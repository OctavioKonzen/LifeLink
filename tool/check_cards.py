"""Confere se falta carta no banco do LifeLink (roda na Action cards-check.yml).

Compara o banco do R2 (data/cards.jsonl.gz) com:
  - a Scryfall: todas as versões (all_cards) e as cartas (oracle_cards);
  - o MTGJSON: todas as versões de todas as coleções (AllPrintings);
  - a busca no D1 (quantas cartas o servidor tem, pelo /health);
  - as imagens já copiadas para o R2 (data/images.txt.gz).
Mostra quantas faltam e alguns exemplos de cada.

Uso: python3 tool/check_cards.py   (precisa das chaves do R2)
"""

import gzip
import json
import os
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(__file__))
from build_cards import HEADERS, LANGS, bulk, faces, get_index, image_urls, r2  # noqa: E402

SKIP_LAYOUTS = {'token', 'double_faced_token', 'emblem', 'art_series'}
SEARCH = os.environ.get('SEARCH_URL', 'https://lifelink-cards.octavio-a-k95.workers.dev')
EXAMPLES = 25
report = []


def say(text=''):
    print(text, flush=True)
    report.append(text)


def show(title, items, fmt):
    say(f'- {title}: **{len(items)}**')
    for x in list(items)[:EXAMPLES]:
        say(f'    - {fmt(x)}')


def main():
    bucket = os.environ.get('R2_BUCKET', 'lifelink')
    s3 = r2()

    # ------------------------------------------------------------ o banco
    lines = gzip.decompress(s3.get_object(Bucket=bucket, Key='data/cards.jsonl.gz')['Body'].read()).decode().splitlines()
    cards = [json.loads(line) for line in lines[1:] if line.strip()]
    oracles = {c['o']: c for c in cards}
    variations = {v['id']: (c, v) for c in cards for v in c['v']}
    images = get_index(s3, bucket)
    searchable = [c for c in cards if c.get('lay') not in SKIP_LAYOUTS]
    say('## Banco do LifeLink (R2)')
    say(f'- cartas: **{len(cards)}** (na busca: {len(searchable)}; fichas, emblemas e art series ficam só no R2)')
    say(f'- variações (inglês e português): **{len(variations)}**')
    say(f'- cartas com nome em português: {sum(1 for c in cards if c.get("pn"))}')
    no_image = [x for x in variations if x not in images]
    show('variações sem imagem no R2', no_image, lambda i: f'{variations[i][0]["n"]} ({variations[i][1].get("s")} #{variations[i][1].get("cn")}, {variations[i][1].get("l")})')

    # ---------------------------------------------------------- Scryfall
    say()
    say('## Scryfall')
    by_lang, missing_prints, other_lang_only, no_img = {}, [], {}, 0
    for c in bulk('all-cards'):
        lang = c.get('lang')
        by_lang[lang] = by_lang.get(lang, 0) + 1
        oid = c.get('oracle_id') or faces(c)[0].get('oracle_id')
        if not image_urls(c)[0]:
            no_img += 1
            continue
        if lang in LANGS:
            if c['id'] not in variations:
                missing_prints.append(c)
        elif oid and oid not in oracles:
            other_lang_only.setdefault(oid, c)
    total = sum(by_lang.values())
    say(f'- versões na Scryfall (todos os idiomas): **{total}**')
    say(f'- por idioma: ' + ', '.join(f'{k} {v}' for k, v in sorted(by_lang.items(), key=lambda kv: -kv[1])))
    say(f'- versões sem imagem na Scryfall (não dá para ter): {no_img}')
    show('versões em inglês/português que faltam no banco', missing_prints, lambda c: f'{c["name"]} ({c["set"]} #{c["collector_number"]}, {c["lang"]})')
    show('cartas que só existem em outros idiomas (não entram: só pt e en)', list(other_lang_only.values()), lambda c: f'{c["name"]} ({c["set"]}, {c["lang"]})')

    missing_cards = []
    count = 0
    for c in bulk('oracle-cards'):
        count += 1
        if image_urls(c)[0] and c.get('oracle_id') not in oracles:
            missing_cards.append(c)
    say(f'- cartas na Scryfall (oracle_cards): **{count}**')
    show('cartas que faltam no banco', missing_cards, lambda c: f'{c["name"]} ({c.get("layout")})')

    # ------------------------------------------------------------ MTGJSON
    say()
    say('## MTGJSON')
    try:
        import ijson
        resp = urllib.request.urlopen(urllib.request.Request('https://mtgjson.com/api/v5/AllPrintings.json.gz', headers=HEADERS), timeout=300)
        mj_prints = mj_sets = 0
        mj_oracles, mj_missing, mj_no_id = {}, [], []
        with gzip.GzipFile(fileobj=resp) as f:
            for code, s in ijson.kvitems(f, 'data'):
                mj_sets += 1
                for card in s.get('cards') or []:
                    mj_prints += 1
                    ids = card.get('identifiers') or {}
                    sid, oid = ids.get('scryfallId'), ids.get('scryfallOracleId')
                    label = f'{card.get("name")} ({code} #{card.get("number")}, {card.get("language")})'
                    if not sid:
                        mj_no_id.append(label)
                        continue
                    if oid:
                        mj_oracles.setdefault(oid, label)
                    if card.get('language', 'English') in ('English', 'Portuguese (Brazil)') and sid not in variations:
                        mj_missing.append(label)
        say(f'- coleções: **{mj_sets}**, versões: **{mj_prints}**, cartas diferentes: **{len(mj_oracles)}**')
        show('versões do MTGJSON que faltam no banco', mj_missing, str)
        show('cartas do MTGJSON que faltam no banco', [v for k, v in mj_oracles.items() if k not in oracles], str)
        show('versões do MTGJSON sem id da Scryfall (não dá para comparar)', mj_no_id, str)
    except Exception as e:  # noqa: BLE001
        say(f'- não deu para ler o MTGJSON: {e}')

    # ---------------------------------------------------------------- D1
    say()
    say('## Busca (D1)')
    try:
        health = json.load(urllib.request.urlopen(urllib.request.Request(f'{SEARCH}/health', headers=HEADERS), timeout=60))
        have = health.get('cards', 0)
        say(f'- cartas na busca: **{have}** de {len(searchable)} (faltam {max(len(searchable) - have, 0)})')
    except Exception as e:  # noqa: BLE001
        say(f'- não deu para ler o /health: {e}')

    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as f:
            f.write('\n'.join(report) + '\n')


if __name__ == '__main__':
    main()
