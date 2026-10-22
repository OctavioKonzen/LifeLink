"""Carrega a busca de cartas no Cloudflare D1 (roda na Action cloud.yml).

Lê o banco do R2 (data/cards.jsonl.gz, feito por build_cards.py) e manda para
o D1 só o que mudou desde a última vez (o resumo fica em data/d1-state.json.gz
no R2). O plano grátis do D1 aceita 100 mil linhas escritas por dia, então a
primeira carga vai em partes (as cartas mais usadas primeiro) e continua no
dia seguinte.

Uso: python3 tool/load_d1.py          (precisa do wrangler e das chaves)
     python3 tool/load_d1.py --sql    (só gera os .sql, sem enviar; para testar)
"""

import gzip
import hashlib
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
from build_cards import r2  # noqa: E402

BUDGET = int(os.environ.get('D1_BUDGET', '85000'))  # linhas escritas por execução
CHUNK = 1500  # cartas por arquivo .sql
# Quanto cada mudança escreve (a linha, o índice e o índice do texto).
COST_NEW, COST_TEXT, COST_LIGHT, COST_DELETE = 4, 8, 2, 6

SKIP_LAYOUTS = {'token', 'double_faced_token', 'emblem', 'art_series'}
TEXT_COLS = ('n', 'pn', 't', 'pt', 'x', 'px', 'ss')
ALL_COLS = ('k', 'o', 'id', 'n', 'pn', 't', 'pt', 'x', 'px', 'ss', 'm', 'cmc', 'ci', 'r', 'er', 'd', 'usd', 'img')


def row_of(card):
    """A carta do banco → a linha da busca."""
    main = next((v for v in card['v'] if v['id'] == card['id']), card['v'][0] if card['v'] else {})
    prices = main.get('$') or {}
    usd = prices.get('usd') or prices.get('usd_foil') or prices.get('usd_etched')
    return {
        'o': card['o'], 'id': card['id'], 'n': card.get('n'), 'pn': card.get('pn'),
        't': card.get('t') or ' // '.join(f.get('t', '') for f in card.get('f', [])),
        'pt': card.get('pt'),
        'x': card.get('x') or '\n//\n'.join(f.get('x', '') for f in card.get('f', [])),
        'px': card.get('px'),
        'ss': ' '.join(sorted({v['s'] for v in card['v'] if v.get('s')})),
        'm': card.get('m'), 'cmc': card.get('cmc'), 'ci': card.get('ci', ''), 'r': main.get('r'),
        'er': card.get('er'), 'd': max((v.get('d', '') for v in card['v']), default=None),
        'usd': float(usd) if usd else None, 'img': 1 if main.get('i') else 0,
    }


def text_hash(row):
    return hashlib.md5(json.dumps([row.get(c) for c in TEXT_COLS + ('o', 'id', 'm', 'cmc', 'ci', 'r', 'd')]).encode()).hexdigest()[:16]


def sql_value(v):
    if v is None:
        return 'NULL'
    if isinstance(v, (int, float)):
        return repr(v)
    return "'" + str(v).replace("'", "''") + "'"


def statements(k, row, kind):
    """O SQL de uma carta: nova, texto mudou, só preço/imagem/popularidade, ou saiu."""
    fts_delete = (f"INSERT INTO cards_fts(cards_fts, rowid, {', '.join(TEXT_COLS)}) "
                  f"SELECT 'delete', k, {', '.join(TEXT_COLS)} FROM cards WHERE k = {k};")
    if kind == 'delete':
        return [fts_delete, f'DELETE FROM cards WHERE k = {k};']
    if kind == 'light':
        return [f"UPDATE cards SET usd = {sql_value(row['usd'])}, img = {row['img']}, er = {sql_value(row['er'])} WHERE k = {k};"]
    values = [k] + [row.get(c) for c in ALL_COLS[1:]]
    return [
        fts_delete,  # não faz nada se a carta ainda não está lá (assim dá para repetir)
        f"INSERT OR REPLACE INTO cards ({', '.join(ALL_COLS)}) VALUES ({', '.join(sql_value(v) for v in values)});",
        f"INSERT INTO cards_fts(rowid, {', '.join(TEXT_COLS)}) VALUES ({k}, {', '.join(sql_value(row.get(c)) for c in TEXT_COLS)});",
    ]


