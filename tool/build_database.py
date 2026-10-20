#!/usr/bin/env python3
"""Gera o banco local do app (assets/database/) a partir do Scryfall e do MTGJSON.

O app e o site não chamam nenhuma API: tudo o que eles mostram (cartas,
edições, traduções, coleções, decks oficiais e os símbolos de mana) sai dos
arquivos que este script grava. Só as imagens das cartas continuam vindo do
servidor de imagens do Scryfall (cards.scryfall.io), porque não cabem no git.

Os preços NÃO ficam aqui: mudam todo dia e são gerados à parte, de hora em
hora, por tool/build_prices.py (sem refazer este banco).

Saída:
    assets/database/cards.json        uma linha por carta (a edição padrão)
    assets/database/prints_<lang>.json todas as edições com imagem, por idioma,
                                       e o texto traduzido de cada carta
    assets/database/sets.json         coleções, da mais nova para a mais velha
    assets/database/catalogs.json     tipos, supertipos e raças (filtros)
    assets/database/decks.json        decks oficiais (MTGJSON)
    assets/database/meta.json         quando e de onde o banco foi gerado
    assets/symbols/<símbolo>.svg      símbolos de mana ({W}, {2/U}, {T}...)
    assets/images/*.jpg               verso da carta e banners do início

Uso:
    pip install ijson
    python3 tool/build_database.py                 # baixa tudo e gera
    python3 tool/build_database.py --offline DIR   # usa arquivos já baixados

No modo --offline, DIR tem os mesmos arquivos que o download produziria:
oracle_cards.json, all_cards.json, sets.json, symbology.json,
catalog-<nome>.json, DeckList.json e AllDeckFiles.zip.
"""

import argparse
import datetime
import json
import os
import re
import shutil
import sys
import tempfile
import time
import urllib.request
import zipfile

import ijson

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DB = os.path.join(ROOT, 'assets', 'database')
SYMBOLS = os.path.join(ROOT, 'assets', 'symbols')
IMAGES = os.path.join(ROOT, 'assets', 'images')

SCRYFALL = 'https://api.scryfall.com'
MTGJSON = 'https://mtgjson.com/api/v5'
# O Scryfall pede um User-Agent que identifique o projeto e o Accept.
HEADERS = {'User-Agent': 'MagicApp-DatabaseBuilder/1.0 (github.com/OctavioKonzen/Magic)', 'Accept': 'application/json;q=0.9,*/*;q=0.8'}

# Os mesmos idiomas do menu "traduzir deck" do app (deck_detail_screen.dart).
LANGS = ['en', 'pt', 'ja', 'es', 'fr', 'de', 'it']

# Não são cartas jogáveis: a busca do Scryfall também deixa de fora.
SKIP_LAYOUTS = {'art_series', 'token', 'double_faced_token', 'emblem', 'vanguard', 'scheme', 'planar'}
GOOD_IMAGES = {'highres_scan', 'lowres'}

CATALOGS = ['supertypes', 'card-types', 'creature-types', 'artifact-types', 'enchantment-types']

CARD_FIELDS = ['id', 'oracle_id', 'name', 'mana_cost', 'cmc', 'type_line', 'oracle_text', 'power', 'toughness', 'color_identity', 'rarity', 'set', 'collector_number', 'commander']
PRINT_FIELDS = ['card', 'id', 'set', 'collector_number', 'rarity']
TEXT_FIELDS = ['name', 'type_line', 'oracle_text']

# Imagens da interface que antes não estavam no git. Cada banner é a arte de
# uma carta ligada à notícia (home_screen.dart).
CARD_BACK = 'https://backs.scryfall.io/normal/0/a/0aeebaf5-8c7d-4636-9e82-8c27447861f7.jpg'
BANNERS = {
    'banned.jpg': 'Nadu, Winged Wisdom',
    'mh3.jpg': 'Ulamog, the Defiler',
    'arena.jpg': 'Sheoldred, the Apocalypse',
}


# ---------------------------------------------------------------- download

def fetch(url, dest=None, tries=4):
    """Baixa url (para dest, ou devolve os bytes), com novas tentativas."""
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=120) as resp:
                if dest is None:
                    return resp.read()
                with open(dest, 'wb') as f:
                    shutil.copyfileobj(resp, f, 1 << 20)
                return dest
        except Exception as e:  # noqa: BLE001 - rede: tenta de novo
            if attempt == tries - 1:
                raise
            print(f'  falhou ({e}), tentando de novo...', file=sys.stderr)
            time.sleep(2 ** (attempt + 1))
        finally:
            # O Scryfall pede no máximo ~10 pedidos por segundo.
            time.sleep(0.1)


