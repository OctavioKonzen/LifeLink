# 🃏 LifeLink

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter&style=for-the-badge" />
  <img src="https://img.shields.io/badge/React-19-61DAFB?logo=react&style=for-the-badge" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?logo=firebase&style=for-the-badge" />
  <img src="https://img.shields.io/badge/Android-1.0.3-green?logo=android&style=for-the-badge" />
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

Seus decks, sincronizados com a conta: crie um deck novo (Commander, Challenger ou Normal), veja as cartas e o preço total, tire cartas e apague o deck. No app dá também para **importar uma lista** (`4 Lightning Bolt`), **traduzir o deck** para outro idioma e gerar um **PDF para imprimir** as cartas (proxies).

### Decks oficiais

Os decks lançados pela Wizards, separados em **Commander**, **Challenger** e **Avatar / Outros**, com a capa de cada um e a lista completa. Com um toque o deck vai para **Meus decks**.

### Preços de hoje

As cartas mais caras do momento, de todas as edições e idiomas, com pesquisa por nome. Os preços vêm do TCGplayer, atualizados pelo Scryfall uma vez por dia.

### Contador de vida

Feito para a mesa, como os apps do gênero (Lifetap, MTG Companion): de **2 a 6 jogadores**, cada um virado para o seu lado, com vida **20, 30 ou 40**.

* **Toque** na metade esquerda tira 1 de vida, na direita soma 1; **segurando**, vai de 10 em 10. O quanto mudou (ex.: −7) aparece em cima da vida.
* **Contadores** de cada jogador: veneno (até 10), energia, experiência, imposto do comandante e **dano de comandante** de cada oponente (até 21, que também tira vida).
* Cada jogador escolhe **nome e cor**; quem perde fica com a caveira e, quando sobra um, aparece o vencedor.
* No botão do meio: **desfazer**, histórico da partida, reiniciar, dados (D6, D20, moeda) e **quem começa**. A tela não apaga durante a partida.

A partida fica salva e, com a conta, é a mesma no app e no site. Cada partida terminada vale XP para o perfil.

### Perfil e missões

Nível e XP, ganhos ao buscar cartas, ver artes, montar decks e jogar partidas. No app, as **missões da arena** dão recompensas por seção: **avatares** com artes de cartas, **bordas**, **banners** e **títulos**. O site mostra o mesmo perfil, com o nível e os contadores.

### Início (app)

No app, o **Início** tem os atalhos para todas as áreas, as notícias de Magic e o avatar do perfil (no site, os atalhos ficam na barra de cima).

### Conta

Entrar com **Google** ou **e-mail e senha**, sair e excluir a conta. A mesma conta vale no app e no site.

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
