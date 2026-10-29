"""Publica firestore.rules no Firebase (roda na Action rules.yml, na main).

Usa a API de regras do Firebase (firebaserules) direto: cria um conjunto de
regras novo com o arquivo e aponta o Firestore para ele. A chave padrão da
conta de serviço do Firebase (firebase-adminsdk) já pode fazer isso.

Uso: SERVICE_ACCOUNT='<o JSON da chave>' python3 tool/deploy_firestore_rules.py
"""

import json
import os
import sys

from google.auth.transport.requests import AuthorizedSession
from google.oauth2 import service_account

API = 'https://firebaserules.googleapis.com/v1'


def main():
    info = json.loads(os.environ['SERVICE_ACCOUNT'])
    creds = service_account.Credentials.from_service_account_info(info, scopes=['https://www.googleapis.com/auth/cloud-platform'])
    project = os.environ.get('FIREBASE_PROJECT') or info['project_id']
    http = AuthorizedSession(creds)
    with open(os.path.join(os.path.dirname(__file__), '..', 'firestore.rules'), encoding='utf-8') as f:
        source = f.read()

    r = http.post(f'{API}/projects/{project}/rulesets', json={'source': {'files': [{'name': 'firestore.rules', 'content': source}]}})
    if r.status_code != 200:
        sys.exit(f'Não deu para criar as regras ({r.status_code}): {r.text[:500]}')
    ruleset = r.json()['name']
    print('regras novas:', ruleset, flush=True)

    release = f'projects/{project}/releases/cloud.firestore'
    r = http.patch(f'{API}/{release}', json={'release': {'name': release, 'rulesetName': ruleset}})
    if r.status_code == 404:  # o Firestore ainda não tinha regras publicadas
        r = http.post(f'{API}/projects/{project}/releases', json={'name': release, 'rulesetName': ruleset})
    if r.status_code != 200:
        sys.exit(f'Não deu para publicar as regras ({r.status_code}): {r.text[:500]}')
    print('publicadas no Firestore de', project, flush=True)


if __name__ == '__main__':
    main()
