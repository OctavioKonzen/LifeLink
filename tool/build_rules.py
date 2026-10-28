"""As Regras Completas de Magic (Comprehensive Rules) para o juiz de regras do
app e do site (roda na Action rules-data.yml).

Baixa o texto oficial da Wizards (o link mais novo da página de regras),
separa as regras (100.1, 702.19b...) e o glossário, junta o dicionário de
termos em português (para buscar "atropelar" e achar "trample") e grava em
data/rules.json no R2 (com gzip).

Uso:
  python3 tool/build_rules.py                  (precisa das chaves do R2)
  python3 tool/build_rules.py regras.txt       (só lê o arquivo e mostra o resumo)
"""

import gzip
import json
import os
import re
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(__file__))

RULES_PAGE = 'https://magic.wizards.com/en/rules'
HEADERS = {'User-Agent': 'Mozilla/5.0 (LifeLink; github.com/OctavioKonzen/LifeLink)'}

# Termos em português (como aparecem nas cartas e no jogo) → em inglês, como
# estão nas regras. A busca troca o que achar daqui antes de procurar.
PT = {
    # Habilidades de palavra-chave
    'voar': 'flying', 'voa': 'flying', 'voo': 'flying', 'atropelar': 'trample', 'atropela': 'trample',
    'toque mortifero': 'deathtouch', 'vinculo com a vida': 'lifelink', 'golpe duplo': 'double strike',
    'iniciativa': 'first strike', 'vigilancia': 'vigilance', 'alcance': 'reach', 'impeto': 'haste',
    'indestrutivel': 'indestructible', 'resguardo': 'ward', 'resistencia a magia': 'hexproof',
    'manto': 'shroud', 'ameacar': 'menace', 'ameaca': 'menace', 'defensor': 'defender', 'lampejo': 'flash',
    'destreza': 'prowess', 'cascata': 'cascade', 'convocar': 'convoke', 'equipar': 'equip',
    'equipamento': 'equipment', 'protecao': 'protection', 'infectar': 'infect', 'persistir': 'persist',
    'imortal': 'undying', 'recapitular': 'flashback', 'reforcar': 'kicker', 'reforco': 'kicker',
    'reciclar': 'cycling', 'videncia': 'scry', 'triturar': 'mill', 'vigiar': 'surveil',
    'investigar': 'investigate', 'pista': 'clue', 'tesouro': 'treasure', 'comida': 'food', 'sangue': 'blood',
    'proliferar': 'proliferate', 'explorar': 'explore', 'transformar': 'transform', 'dupla face': 'double-faced',
    'mutacao': 'mutate', 'mutar': 'mutate', 'aventura': 'adventure', 'metamorfo': 'changeling',
    'emboscar': 'ambush', 'enfeiticar': 'enchant', 'encantar': 'enchant', 'aura': 'aura',
    'evocar': 'evoke', 'enxertar': 'graft', 'exaltado': 'exalted', 'dissipar': 'fading',
    'despertar': 'awaken', 'emergir': 'emerge', 'escalar': 'escalate', 'extorquir': 'extort',
    'fabricar': 'fabricate', 'fortalecer': 'bolster', 'amplificar': 'amplify', 'anexar': 'attach',
    'ninjutsu': 'ninjutsu', 'morfar': 'morph', 'metamorfose': 'morph', 'disfarce': 'disguise',
    'manifestar': 'manifest', 'encarnar': 'embalm', 'eternizar': 'eternalize', 'desenterrar': 'unearth',
    'dragar': 'dredge', 'afinidade': 'affinity', 'delirio': 'delirium', 'limiar': 'threshold',
    'metalurgia': 'metalcraft', 'carnificina': 'bloodthirst', 'furtividade': 'prowl', 'tropas': 'battalion',
    'banda': 'banding', 'fase': 'phasing', 'desvanecer': 'vanishing', 'suspender': 'suspend',
    'tempestade': 'storm', 'replicar': 'replicate', 'esplice': 'splice', 'reverberar': 'rebound',
    'retorno': 'rebound', 'treinar': 'training', 'treinamento': 'training', 'conjurar': 'conjure',
    'enfrentar': 'fight', 'lutar': 'fight', 'luta': 'fight', 'escudo': 'shield counter',
    'saga': 'saga', 'classe': 'class', 'veiculo': 'vehicle', 'tripular': 'crew', 'pilotar': 'crew',
    'montar': 'saddle', 'iniciar': 'initiative', 'masmorra': 'dungeon', 'aventurar': 'venture',
    'monarca': 'monarch', 'dia e noite': 'day and night', 'noite': 'night', 'dia': 'day',
    'radiacao': 'rad counter', 'cidade abencoada': "city's blessing", 'ascender': 'ascend',
    'energia': 'energy', 'experiencia': 'experience counter', 'veneno': 'poison counter',
    'marcador de veneno': 'poison counter', 'contadores de veneno': 'poison counter',
    'marcadores de veneno': 'poison counter', 'imposto do comandante': 'commander tax',
    # O jogo
    'comandante': 'commander', 'dano de comandante': 'commander damage', 'zona de comando': 'command zone',
    'identidade de cor': 'color identity', 'pilha': 'stack', 'prioridade': 'priority',
    'combate': 'combat', 'atacar': 'attack', 'ataca': 'attack', 'atacante': 'attacking creature',
    'bloquear': 'block', 'bloqueia': 'block', 'bloqueador': 'blocking creature', 'bloqueio': 'block',
    'dano': 'damage', 'dano de combate': 'combat damage', 'ficha': 'token', 'fichas': 'token',
    'marcador': 'counter', 'marcadores': 'counter', 'anular': 'counter', 'anula': 'counter',
    'sacrificar': 'sacrifice', 'sacrifica': 'sacrifice', 'exilar': 'exile', 'exilio': 'exile',
    'cemiterio': 'graveyard', 'grimorio': 'library', 'mao': 'hand', 'campo de batalha': 'battlefield',
    'virar': 'tap', 'virada': 'tapped', 'virado': 'tapped', 'desvirar': 'untap', 'desvirada': 'untapped',
    'manutencao': 'upkeep', 'etapa de compra': 'draw step', 'comprar': 'draw', 'compra': 'draw',
    'descartar': 'discard', 'descarte': 'discard', 'fase principal': 'main phase', 'etapa final': 'end step',
    'limpeza': 'cleanup step', 'turno': 'turn', 'turno extra': 'extra turn', 'mulligan': 'mulligan',
    'ponto de vida': 'life', 'pontos de vida': 'life', 'vida': 'life', 'perder o jogo': 'loses the game',
    'perde o jogo': 'loses the game', 'ganhar o jogo': 'wins the game', 'empate': 'draw game',
    'lendaria': 'legend rule', 'lendario': 'legend rule', 'regra da lenda': 'legend rule',
    'acoes baseadas em estado': 'state-based actions', 'acao baseada em estado': 'state-based actions',
    'copia': 'copy', 'copiar': 'copy', 'clonar': 'copy', 'desencadeada': 'triggered ability',
    'habilidade desencadeada': 'triggered ability', 'gatilho': 'triggered ability',
    'habilidade ativada': 'activated ability', 'ativada': 'activated ability',
    'habilidade estatica': 'static ability', 'estatica': 'static ability',
    'efeito de substituicao': 'replacement effect', 'substituicao': 'replacement effect',
    'efeito de prevencao': 'prevention effect', 'prevenir': 'prevent', 'camadas': 'layer', 'camada': 'layer',
    'dependencia': 'dependency', 'carimbo de tempo': 'timestamp', 'lealdade': 'loyalty',
    'planeswalker': 'planeswalker', 'batalha': 'battle', 'proteger': 'protector', 'defesa': 'defense',
    'criatura': 'creature', 'artefato': 'artifact', 'encantamento': 'enchantment', 'terreno': 'land',
    'instantanea': 'instant', 'magica instantanea': 'instant', 'feitico': 'sorcery', 'magica': 'spell',
    'conjurar magica': 'cast', 'lancar': 'cast', 'jogar terreno': 'play land', 'custo': 'cost',
    'custo de mana': 'mana cost', 'valor de mana': 'mana value', 'custo adicional': 'additional cost',
    'custo alternativo': 'alternative cost', 'mana': 'mana', 'reserva de mana': 'mana pool',
    'incolor': 'colorless', 'multicolorida': 'multicolored', 'alvo': 'target', 'alvos': 'target',
    'controlador': 'controller', 'dono': 'owner', 'oponente': 'opponent', 'jogador': 'player',
    'retirar': 'remove', 'destruir': 'destroy', 'destruida': 'destroy', 'regenerar': 'regenerate',
    'devolver': 'return', 'embaralhar': 'shuffle', 'revelar': 'reveal', 'procurar': 'search',
    'buscar': 'search', 'face para baixo': 'face down', 'face para cima': 'face up',
    'poder': 'power', 'resistencia': 'toughness', 'forca': 'power', 'morrer': 'dies', 'morre': 'dies',
    'morreu': 'dies', 'entrar no campo': 'enters', 'entra no campo': 'enters', 'entrar': 'enters',
    'deixar o campo': 'leaves the battlefield', 'sai do campo': 'leaves the battlefield',
    'sair do campo': 'leaves the battlefield', 'trocar de controle': 'control', 'controle': 'control',
    'emblema': 'emblem', 'plano': 'plane', 'planechase': 'planechase', 'arquiinimigo': 'archenemy',
    'esquema': 'scheme', 'multijogador': 'multiplayer', 'gigante de duas cabecas': 'two-headed giant',
    'dano letal': 'lethal damage', 'atropelar dano': 'trample', 'atacar planeswalker': 'attack planeswalker',
    'sideboard': 'sideboard', 'banco': 'sideboard', 'baralho': 'deck', 'deck': 'deck',
}