def fetch_json(url):
    return json.loads(fetch(url))


def download_all(work):
    """Baixa para work/ tudo o que o banco precisa e devolve o updated_at."""
    bulk = {}
    for kind in ('oracle_cards', 'all_cards'):
        info = fetch_json(f'{SCRYFALL}/bulk-data/{kind}')
        bulk[kind] = info['updated_at']
        print(f'Baixando {kind} ({info["size"] / 1e6:.0f} MB)...')
        fetch(info['download_uri'], os.path.join(work, f'{kind}.json'))

    print('Baixando coleções, catálogos e símbolos...')
    with open(os.path.join(work, 'sets.json'), 'wb') as f:
        f.write(fetch(f'{SCRYFALL}/sets'))
    for name in CATALOGS:
        with open(os.path.join(work, f'catalog-{name}.json'), 'wb') as f:
            f.write(fetch(f'{SCRYFALL}/catalog/{name}'))
    with open(os.path.join(work, 'symbology.json'), 'wb') as f:
        f.write(fetch(f'{SCRYFALL}/symbology'))

    print('Baixando decks do MTGJSON...')
    fetch(f'{MTGJSON}/DeckList.json', os.path.join(work, 'DeckList.json'))
    fetch(f'{MTGJSON}/AllDeckFiles.zip', os.path.join(work, 'AllDeckFiles.zip'))
    return bulk


# ------------------------------------------------------------------ cartas

def faces(c):
    return c.get('card_faces') or []


def joined(c, key, sep):
    """Campo da carta, ou dos lados juntos (cartas de duas faces)."""
    if c.get(key):
        return c[key]
    parts = [f.get(key) or '' for f in faces(c)]
    return sep.join(p for p in parts if p) if any(parts) else ''


def front(c, key):
    if c.get(key) is not None:
        return c[key]
    fs = faces(c)
    return fs[0].get(key) if fs else None


def has_image(c):
    return bool(c.get('image_uris') or (faces(c) and faces(c)[0].get('image_uris')))


def oracle_id(c):
    # Cartas reversíveis não têm oracle_id no topo, só em cada lado.
    return c.get('oracle_id') or (faces(c)[0].get('oracle_id') if faces(c) else None)


def can_be_commander(c):
    """O mesmo critério do filtro is:commander do Scryfall, simplificado."""
    if c.get('legalities', {}).get('commander') not in ('legal', 'restricted'):
        return False
    type_line = (front(c, 'type_line') or c.get('type_line') or '').split('//')[0]
    if 'Legendary' in type_line and 'Creature' in type_line:
        return True
    return 'can be your commander' in joined(c, 'oracle_text', '\n')


def card_row(c):
    return [
        c['id'],
        oracle_id(c),
        c['name'],
        joined(c, 'mana_cost', ' // '),
        c.get('cmc') or 0,
        c.get('type_line') or joined(c, 'type_line', ' // '),
        joined(c, 'oracle_text', '\n//\n'),
        front(c, 'power'),
        front(c, 'toughness'),
        ''.join(c.get('color_identity') or []),
        c.get('rarity') or 'common',
        c.get('set') or '',
        c.get('collector_number') or '',
        1 if can_be_commander(c) else 0,
    ]


def number_key(cn):
    m = re.match(r'(\d+)', cn or '')
    return (int(m.group(1)) if m else 0, cn or '')


def stream(path):
    with open(path, 'rb') as f:
        yield from ijson.items(f, 'item', use_float=True)


def build_cards(path):
    cards = []
    for c in stream(path):
        if c.get('layout') in SKIP_LAYOUTS or not has_image(c) or not oracle_id(c):
            continue
        cards.append(card_row(c))
    cards.sort(key=lambda r: r[2].lower())
    return cards


