"""O banco de cartas do LifeLink no Cloudflare R2 (roda na Action cards-data.yml).

1. Monta o banco: todas as cartas (uma linha por carta), com o texto em
   inglês e, quando existe, em português, e todas as variações (versões) em
   inglês e português.
2. Copia as imagens da Scryfall para o R2 aos poucos (primeiro uma por
   carta, depois as outras variações), continuando de onde parou.
3. Publica o banco no R2, marcando quais imagens já estão lá.

No R2 (bucket lifelink):
  data/cards.jsonl.gz  o banco (ver abaixo)
  data/meta.json       quando foi feito e quantas cartas e imagens
  data/images.txt.gz   os ids das imagens que já estão no R2
  img/<id>.jpg         a imagem (frente) de cada variação
  img/<id>-b.jpg       o verso (cartas de duas faces)

O banco: a primeira linha é {"sets": {código: nome}}; depois, uma linha por
carta com campos curtos (para o arquivo ficar pequeno):
  id (a versão principal), o (oracle_id), n/t/x (nome, tipo e texto em
  inglês), m (custo), cmc, ci (identidade de cor), r (raridade), lg
  (legalidade: uma letra por formato, ver FORMATS: l legal, b banida,
  r restrita, n não), gc (1 = game changer), pn/pt/px (português) e
  v: as variações [id, coleção, número, raridade, idioma, usd, eur,
  imagem no R2 (0/1), verso (0/1), nome impresso (só se for diferente)].

Uso:
  python3 tool/build_cards.py               (tudo; precisa das chaves do R2)
  python3 tool/build_cards.py --sem-imagens (só o banco, sem mexer em imagens)
Variáveis: R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY,
R2_BUCKET (lifelink), MAX_MINUTES (tempo para as imagens, 300).
"""

import concurrent.futures
import gzip
import io
import json
import os
import sys
import time
import urllib.request

HEADERS = {'User-Agent': 'LifeLink/1.0 (github.com/OctavioKonzen/LifeLink)', 'Accept': 'application/json'}
FORMATS = ['commander', 'standard', 'pioneer', 'modern', 'legacy', 'vintage', 'pauper']
LEGAL = {'legal': 'l', 'banned': 'b', 'restricted': 'r'}
LANGS = ('en', 'pt')


# ------------------------------------------------------------- Scryfall

def bulk_url(kind):
    req = urllib.request.Request(f'https://api.scryfall.com/bulk-data/{kind}', headers=HEADERS)
    meta = json.load(urllib.request.urlopen(req, timeout=60))
    return meta.get('jsonl_download_uri') or meta['download_uri']


def bulk(kind):
    """As cartas de um arquivo da Scryfall, uma por vez (sem guardar o arquivo)."""
    resp = urllib.request.urlopen(urllib.request.Request(bulk_url(kind), headers=HEADERS), timeout=120)
    with gzip.GzipFile(fileobj=resp) as f:
        for line in f:
            line = line.strip().rstrip(b',')
            if line.startswith(b'{'):
                yield json.loads(line)


def faces(c):
    return c.get('card_faces') or [c]


def image_urls(c):
    """Frente e verso (normal) de uma versão."""
    f = faces(c)
    front = (c.get('image_uris') or f[0].get('image_uris') or {}).get('normal')
    back = (f[1].get('image_uris') or {}).get('normal') if len(f) > 1 and not c.get('image_uris') else None
    return front, back


def joined(fs, key):
    return ' // '.join(x.get(key) or '' for x in fs).strip(' /')


# ----------------------------------------------------------------- banco