# Palavras que não ajudam na busca (português e inglês).
STOP = sorted({
    'a', 'o', 'as', 'os', 'um', 'uma', 'uns', 'umas', 'de', 'do', 'da', 'dos', 'das', 'em', 'no', 'na', 'nos', 'nas',
    'por', 'para', 'pra', 'com', 'sem', 'e', 'ou', 'que', 'se', 'como', 'quando', 'qual', 'quais', 'quem', 'onde',
    'pode', 'posso', 'podem', 'consigo', 'tem', 'ter', 'tenho', 'faz', 'fazer', 'acontece', 'acontecer', 'isso',
    'isto', 'esse', 'essa', 'este', 'esta', 'ele', 'ela', 'eles', 'elas', 'meu', 'minha', 'seu', 'sua', 'mais',
    'menos', 'muito', 'ja', 'nao', 'sim', 'e', 'ao', 'aos', 'mesmo', 'mesma', 'outra', 'outro', 'carta', 'cartas',
    'regra', 'regras', 'funciona', 'vale', 'conta', 'contra', 'sobre', 'depois', 'antes', 'ainda', 'so', 'tambem',
    'the', 'an', 'of', 'to', 'in', 'on', 'is', 'it', 'and', 'or', 'if', 'can', 'does', 'what', 'how', 'with', 'my',
    'your', 'that', 'this', 'be', 'are', 'for', 'when', 'from', 'by', 'at',
})