def build_prints(path, by_oracle):
    """Edições por idioma e o texto traduzido mais novo de cada carta."""
    prints = {lang: [] for lang in LANGS}
    texts = {lang: {} for lang in LANGS if lang != 'en'}
    for c in stream(path):
        lang = c.get('lang')
        if lang not in prints or c.get('layout') in SKIP_LAYOUTS:
            continue
        idx = by_oracle.get(oracle_id(c))
        if idx is None or c.get('image_status') not in GOOD_IMAGES or not has_image(c):
            continue
        released = c.get('released_at') or ''
        prints[lang].append((released, c.get('set') or '', number_key(c.get('collector_number')),
                             [idx, c['id'], c.get('set') or '', c.get('collector_number') or '', c.get('rarity') or 'common']))
        if lang != 'en':
            name = c.get('printed_name') or joined_printed(c, 'printed_name', ' // ')
            if not name:
                continue
            old = texts[lang].get(idx)
            if old is None or released > old[0]:
                texts[lang][idx] = (released, [
                    name,
                    c.get('printed_type_line') or joined_printed(c, 'printed_type_line', ' // '),
                    c.get('printed_text') or joined_printed(c, 'printed_text', '\n//\n'),
                ])
    out = {}
    for lang, rows in prints.items():
        rows.sort(key=lambda r: (r[0], r[1], r[2]))
        out[lang] = {
            'fields': PRINT_FIELDS,
            'prints': [r[3] for r in rows],
            'text_fields': TEXT_FIELDS,
            'texts': {str(k): v[1] for k, v in sorted(texts.get(lang, {}).items())},
        }
    return out


def joined_printed(c, key, sep):
    parts = [f.get(key) or '' for f in faces(c)]
    return sep.join(p for p in parts if p)


# ---------------------------------------------------- coleções e catálogos

def build_sets(path):
    with open(path, encoding='utf-8') as f:
        data = json.load(f)['data']
    sets = [{
        'code': s['code'],
        'name': s['name'],
        'released': s.get('released_at') or '',
        'type': s.get('set_type') or '',
        'count': s.get('card_count') or 0,
        'digital': bool(s.get('digital')),
    } for s in data]
    sets.sort(key=lambda s: s['released'], reverse=True)
    return sets


def build_catalogs(work):
    out = {}
    for name in CATALOGS:
        with open(os.path.join(work, f'catalog-{name}.json'), encoding='utf-8') as f:
            out[name.replace('-', '_')] = json.load(f)['data']
    return out


def copy_symbols(work, offline):
    """Salva o SVG de cada símbolo com o nome que o app usa: {2/W} -> 2W.svg."""
    with open(os.path.join(work, 'symbology.json'), encoding='utf-8') as f:
        data = json.load(f)['data']
    os.makedirs(SYMBOLS, exist_ok=True)
    count = 0
    for s in data:
        uri = s.get('svg_uri')
        if not uri:
            continue
        name = os.path.basename(uri.split('?')[0])
        dest = os.path.join(SYMBOLS, name)
        local = os.path.join(work, 'symbols', name)
        if offline:
            if os.path.exists(local):
                shutil.copyfile(local, dest)
                count += 1
        elif not os.path.exists(dest):
            fetch(uri, dest)
            count += 1
    return count


# ------------------------------------------------------------------- decks

def deck_category(deck):
    """0 = Commander, 1 = Challenger, 2 = Avatar / Outros (community_decks_screen.dart)."""
    kind = (deck.get('type') or '').lower()
    name = (deck.get('name') or '').lower()
    if any(w in name for w in ('avatar', 'aang', 'zuko')) or 'secret lair' in kind:
        return 2
    if 'commander' in kind:
        return 0
    if 'challenger' in kind:
        return 1
    if 'starter' in kind or 'planeswalker' in kind:
        return 2
    return None


def deck_card(item, by_oracle, by_name):
    ids = item.get('identifiers') or {}
    count = int(item.get('count') or 1)
    print_id = ids.get('scryfallId') or ''
    idx = by_oracle.get(ids.get('scryfallOracleId'))
    if idx is None:
        idx = by_name.get((item.get('name') or '').lower())
    if idx is not None:
        return [count, idx, print_id]
    # Carta que não está no banco (ex.: só digital): guarda o que o deck tem.
    return [count, -1, print_id, item.get('name') or '', item.get('type') or '', item.get('text') or '',
            item.get('manaCost') or '', item.get('rarity') or 'common', ''.join(item.get('colorIdentity') or []),
            item.get('setCode') or '', item.get('number') or '', item.get('power'), item.get('toughness')]