def collect_prints(cards):
    """Das versões (all_cards): as variações em inglês e português de cada
    carta e o texto em português (da versão mais nova). Volta
    (variações por oracle_id, português por oracle_id, coleções, urls)."""
    prints, pt, sets, urls = {}, {}, {}, {}
    for c in cards:
        lang = c.get('lang')
        if lang not in LANGS:
            continue
        fs = faces(c)
        oid = c.get('oracle_id') or fs[0].get('oracle_id')
        front, back = image_urls(c)
        if not oid or not front:
            continue
        sets[c['set']] = c.get('set_name', c['set'])
        prices = c.get('prices') or {}
        printed = joined(fs, 'printed_name') if lang == 'pt' else ''
        prints.setdefault(oid, []).append({
            'id': c['id'], 'set': c['set'], 'cn': c.get('collector_number', ''), 'r': c.get('rarity', ''),
            'lang': lang, 'usd': prices.get('usd') or prices.get('usd_foil'), 'eur': prices.get('eur') or prices.get('eur_foil'),
            'at': c.get('released_at', ''), 'back': 1 if back else 0, 'pn': printed,
        })
        urls[c['id']] = (front, back)
        if lang == 'pt' and printed:
            old = pt.get(oid)
            if not old or old['at'] < c.get('released_at', ''):
                pt[oid] = {'at': c.get('released_at', ''), 'pn': printed, 'pt': joined(fs, 'printed_type_line'),
                           'px': '\n//\n'.join(x.get('printed_text') or '' for x in fs).strip('\n/')}
    for vs in prints.values():
        vs.sort(key=lambda v: v['at'], reverse=True)  # as mais novas primeiro
    return prints, pt, sets, urls


def card_line(c, prints, pt, have):
    """Uma carta do banco (c é a carta do oracle_cards)."""
    fs = faces(c)
    prices = c.get('prices') or {}
    leg = c.get('legalities') or {}
    oid = c.get('oracle_id')
    card = {
        'id': c['id'], 'o': oid, 'n': c['name'], 't': c.get('type_line', ''),
        'x': c.get('oracle_text') or fs[0].get('oracle_text', ''),
        'm': c.get('mana_cost') or fs[0].get('mana_cost', ''), 'cmc': c.get('cmc'),
        'ci': ''.join(c.get('color_identity', [])), 'r': c.get('rarity'),
        'lg': ''.join(LEGAL.get(leg.get(f), 'n') for f in FORMATS),
    }
    if c.get('game_changer'):
        card['gc'] = 1
    p = pt.get(oid)
    if p:
        card.update({k: p[k] for k in ('pn', 'pt', 'px')})
    vs = prints.get(oid) or []
    if not any(v['id'] == c['id'] for v in vs):  # a versão principal sempre entra
        front, back = image_urls(c)
        vs = [{'id': c['id'], 'set': c['set'], 'cn': c.get('collector_number', ''), 'r': c.get('rarity', ''), 'lang': c.get('lang', 'en'),
               'usd': prices.get('usd'), 'eur': prices.get('eur'), 'back': 1 if back else 0, 'pn': ''}] + vs
    card['v'] = [[v['id'], v['set'], v['cn'], v['r'], v['lang'], v['usd'], v['eur'],
                  1 if v['id'] in have else 0, v['back'], v['pn'] if v['pn'] and v['pn'] != card.get('pn') else '']
                 for v in vs]
    return card


def build(oracle, prints, pt, sets, have):
    lines = [json.dumps({'sets': sets}, ensure_ascii=False, separators=(',', ':'))]
    count = with_pt = 0
    for c in oracle:
        if not image_urls(c)[0]:
            continue
        card = card_line(c, prints, pt, have)
        with_pt += 1 if 'pn' in card else 0
        count += 1
        lines.append(json.dumps(card, ensure_ascii=False, separators=(',', ':')))
    return '\n'.join(lines) + '\n', count, with_pt


def image_order(oracle_ids_main, prints):
    """A ordem de cópia das imagens: a versão principal de cada carta, depois
    as outras em inglês (mais novas primeiro) e por fim as em português."""
    order, seen = [], set()
    for vid in oracle_ids_main:
        if vid not in seen:
            seen.add(vid)
            order.append(vid)
    for lang in LANGS:
        for vs in prints.values():
            for v in vs:
                if v['lang'] == lang and v['id'] not in seen:
                    seen.add(v['id'])
                    order.append(v['id'])
    return order


# -------------------------------------------------------------------- R2

def account_id(value):
    """O Account ID, mesmo se veio o endereço inteiro do Cloudflare
    (https://<id>.r2.cloudflarestorage.com)."""
    value = value.strip().removeprefix('https://').removeprefix('http://')
    return value.split('/')[0].split('.')[0]


