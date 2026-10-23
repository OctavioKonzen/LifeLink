"""Converte as imagens das cartas no R2 de JPG para WebP (roda na Action
images-webp.yml). Cada imagem fica com o mesmo nome (img/<id>.jpg) e cerca de
metade do tamanho; as que já estão em WebP ficam como estão. Continua de onde
parou (a lista das prontas fica em data/webp-done.txt.gz).

Uso: python3 tool/convert_webp.py   (precisa das chaves do R2)
Variáveis: R2_BUCKET (lifelink), MAX_MINUTES (300).
"""

import concurrent.futures
import gzip
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from build_cards import r2, to_webp  # noqa: E402

DONE_KEY = 'data/webp-done.txt.gz'


def main():
    started = time.time()
    deadline = started + int(os.environ.get('MAX_MINUTES', '300')) * 60
    bucket = os.environ.get('R2_BUCKET', 'lifelink')
    s3 = r2()
    try:
        done = set(gzip.decompress(s3.get_object(Bucket=bucket, Key=DONE_KEY)['Body'].read()).decode().split())
    except Exception:
        done = set()

    keys = []
    for page in s3.get_paginator('list_objects_v2').paginate(Bucket=bucket, Prefix='img/'):
        keys += [o['Key'] for o in page.get('Contents', []) if o['Key'] not in done]
    print(f'{len(done)} já em WebP; faltam {len(keys)}', flush=True)

    before = after = 0

    def one(key):
        obj = s3.get_object(Bucket=bucket, Key=key)
        if obj.get('ContentType') == 'image/webp':
            return key, 0, 0
        data = obj['Body'].read()
        body, kind = to_webp(data)
        if kind == 'image/webp':
            s3.put_object(Bucket=bucket, Key=key, Body=body, ContentType=kind, CacheControl='public, max-age=31536000')
        return key, len(data), len(body)

    def save():
        s3.put_object(Bucket=bucket, Key=DONE_KEY, Body=gzip.compress('\n'.join(sorted(done)).encode()), ContentType='application/gzip')

    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
        for start in range(0, len(keys), 2000):
            if time.time() > deadline:
                break
            for key, a, b in pool.map(one, keys[start:start + 2000]):
                done.add(key)
                before += a
                after += b
            save()
            pct = f' ({100 * after / before:.0f}% do tamanho)' if before else ''
            print(f'{min(start + 2000, len(keys))}/{len(keys)}: {before / 1e9:.2f} GB viraram {after / 1e9:.2f} GB{pct}', flush=True)
    left = len([k for k in keys if k not in done])
    print(f'faltam {left}', flush=True)


if __name__ == '__main__':
    main()
