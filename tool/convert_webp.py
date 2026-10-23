"""Comprime de novo as imagens das cartas no R2 (roda na Action
images-webp.yml): cada imagem fica em WebP com a qualidade QUALITY (e, com
WIDTH, com essa largura), com o mesmo nome (img/<id>.jpg). Continua de onde
parou (a lista das prontas fica em data/webp-q<QUALITY>-done.txt.gz).

Com SAMPLE=<n>, só testa: pega n imagens, mostra quanto cada qualidade
diminuiria o total, e não muda nada.

Uso: python3 tool/convert_webp.py   (precisa das chaves do R2)
Variáveis: R2_BUCKET (lifelink), QUALITY, WIDTH, SAMPLE, MAX_MINUTES (300).
"""

import concurrent.futures
import gzip
import os
import random
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from build_cards import WEBP_QUALITY, r2, to_webp  # noqa: E402

TRIES = [(82, None), (75, None), (70, None), (65, None), (60, None), (75, 440), (70, 440), (65, 440)]


def list_images(s3, bucket):
    keys = {}
    for page in s3.get_paginator('list_objects_v2').paginate(Bucket=bucket, Prefix='img/'):
        for o in page.get('Contents', []):
            keys[o['Key']] = o['Size']
    return keys


def sample(s3, bucket, keys, n):
    picked = random.Random(1).sample(sorted(keys), n)
    total = sum(keys.values())
    now = sum(keys[k] for k in picked)
    sizes = {t: 0 for t in TRIES}

    def one(key):
        data = s3.get_object(Bucket=bucket, Key=key)['Body'].read()
        return {t: len(to_webp(data, quality=t[0], width=t[1])[0]) for t in TRIES}

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        for result in pool.map(one, picked):
            for t, size in result.items():
                sizes[t] += size
    print(f'{n} imagens de teste: {now / 1e6:.1f} MB hoje; todas: {total / 1e9:.2f} GB', flush=True)
    for (q, w), size in sizes.items():
        ratio = size / now
        print(f'  qualidade {q}{f", largura {w}" if w else ""}: {100 * ratio:.0f}% → imagens com ~{total * ratio / 1e9:.2f} GB', flush=True)


def main():
    started = time.time()
    deadline = started + int(os.environ.get('MAX_MINUTES', '300')) * 60
    bucket = os.environ.get('R2_BUCKET', 'lifelink')
    quality = int(os.environ.get('QUALITY') or WEBP_QUALITY)
    width = int(os.environ['WIDTH']) if os.environ.get('WIDTH') else None
    s3 = r2()
    keys = list_images(s3, bucket)
    if os.environ.get('SAMPLE'):
        return sample(s3, bucket, keys, int(os.environ['SAMPLE']))

    done_key = f'data/webp-q{quality}{f"-w{width}" if width else ""}-done.txt.gz'
    try:
        done = set(gzip.decompress(s3.get_object(Bucket=bucket, Key=done_key)['Body'].read()).decode().split())
    except Exception:
        done = set()
    todo = [k for k in sorted(keys) if k not in done]
    print(f'qualidade {quality}: {len(done)} prontas; faltam {len(todo)}', flush=True)

    before = after = 0

    def one(key):
        data = s3.get_object(Bucket=bucket, Key=key)['Body'].read()
        body, kind = to_webp(data, quality=quality, width=width)
        if body is not data:
            s3.put_object(Bucket=bucket, Key=key, Body=body, ContentType=kind, CacheControl='public, max-age=31536000')
        return key, len(data), len(body)

    def save():
        s3.put_object(Bucket=bucket, Key=done_key, Body=gzip.compress('\n'.join(sorted(done)).encode()), ContentType='application/gzip')

    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
        for start in range(0, len(todo), 2000):
            if time.time() > deadline:
                break
            for key, a, b in pool.map(one, todo[start:start + 2000]):
                done.add(key)
                before += a
                after += b
            save()
            pct = f' ({100 * after / before:.0f}% do tamanho)' if before else ''
            print(f'{min(start + 2000, len(todo))}/{len(todo)}: {before / 1e9:.2f} GB viraram {after / 1e9:.2f} GB{pct}', flush=True)
    print(f'faltam {len([k for k in todo if k not in done])}', flush=True)


if __name__ == '__main__':
    main()