def r2():
    import boto3
    return boto3.client(
        's3',
        endpoint_url=f"https://{account_id(os.environ['R2_ACCOUNT_ID'])}.r2.cloudflarestorage.com",
        aws_access_key_id=os.environ['R2_ACCESS_KEY_ID'],
        aws_secret_access_key=os.environ['R2_SECRET_ACCESS_KEY'],
        region_name='auto',
    )


def get_index(s3, bucket):
    try:
        body = s3.get_object(Bucket=bucket, Key='data/images.txt.gz')['Body'].read()
        return set(gzip.decompress(body).decode().split())
    except Exception:
        return set()


def fetch(url):
    for attempt in range(3):
        try:
            return urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=60).read()
        except Exception:
            time.sleep(2 * (attempt + 1))
    return None


def copy_images(s3, bucket, ids, urls, have, deadline):
    """Copia as imagens que faltam até o tempo acabar; volta quantas copiou."""
    todo = [i for i in ids if i not in have]
    done = 0

    def one(vid):
        front, back = urls[vid]
        data = fetch(front)
        if not data:
            return None
        s3.put_object(Bucket=bucket, Key=f'img/{vid}.jpg', Body=data, ContentType='image/jpeg', CacheControl='public, max-age=31536000')
        if back:
            b = fetch(back)
            if b:
                s3.put_object(Bucket=bucket, Key=f'img/{vid}-b.jpg', Body=b, ContentType='image/jpeg', CacheControl='public, max-age=31536000')
        return vid

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        for start in range(0, len(todo), 400):
            if time.time() > deadline:
                break
            for vid in pool.map(one, todo[start:start + 400]):
                if vid:
                    have.add(vid)
                    done += 1
            print(f'imagens: {done} copiadas nesta vez, {len(have)} no total', flush=True)
    return done, len(todo) - done


def main():
    no_images = '--sem-imagens' in sys.argv
    started = time.time()
    print('Lendo as versões (all_cards)...', flush=True)
    prints, pt, sets, urls = collect_prints(bulk('all-cards'))
    print(f'{sum(len(v) for v in prints.values())} variações em inglês e português, {len(pt)} cartas em português', flush=True)
    print('Lendo as cartas (oracle_cards)...', flush=True)
    oracle = list(bulk('oracle-cards'))
    for c in oracle:
        front, back = image_urls(c)
        if front:
            urls.setdefault(c['id'], (front, back))

    bucket = os.environ.get('R2_BUCKET', 'lifelink')
    s3 = None if no_images else r2()
    have = get_index(s3, bucket) if s3 else set()
    left = 0
    if s3:
        deadline = started + int(os.environ.get('MAX_MINUTES', '300')) * 60
        order = image_order([c['id'] for c in oracle if image_urls(c)[0]], prints)
        copied, left = copy_images(s3, bucket, order, urls, have, deadline)
        print(f'{copied} imagens copiadas; faltam {left}', flush=True)

    text, count, with_pt = build(oracle, prints, pt, sets, have)
    if count < 30000:
        sys.exit(f'Só {count} cartas: a Scryfall mudou o formato?')
    data = gzip.compress(text.encode(), 9)
    meta = {'updatedAt': int(time.time() * 1000), 'cards': count, 'portuguese': with_pt,
            'images': len(have), 'imagesLeft': left, 'size': len(data)}
    print(json.dumps(meta), flush=True)
    if s3:
        s3.put_object(Bucket=bucket, Key='data/images.txt.gz', Body=gzip.compress('\n'.join(sorted(have)).encode()), ContentType='application/gzip')
        s3.put_object(Bucket=bucket, Key='data/cards.jsonl.gz', Body=data, ContentType='application/gzip', CacheControl='public, max-age=3600')
        s3.put_object(Bucket=bucket, Key='data/meta.json', Body=json.dumps(meta).encode(), ContentType='application/json', CacheControl='public, max-age=300')
    else:
        with open('cards.jsonl.gz', 'wb') as f:
            f.write(data)


if __name__ == '__main__':
    main()
