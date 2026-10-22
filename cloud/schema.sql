-- Busca de cartas do LifeLink (Cloudflare D1). Uma linha por carta, com o
-- texto em inglês e em português; o resto (variações, preços, imagens) fica
-- em arquivos no R2 (tool/build_cards.py). Carregado por tool/load_d1.py.
CREATE TABLE IF NOT EXISTS cards (
  k INTEGER PRIMARY KEY,
  o TEXT NOT NULL,   -- oracle_id (arquivo c/<o>.json no R2)
  id TEXT,           -- a versão principal (imagem)
  n TEXT, pn TEXT,   -- nome em inglês e em português
  t TEXT, pt TEXT,   -- tipo
  x TEXT, px TEXT,   -- texto
  ss TEXT,           -- coleções em que saiu (códigos separados por espaço)
  m TEXT,            -- custo de mana
  cmc REAL,
  ci TEXT,           -- identidade de cor (WUBRG)
  r TEXT,            -- raridade da versão principal
  er INTEGER,        -- posição no EDHREC (popularidade; menor = mais usada)
  d TEXT,            -- data da versão mais nova
  usd REAL,
  img INTEGER        -- a imagem da versão principal já está no R2
);
CREATE INDEX IF NOT EXISTS cards_er ON cards(er);
CREATE VIRTUAL TABLE IF NOT EXISTS cards_fts USING fts5(
  n, pn, t, pt, x, px, ss,
  content='cards', content_rowid='k',
  tokenize='unicode61 remove_diacritics 2'
);