def latest_rules_url():
    page = urllib.request.urlopen(urllib.request.Request(RULES_PAGE, headers=HEADERS), timeout=60).read().decode('utf-8', 'replace')
    links = re.findall(r'https://media\.wizards\.com/[^"\'<>]+?\.txt', page)
    if not links:
        raise SystemExit('Não achei o link do texto das regras na página da Wizards.')
    return links[0].replace(' ', '%20')


def decode(raw):
    for enc in ('utf-8-sig', 'cp1252'):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode('utf-8', 'replace')


RULE = re.compile(r'^(\d{3}\.\d+[a-z]?)\.?\s+(.*)$')
SECTION = re.compile(r'^(\d{3})\.\s+(.+)$')
CHAPTER = re.compile(r'^(\d)\.\s+(.+)$')


def parse(text):
    """O texto das regras → { effective, sections, rules: [[id, texto]], glossary: [[termo, texto]] }."""
    lines = [line.strip().replace('’', "'").replace('“', '"').replace('”', '"') for line in text.splitlines()]
    effective = ''
    for line in lines[:40]:
        m = re.search(r'effective as of (.+?)\.?$', line)
        if m:
            effective = m.group(1)
            break
    # "Glossary" e "Credits" aparecem no índice e depois de verdade: vale a última vez.
    glossary_at = max(i for i, line in enumerate(lines) if line == 'Glossary')
    credits_at = max(i for i, line in enumerate(lines) if line == 'Credits')
    # As regras começam no segundo "1. Game Concepts" (o primeiro é o índice).
    starts = [i for i, line in enumerate(lines) if CHAPTER.match(line) and line.startswith('1.')]
    body_at = starts[1] if len(starts) > 1 else starts[0]

    rules, sections = [], {}
    for line in lines[body_at:glossary_at]:
        if not line:
            continue
        m = RULE.match(line)
        if m:
            rules.append([m.group(1), m.group(2).strip()])
            continue
        m = SECTION.match(line)
        if m:
            sections[m.group(1)] = m.group(2).strip()
            continue
        if CHAPTER.match(line):
            continue
        if rules:  # "Example: ..." e continuações ficam na regra de cima
            rules[-1][1] += '\n' + line

    glossary, block = [], []
    for line in lines[glossary_at + 1:credits_at] + ['']:
        if line:
            block.append(line)
        elif block:
            glossary.append([block[0], '\n'.join(block[1:])])
            block = []
    return {'effective': effective, 'sections': sections, 'rules': rules, 'glossary': glossary}


def main():
    if len(sys.argv) > 1:
        with open(sys.argv[1], 'rb') as f:
            text, url = decode(f.read()), sys.argv[1]
    else:
        url = latest_rules_url()
        print('regras:', url, flush=True)
        text = decode(urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=120).read())
    data = parse(text)
    data.update({'source': url, 'pt': PT, 'stop': STOP})
    print(f"vigentes desde {data['effective']}: {len(data['rules'])} regras, {len(data['sections'])} seções, {len(data['glossary'])} termos no glossário", flush=True)
    if len(data['rules']) < 1500 or len(data['glossary']) < 300:
        raise SystemExit('Poucas regras lidas: o formato do arquivo deve ter mudado.')
    body = gzip.compress(json.dumps(data, ensure_ascii=False, separators=(',', ':')).encode())
    print(f'rules.json: {len(body) / 1e3:.0f} KB (gzip)', flush=True)
    if len(sys.argv) > 1:
        return
    from build_cards import r2
    r2().put_object(
        Bucket=os.environ.get('R2_BUCKET', 'lifelink'),
        Key='data/rules.json',
        Body=body,
        ContentType='application/json; charset=utf-8',
        ContentEncoding='gzip',
        CacheControl='public, max-age=86400',
    )
    print('gravado em data/rules.json', flush=True)


if __name__ == '__main__':
    main()
