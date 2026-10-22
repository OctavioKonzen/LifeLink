"""Prepara a conta da Cloudflare para o Worker (roda na Action cloud.yml):
o endereço workers.dev da conta e o banco D1 "lifelink". Escreve o id do
banco no cloud/wrangler.toml e mostra o endereço do Worker.

Precisa de CLOUDFLARE_API_TOKEN e CLOUDFLARE_ACCOUNT_ID.
"""

import json
import os
import sys
import urllib.error
import urllib.request

ACCOUNT = os.environ['CLOUDFLARE_ACCOUNT_ID']
TOKEN = os.environ['CLOUDFLARE_API_TOKEN']
API = f'https://api.cloudflare.com/client/v4/accounts/{ACCOUNT}'


def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method, data=json.dumps(body).encode() if body is not None else None,
                                 headers={'Authorization': f'Bearer {TOKEN}', 'Content-Type': 'application/json'})
    try:
        return json.load(urllib.request.urlopen(req, timeout=60))
    except urllib.error.HTTPError as e:
        return json.loads(e.read() or b'{}') | {'success': False, 'status': e.code}


def subdomain():
    got = call('GET', '/workers/subdomain')
    if got.get('success') and got.get('result', {}).get('subdomain'):
        return got['result']['subdomain']
    # Conta nova: escolhe um endereço livre.
    for name in ('lifelink', 'lifelink-mtg', 'lifelink-app', f'lifelink-{ACCOUNT[:6]}'):
        made = call('PUT', '/workers/subdomain', {'subdomain': name})
        if made.get('success'):
            return made['result']['subdomain']
    sys.exit(f'Não deu para criar o endereço workers.dev: {made}')


def database():
    found = call('GET', '/d1/database?name=lifelink')
    for db in found.get('result') or []:
        if db.get('name') == 'lifelink':
            return db['uuid']
    made = call('POST', '/d1/database', {'name': 'lifelink'})
    if not made.get('success'):
        sys.exit(f'Não deu para criar o banco D1 (o token tem a permissão D1 → Edit?): {made}')
    return made['result']['uuid']


def main():
    sub = subdomain()
    uuid = database()
    path = os.path.join(os.path.dirname(__file__), '..', 'cloud', 'wrangler.toml')
    text = open(path).read().replace('__D1_ID__', uuid)
    open(path, 'w').write(text)
    url = f'https://lifelink-cards.{sub}.workers.dev'
    print(f'Banco D1: {uuid}\nWorker: {url}')
    out = os.environ.get('GITHUB_OUTPUT')
    if out:
        with open(out, 'a') as f:
            f.write(f'url={url}\n')


if __name__ == '__main__':
    main()
