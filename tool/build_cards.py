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
carta, com tudo o que a Scryfall tem dela (menos links, ids de outros sites
e a imagem), em campos curtos para o arquivo ficar pequeno:
  da carta: id (versão principal), o (oracle_id), n, lay (layout), m (custo),
    cmc, t (tipo), x (texto), pw/tg (poder/resistência), ly (lealdade),
    df (defesa), c/ci/ind (cores, identidade, indicador), kw (palavras-chave),
    pmn (mana que gera), lg (legalidade: formato → l/b/r), gc (game changer),
    rs (lista reservada), er/pr (posição no EDHREC e no Penny), f (faces),
    pn/pt/px (nome, tipo e texto em português)
  v: as variações (inglês e português): id, s (coleção), cn (número),
    r (raridade), l (idioma), d (data), a (artista), ft (texto ilustrativo),
    fr/fe/bc (moldura, efeitos, borda), fa (arte total), tl (sem texto),
    pm/pts (promo e tipos), fn (acabamentos: foil...), wm (marca d'água),
    $ (todos os preços), b (tem verso), i (imagem já no R2) e, em
    português, pn/pt/px impressos.

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
LANGS = ('en', 'pt')
LEGAL = {'legal': 'l', 'banned': 'b', 'restricted': 'r'}


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

def clean(d):
    """Tira o que está vazio (o arquivo fica menor)."""
    return {k: v for k, v in d.items() if v not in (None, '', [], {}, False)}


def face_oracle(f):
    """O que é da carta (igual em todas as versões), de uma face."""
    return clean({
        'n': f.get('name'), 'm': f.get('mana_cost'), 't': f.get('type_line'), 'x': f.get('oracle_text'),
        'pw': f.get('power'), 'tg': f.get('toughness'), 'ly': f.get('loyalty'), 'df': f.get('defense'),
        'c': ''.join(f.get('colors') or []), 'ind': ''.join(f.get('color_indicator') or []),
    })


def printed(c):
    """Nome, tipo e texto impressos (português), da versão."""
    fs = faces(c)
    return clean({
        'pn': joined(fs, 'printed_name'),
        'pt': joined(fs, 'printed_type_line'),
        'px': '\n//\n'.join(f.get('printed_text') or '' for f in fs).strip('\n/'),
    })


def variation(c, back, have=()):
    """O que muda de uma versão para outra."""
    fs = faces(c)
    prices = {k: v for k, v in (c.get('prices') or {}).items() if v}
    v = clean({
        'id': c['id'], 's': c.get('set'), 'cn': c.get('collector_number'), 'r': c.get('rarity'), 'l': c.get('lang'),
        'd': c.get('released_at'), 'a': c.get('artist') or fs[0].get('artist'),
        'ft': c.get('flavor_text') or joined(fs, 'flavor_text'),
        'fr': c.get('frame'), 'fe': c.get('frame_effects'), 'bc': c.get('border_color'),
        'fa': 1 if c.get('full_art') else None, 'tl': 1 if c.get('textless') else None,
        'pm': 1 if c.get('promo') else None, 'pts': c.get('promo_types'), 'fn': c.get('finishes'),
        'wm': c.get('watermark') or fs[0].get('watermark'), '$': prices,
        'b': 1 if back else None,
    })
    if c.get('lang') != 'en':
        v.update(printed(c))
    return v


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
        prints.setdefault(oid, []).append(variation(c, back))
        urls[c['id']] = (front, back)
        if lang == 'pt':
            # A versão em português mais nova; antes as que têm o nome
            # traduzido (algumas reimpressões mantêm o nome em inglês).
            p = printed(c)
            if p.get('pn'):
                rank = (p['pn'] != c.get('name'), c.get('released_at', ''))
                if oid not in pt or pt[oid]['rank'] < rank:
                    pt[oid] = {'rank': rank, **p}
    for vs in prints.values():
        vs.sort(key=lambda v: v.get('d', ''), reverse=True)  # as mais novas primeiro
    return prints, pt, sets, urls


def card_line(c, prints, pt, have):
    """Uma carta do banco (c é a carta do oracle_cards)."""
    fs = faces(c)
    oid = c.get('oracle_id')
    card = clean({
        'id': c['id'], 'o': oid, 'n': c['name'], 'lay': c.get('layout'),
        'm': c.get('mana_cost') or fs[0].get('mana_cost'), 'cmc': c.get('cmc'),
        't': c.get('type_line'), 'x': c.get('oracle_text') or fs[0].get('oracle_text'),
        'pw': c.get('power'), 'tg': c.get('toughness'), 'ly': c.get('loyalty'), 'df': c.get('defense'),
        'c': ''.join(c.get('colors') or []), 'ci': ''.join(c.get('color_identity') or []),
        'ind': ''.join(c.get('color_indicator') or []), 'kw': c.get('keywords'),
        'pmn': c.get('produced_mana'),
        'lg': {f: LEGAL[s] for f, s in (c.get('legalities') or {}).items() if s in LEGAL},
        'gc': 1 if c.get('game_changer') else None, 'rs': 1 if c.get('reserved') else None,
        'er': c.get('edhrec_rank'), 'pr': c.get('penny_rank'),
        'f': [face_oracle(f) for f in fs] if len(fs) > 1 else None,
    })
    p = pt.get(oid)
    if p:
        card.update({k: p[k] for k in ('pn', 'pt', 'px') if k in p})
    vs = prints.get(oid) or []
    if not any(v['id'] == c['id'] for v in vs):  # a versão principal sempre entra
        vs = [variation(c, image_urls(c)[1])] + vs
    card['v'] = [dict(v, i=1) if v['id'] in have else v for v in vs]
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


def image_order(main_ids, prints):
    """A ordem de cópia das imagens: a versão principal de cada carta, depois
    as outras em inglês (mais novas primeiro) e por fim as em português."""
    order, seen = [], set()
    for vid in main_ids:
        if vid not in seen:
            seen.add(vid)
            order.append(vid)
    for lang in LANGS:
        for vs in prints.values():
            for v in vs:
                if v.get('l') == lang and v['id'] not in seen:
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


# ------------------------------------------------- arquivos por carta

def shard_files(cards, sets):
    """Os arquivos que o app e o site buscam no R2 pelo código (sem baixar o
    banco inteiro). Volta {caminho: conteúdo}:
      c/<oracle_id>.json   a carta com todas as variações (sem preços)
      pr/<xx>.json         os preços de todas as variações das cartas cujo
                           oracle_id começa com xx (muda todo dia)
      id/<xxx>.json        código da variação → oracle_id (xxx = começo do código)
      set/<coleção>.json   "número|idioma" → código da variação (para a câmera)
      sets.json            código da coleção → nome
    """
    files, prices, ids, by_set = {}, {}, {}, {}
    for card in cards:
        o = card['o']
        static = dict(card, v=[{k: x for k, x in v.items() if k != '$'} for v in card['v']])
        files[f'c/{o}.json'] = static
        prices.setdefault(o[:2], {})[o] = {v['id']: v['$'] for v in card['v'] if v.get('$')}
        for v in card['v']:
            ids.setdefault(v['id'][:3], {})[v['id']] = o
            by_set.setdefault(v['s'], {})[f"{v.get('cn', '')}|{v.get('l', 'en')}"] = v['id']
    files.update({f'pr/{k}.json': v for k, v in prices.items()})
    files.update({f'id/{k}.json': v for k, v in ids.items()})
    files.update({f'set/{k}.json': v for k, v in by_set.items()})
    files['sets.json'] = sets
    return {k: json.dumps(v, ensure_ascii=False, separators=(',', ':')).encode() for k, v in files.items()}


def top_prices(cards, sets, count=600):
    """As variações mais caras (inglês e português), para a tela "Preços de
    hoje" do app e do site: data/top.json."""
    rows = []
    for card in cards:
        for v in card['v']:
            prices = v.get('$') or {}
            usd = prices.get('usd') or prices.get('usd_foil') or prices.get('usd_etched')
            try:
                value = float(usd) if usd else 0
            except ValueError:
                value = 0
            if value > 0:
                rows.append((value, card, v))
    rows.sort(key=lambda r: r[0], reverse=True)
    return [clean({
        'id': v['id'], 'o': card['o'], 'n': card['n'], 'pn': v.get('pn') or (card.get('pn') if v.get('l') == 'pt' else None),
        'l': v.get('l'), 's': v.get('s'), 'sn': sets.get(v.get('s'), ''), 'cn': v.get('cn'), 'r': v.get('r'),
        'm': card.get('m'), 't': card.get('t'), 'ci': card.get('ci'), 'i': v.get('i'), '$': v.get('$'),
    }) for _, card, v in rows[:count]]


def publish_shards(s3, bucket, files):
    """Envia só os arquivos que mudaram desde a última vez (o resumo de cada
    um fica em data/shards.json.gz)."""
    import hashlib
    try:
        old = json.loads(gzip.decompress(s3.get_object(Bucket=bucket, Key='data/shards.json.gz')['Body'].read()))
    except Exception:
        old = {}
    new = {k: hashlib.md5(v).hexdigest() for k, v in files.items()}
    changed = [k for k, h in new.items() if old.get(k) != h]
    print(f'arquivos por carta: {len(files)}, mudaram {len(changed)}', flush=True)

    def put(key):
        cache = 'public, max-age=3600' if key.startswith('pr/') else 'public, max-age=86400'
        s3.put_object(Bucket=bucket, Key=key, Body=files[key], ContentType='application/json', CacheControl=cache)

    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
        for i, _ in enumerate(pool.map(put, changed), 1):
            if i % 5000 == 0:
                print(f'  {i} enviados', flush=True)
    s3.put_object(Bucket=bucket, Key='data/shards.json.gz', Body=gzip.compress(json.dumps(new).encode()), ContentType='application/gzip')


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
        cards = [json.loads(line) for line in text.splitlines()[1:]]
        publish_shards(s3, bucket, shard_files(cards, sets))
        s3.put_object(Bucket=bucket, Key='data/top.json', Body=json.dumps(top_prices(cards, sets), ensure_ascii=False, separators=(',', ':')).encode(),
                      ContentType='application/json', CacheControl='public, max-age=3600')
        s3.put_object(Bucket=bucket, Key='data/meta.json', Body=json.dumps(meta).encode(), ContentType='application/json', CacheControl='public, max-age=300')
    else:
        with open('cards.jsonl.gz', 'wb') as f:
            f.write(data)


if __name__ == '__main__':
    main()