def build_decks(work, by_oracle, by_name):
    with open(os.path.join(work, 'DeckList.json'), encoding='utf-8') as f:
        listing = json.load(f)['data']
    decks = []
    with zipfile.ZipFile(os.path.join(work, 'AllDeckFiles.zip')) as z:
        files = {os.path.splitext(os.path.basename(n))[0]: n for n in z.namelist() if n.endswith('.json')}
        for d in listing:
            category = deck_category(d)
            name = files.get(d.get('fileName'))
            if category is None or name is None:
                continue
            data = json.loads(z.read(name))['data']
            cards, cover = [], []
            # Igual ao app: todas as listas do deck (principal, reserva, comandante...).
            for key, value in data.items():
                if not isinstance(value, list):
                    continue
                for item in value:
                    if isinstance(item, dict) and item.get('name'):
                        cards.append(deck_card(item, by_oracle, by_name))
            for item in [*(data.get('commander') or []), *(data.get('mainBoard') or [])]:
                sid = (item.get('identifiers') or {}).get('scryfallId')
                if sid and sid not in cover:
                    cover.append(sid)
                if len(cover) == 3:
                    break
            decks.append({
                'file': d['fileName'],
                'name': d.get('name') or '',
                'code': d.get('code') or '',
                'type': d.get('type') or '',
                'date': d.get('releaseDate') or '',
                'category': category,
                'cover': cover,
                'cards': cards,
            })
    decks.sort(key=lambda d: d['date'], reverse=True)
    return decks


# ----------------------------------------------------------------- imagens

def image_url(card_id, version='normal'):
    return f'https://cards.scryfall.io/{version}/front/{card_id[0]}/{card_id[1]}/{card_id}.jpg'


def fetch_images(cards):
    """Baixa só as imagens que faltam (verso e banners), uma vez."""
    os.makedirs(IMAGES, exist_ok=True)
    wanted = {'traseira_carta.jpg': CARD_BACK}
    by_name = {c[2]: c[0] for c in cards}
    for file, card in BANNERS.items():
        if card in by_name:
            wanted[file] = image_url(by_name[card], 'art_crop')
    for file, url in wanted.items():
        dest = os.path.join(IMAGES, file)
        if not os.path.exists(dest):
            print(f'Baixando {file}...')
            fetch(url, dest)


# -------------------------------------------------------------------- main

def save(name, data):
    os.makedirs(DB, exist_ok=True)
    path = os.path.join(DB, name)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
    return os.path.getsize(path)


def build(work, bulk, offline):
    print('Montando cartas...')
    cards = build_cards(os.path.join(work, 'oracle_cards.json'))
    by_oracle = {c[1]: i for i, c in enumerate(cards)}
    by_name = {c[2].lower(): i for i, c in enumerate(cards)}

    print('Montando edições e traduções...')
    prints = build_prints(os.path.join(work, 'all_cards.json'), by_oracle)

    sizes = {'cards.json': save('cards.json', {'fields': CARD_FIELDS, 'cards': cards})}
    for lang, data in prints.items():
        sizes[f'prints_{lang}.json'] = save(f'prints_{lang}.json', data)
    sizes['sets.json'] = save('sets.json', build_sets(os.path.join(work, 'sets.json')))
    sizes['catalogs.json'] = save('catalogs.json', build_catalogs(work))

    print('Montando decks...')
    decks = build_decks(work, by_oracle, by_name)
    sizes['decks.json'] = save('decks.json', decks)

    symbols = copy_symbols(work, offline)
    if not offline:
        fetch_images(cards)

    meta = {
        'generated': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'scryfall': bulk,
        'cards': len(cards),
        'prints': {lang: len(p['prints']) for lang, p in prints.items()},
        'decks': len(decks),
    }
    save('meta.json', meta)

    print(f'\n{len(cards)} cartas, {len(decks)} decks, {symbols} símbolos novos.')
    for name, size in sizes.items():
        print(f'  {name:<20} {size / 1e6:6.1f} MB')
    print(f'  total                {sum(sizes.values()) / 1e6:6.1f} MB')
    return meta


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--offline', metavar='DIR', help='usar arquivos já baixados em DIR')
    args = parser.parse_args()

    if args.offline:
        build(args.offline, {'offline': True}, offline=True)
        return
    with tempfile.TemporaryDirectory() as work:
        bulk = download_all(work)
        build(work, bulk, offline=False)


if __name__ == '__main__':
    main()