def plan(cards, state, budget=BUDGET):
    """O que mandar nesta vez: [(oracle, k, linha, tipo)], dentro do limite.
    As cartas novas mais usadas (EDHREC) vão primeiro."""
    rows = {c['o']: row_of(c) for c in cards}
    next_k = max([s[0] for s in state.values()], default=0) + 1
    new, text, light, gone = [], [], [], []
    for o, row in rows.items():
        old = state.get(o)
        if old is None:
            new.append(o)
        elif old[1] != text_hash(row):
            text.append(o)
        elif old[2:] != [row['usd'], row['img'], row['er']]:
            light.append(o)
    gone = [o for o in state if o not in rows]
    new.sort(key=lambda o: (rows[o]['er'] is None, rows[o]['er'] or 0))

    todo, spent = [], 0
    for kind, items, cost in (('delete', gone, COST_DELETE), ('text', text, COST_TEXT), ('new', new, COST_NEW), ('light', light, COST_LIGHT)):
        for o in items:
            if spent + cost > budget:
                break
            if kind == 'new':
                k, next_k = next_k, next_k + 1
            else:
                k = state[o][0]
            todo.append((o, k, rows.get(o), kind))
            spent += cost
    left = len(new) + len(text) + len(light) + len(gone) - len(todo)
    return todo, left


def apply(state, item):
    o, k, row, kind = item
    if kind == 'delete':
        state.pop(o, None)
    else:
        state[o] = [k, text_hash(row), row['usd'], row['img'], row['er']]


def main():
    only_sql = '--sql' in sys.argv
    bucket = os.environ.get('R2_BUCKET', 'lifelink')
    if only_sql:
        with gzip.open(sys.argv[sys.argv.index('--sql') + 1], 'rt', encoding='utf-8') as f:
            lines = f.read().splitlines()
        state = {}
        s3 = None
    else:
        s3 = r2()
        lines = gzip.decompress(s3.get_object(Bucket=bucket, Key='data/cards.jsonl.gz')['Body'].read()).decode().splitlines()
        try:
            state = json.loads(gzip.decompress(s3.get_object(Bucket=bucket, Key='data/d1-state.json.gz')['Body'].read()))
        except Exception:
            state = {}
    # Fichas, emblemas e "art series" não entram na busca (continuam no R2).
    cards = [c for c in (json.loads(line) for line in lines[1:] if line.strip()) if c.get('lay') not in SKIP_LAYOUTS]
    todo, left = plan(cards, state)
    kinds = {}
    for t in todo:
        kinds[t[3]] = kinds.get(t[3], 0) + 1
    print(f'{len(cards)} cartas; nesta vez: {kinds or "nada"}; ficam para a próxima: {left}', flush=True)

    for start in range(0, len(todo), CHUNK):
        part = todo[start:start + CHUNK]
        path = f'd1-{start // CHUNK:03d}.sql'
        with open(path, 'w', encoding='utf-8') as f:
            for o, k, row, kind in part:
                f.write('\n'.join(statements(k, row, kind)) + '\n')
        if only_sql:
            continue
        subprocess.run(['npx', 'wrangler', 'd1', 'execute', 'lifelink', '--remote', f'--file={os.path.abspath(path)}'],
                       check=True, cwd=os.path.join(os.path.dirname(__file__), '..', 'cloud'))
        for item in part:
            apply(state, item)
        # Guarda o progresso a cada parte (se cair, continua daqui).
        s3.put_object(Bucket=bucket, Key='data/d1-state.json.gz', Body=gzip.compress(json.dumps(state).encode()), ContentType='application/gzip')
        print(f'  {min(start + CHUNK, len(todo))}/{len(todo)} enviadas', flush=True)


if __name__ == '__main__':
    main()
