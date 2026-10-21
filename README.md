# 🃏 LifeLink

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter&style=for-the-badge" />
  <img src="https://img.shields.io/badge/React-19-61DAFB?logo=react&style=for-the-badge" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?logo=firebase&style=for-the-badge" />
  <img src="https://img.shields.io/badge/Android-1.0.14-green?logo=android&style=for-the-badge" />
</p>

<div align="center">
  <h3>Contador de vida, busca de cartas, decks e preços de Magic: The Gathering</h3>
  <p>App Android e site com a mesma conta: o que você faz em um aparece no outro.</p>
  <p>🌐 <a href="https://octaviokonzen.github.io/LifeLink/"><b>Abrir o site</b></a> · 📥 <a href="https://github.com/OctavioKonzen/LifeLink/releases/latest"><b>Baixar o APK</b></a></p>
</div>

---

## 📑 Sumário

- [Telas principais](#-telas-principais)
  - [Cartas](#cartas) · [Carta](#carta) · [Meus decks](#meus-decks) · [Decks oficiais](#decks-oficiais) · [Preços de hoje](#preços-de-hoje) · [Contador de vida](#contador-de-vida) · [Perfil e missões](#perfil-e-missões) · [Início (app)](#início-app) · [Conta](#conta) · [Configurações](#configurações)
- [Conta e sincronização](#-conta-e-sincronização)
- [Ferramentas](#️-ferramentas-usadas) · [Como usar](#-como-usar) · [Como rodar o código](#-como-rodar-o-código) · [Créditos](#-créditos)

> As telas são as mesmas no app (celular Android) e no site (computador ou celular): mesmo visual, mesmas regras e mesma conta.

---

## 🧭 Telas principais

### Cartas

A busca procura pelo **nome em português ou inglês** ("Raio" encontra "Lightning Bolt") e também pelo **texto da carta**, em inglês ("flying", "destroy target creature"). Enquanto você digita aparecem **sugestões de nomes**, e as **buscas recentes** ficam guardadas. Os **filtros** separam por cor, tipo, raça de criatura e edição. Quem conhece a sintaxe do Scryfall (`t:dragon c:r`, `o:"draw a card"`) pode usar direto.

### Carta

A ficha de cada carta: imagem em **alta qualidade** (PNG), frente e verso nas cartas de duas faces, custo de mana, tipo, texto, poder e resistência, edição, raridade e artista. Mostra os **preços** (normal, foil, euro e MTGO), os **formatos** em que é legal ou banida e as **outras versões** em vários idiomas (português, inglês, japonês, espanhol, francês, alemão e italiano), para trocar a arte. Daqui você **adiciona a carta a um deck**.

### Meus decks

Seus decks, sincronizados com a conta: crie um deck novo (Commander, Challenger ou Normal), veja as cartas e o preço total, tire cartas e apague o deck.

* **Importar lista** (app e site): cole a lista exportada do **Moxfield, Archidekt, MTG Arena ou MTGO** (`1 Sol Ring (CMM) 410`, `4x Lightning Bolt`, com seções de comandante, banco e "talvez") para criar um deck novo ou somar a um deck. As cartas vêm da Scryfall de 75 em 75.
* **Preço e legalidade**: o valor do deck hoje em dólar, **real** e euro, as cartas mais caras e se o deck é legal em Commander, Standard, Pioneer, Modern, Legacy, Vintage e Pauper (tamanho, cópias, banidas e restritas).
* **Mão de teste**: compra 7, **mulligan de Londres** (põe uma no fundo por mulligan) e comprar as próximas.
* No app dá também para **traduzir o deck** para outro idioma e gerar um **PDF para imprimir** as cartas (proxies).

### Decks oficiais

Os decks lançados pela Wizards, separados em **Commander**, **Challenger**, **Secret Lair** (as coleções especiais da Wizards) e **Iniciante** (decks para começar: Starter, Planeswalker e os do Avatar), com a capa de cada um e a lista completa. Com um toque o deck vai para **Meus decks**.

### Preços de hoje

As cartas mais caras do momento, de todas as edições e idiomas, com pesquisa por nome. Os preços vêm do TCGplayer, atualizados pelo Scryfall uma vez por dia.

### Contador de vida

Feito para a mesa, como os apps do gênero (Lifetap, MTG Companion): de **2 a 6 jogadores**, cada um virado para o seu lado, com vida inicial **à vontade** (20, 25, 30, 40, 50, 60 ou outra).

* **Toque** na metade esquerda tira 1 de vida, na direita soma 1; **segurando**, vai de 1 em 1, cada vez mais rápido (no site também). O quanto mudou (ex.: −7) aparece em cima da vida.
* **Contadores** de cada jogador: veneno (até 10), energia, experiência, imposto do comandante, tesouro, tempestade, cidade abençoada e **dano de comandante** de cada oponente (até 21, que também tira vida).
* **Monarca** e **iniciativa**: a coroa e o castelo aparecem no quadro de quem tem.
* **Turnos**: a vez passa no sentido horário (pulando quem morreu), com a rodada e o **cronômetro** no quadro de quem joga e o tempo total de cada um. O "quem começa" já começa a contar.
* **Planechase** (o plano em jogo e o **dado planar 3D**, com o custo de cada rolagem extra na mesma vez) e **Archenemy** (revelar esquemas), com as cartas sorteadas da Scryfall.
* **Histórico de vida** de cada jogador: gráfico e a lista de cada mudança (dano, cura e comandante).
* Cada jogador escolhe **nome e cor** (18 cores, com dois verdes para mesas grandes, e uma segunda cor para o quadro virar um degradê, como deck de duas cores); quem perde fica com a caveira e, quando sobra um, aparece o vencedor.
* No botão do meio: **desfazer**, histórico da partida, reiniciar, **dados 3D com física** (D4, D6, D8, D10, D12, D20 e o D100 de uma peça só, de 1 a 100: jogados numa mesa, quicam, batem um no outro com som e vale a face que fica para cima), moeda e **quem começa** (cada jogador joga um D20 que cai em cima do quadro dele; empate joga de novo).
* **Sons** de dano, cura, veneno, dano de comandante e morte (dá para desligar). A tela não apaga durante a partida.

A partida fica salva e, com a conta, é a mesma no app e no site. Cada partida terminada vale XP para o perfil.

### Mesa online e amigos

* **Mesa online**: no contador, "Mesa online" cria uma mesa com um **código de 6 letras**; cada um entra com o código no próprio celular (app) ou no site e a vida, os contadores e a vez de todos aparecem **em tempo real** em todos. Cada jogador fica num pedaço separado da mesa, então dois celulares mexendo ao mesmo tempo não se atrapalham. O dono fecha a mesa para todos.
* **Amigos pelo nick**: peça amizade pelo nick, aceite os pedidos, veja os **decks dos amigos** (e copie para os seus) e **convide amigos** para a sua mesa online. No app fica no menu do início → Amigos; no site, no Perfil.

### Partidas e estatísticas

Cada partida terminada no contador vai para o **histórico** (na conta, igual no app e no site): quem ganhou, quem jogou e com qual **deck**, a duração, as rodadas e o gráfico da vida de todos. As **estatísticas** mostram as vitórias de cada jogador e de cada deck/comandante, a duração média e a partida com mais rodadas. O deck de cada jogador é escolhido no contador (no nome do jogador, no app; nos contadores, no site).

### Perfil e missões

Nível e XP, ganhos ao buscar cartas, ver artes, montar decks e jogar partidas. No app, as **missões da arena** dão recompensas por seção: **avatares** com artes de cartas, **bordas**, **banners** e **títulos**. O site mostra o mesmo perfil, com o nível e os contadores.

### Início (app)

No app, o **Início** tem os atalhos para todas as áreas, as notícias de Magic e o avatar do perfil (no site, os atalhos ficam na barra de cima).

### Conta

Entrar ou **criar conta** (com e-mail e senha ou **Google**), sempre com um **nick**: quem entra com Google pela primeira vez escolhe o nick antes de entrar. Sair e excluir a conta. A mesma conta vale no app e no site.

### Configurações

No app: cor do fundo, idioma do app e das cartas (português ou inglês), a versão instalada e o botão **Procurar atualização**.

---

## 🔄 Conta e sincronização

* **Sem conta**, tudo fica salvo no aparelho (ou no navegador).
* **Com conta**, os decks, o perfil, o nível, as missões, as preferências e a partida do contador vão para a nuvem e são **sincronizados em tempo real**, nos dois sentidos: o que você muda no celular aparece no site na hora, e vice-versa.
* Ao entrar, os decks feitos sem conta entram nela, e fica o perfil com mais XP. Ao sair, os dados da conta saem do aparelho.
* Cada pessoa só lê e grava os próprios dados (regras em [`firestore.rules`](firestore.rules)).

## 🛠️ Ferramentas usadas

| Parte | Ferramentas |
|---|---|
| **App (Android)** | Flutter / Dart, Provider |
| **Site** | React, Vite, Tailwind CSS, React Router |
| **Dados 3D** (site e app) | [three.js](https://threejs.org) e física [cannon-es](https://github.com/pmndrs/cannon-es); no app, a mesma mesa numa WebView (`assets/dice`, gerada com `npm run build:dice`) |
| **Cartas, preços e imagens** | API do [Scryfall](https://scryfall.com/docs/api) |
| **Decks oficiais** | [MTGJSON](https://mtgjson.com) |
| **Conta e dados online** | Firebase Authentication e Firestore |
| **Publicação** | GitHub Actions (conferência automática, site no GitHub Pages e APK em Releases) |

## 📥 Como usar

* **Site:** https://octaviokonzen.github.io/LifeLink/
* **App:** no site, toque em **Baixar o app para Android (APK)** (ou vá em [Releases](https://github.com/OctavioKonzen/LifeLink/releases/latest)), instale o `LifeLink.apk` e entre com a mesma conta do site. O próprio app avisa quando sai uma versão nova. Celular antigo, de 32 bits: use o `LifeLink_32bits.apk`.

## 🚀 Como rodar o código

```bash
git clone https://github.com/OctavioKonzen/LifeLink.git
cd LifeLink

# App
flutter pub get
flutter run

# Site
cd web-site
npm install
npm run dev
```

**Publicar uma versão nova do app:** aumente a `version` no `pubspec.yaml` (ex.: `1.0.1+2`) e junte na `main`. O workflow **App Android (APK)** gera o APK assinado e publica em Releases. A chave de assinatura fica criptografada em `android/app/lifelink.jks.enc` (criada pelo workflow **Chave do APK**), com a senha no secret `ANDROID_KEYSTORE_PASSWORD`.

## 🙏 Créditos

* Dados, preços, imagens das cartas e símbolos de mana: [Scryfall](https://scryfall.com).
* Decks oficiais: [MTGJSON](https://mtgjson.com).
* Magic: The Gathering, os nomes, textos e imagens das cartas são da Wizards of the Coast. O LifeLink é um projeto de fã, gratuito, sem ligação com a Wizards of the Coast nem com o Scryfall.
