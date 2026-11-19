import 'dart:convert';

// Os dados que vão para a conta (users/{uid} no Firestore). O formato é o
// mesmo do site (web-site/src/lib/userData.js):
//   data.settings: { bgColor, playerName, cardLanguage }
//   data.profile:  { xp, level, tier, claimedMissions, unlocked*, selected*,
//                    totalMatches, statDecks, statCards, statSearches, statArts }
//   data.game:     { playerCount, startingLife, lives, poison, cmdRows,
//                    playerNames, playerDecks, ... (game_provider.dart) }
//   data.matches:  { list: [partidas terminadas] } (match_provider.dart)
//   data.collection, data.wishlist: { list: [cartas] } (collection_provider.dart)
//   decks/{id}:    { id, name, type, cards }   (um documento por deck)
// O Firestore não aceita lista dentro de lista (o dano de comandante vai
// como cmdRows, uma linha de texto por jogador).
//
// Cada provider registra a sua parte aqui: como ler, como aplicar o que
// chegou da conta e como voltar ao padrão (ao sair da conta).

class SyncedSection {
  final String key;
  final Map<String, dynamic> Function() read;

  /// Aplica o que veio da conta; null = volta ao padrão.
  final Future<void> Function(Map<String, dynamic>? value) apply;

  const SyncedSection({required this.key, required this.read, required this.apply});
}

/// O que a conta tem de cada parte (o último que chegou ou que foi gravado
/// daqui), em texto. Uma parte igual a essa não é aplicada de novo: senão,
/// qualquer mudança na conta (XP, coleção...) trazia de volta a partida
/// guardada, por cima da que está acontecendo (os números pulavam).
class RemoteSeen {
  final Map<String, String> _seen = {};

  /// O valor em texto, com os campos em ordem (o Firestore pode mudar a ordem).
  static String text(Object? v) => jsonEncode(_sorted(v), toEncodable: (o) => o.toString());

  static Object? _sorted(Object? v) => switch (v) {
        Map m => {for (final k in (m.keys.map((k) => '$k').toList()..sort())) k: _sorted(m[k])},
        List l => [for (final x in l) _sorted(x)],
        _ => v,
      };

  /// Chegou da conta: volta as partes que não mudaram desde a última vez
  /// (essas não são aplicadas) e guarda as novas.
  Set<String> unchanged(Map<String, dynamic> data) {
    final same = <String>{};
    for (final e in data.entries) {
      final t = text(e.value);
      if (_seen[e.key] == t) same.add(e.key);
      _seen[e.key] = t;
    }
    return same;
  }

  /// Gravou na conta: é isso que a conta tem agora.
  void wrote(Map<String, dynamic> changes) {
    for (final e in changes.entries) {
      _seen[e.key] = text(e.value);
    }
  }

  void clear() => _seen.clear();
}

/// Os decks ficam um por documento (o Firestore limita cada documento a 1 MB).
abstract class SyncedDecks {
  Map<String, Map<String, dynamic>> readDecks();

  /// Troca os decks pelos da conta, mantendo os de [keep] (mudados aqui e
  /// ainda não gravados).
  Future<void> applyDecks(Map<String, Map<String, dynamic>> remote, {Set<String> keep = const {}});

  Future<void> clearDecks();
}

class UserData {
  UserData._();
  static final UserData instance = UserData._();

  static const sectionKeys = ['settings', 'profile', 'game', 'matches', 'collection', 'wishlist'];

  /// Partes que a conta só traz ao entrar (depois, cada aparelho fica com a
  /// sua). A partida do contador: dois aparelhos (ou o site) na mesma conta
  /// com o contador aberto trocavam a partida um do outro, e os números
  /// mudavam e trocavam de lugar sozinhos. Para jogar a mesma partida em
  /// vários celulares existe a mesa online.
  static const onlyAtStart = {'game'};

  /// As partes que chegaram da conta e NÃO são aplicadas: as mudadas aqui e
  /// ainda não gravadas ([dirty]), as que não mudaram na conta
  /// ([unchanged]), as de [onlyAtStart] depois da primeira vez ([started])
  /// e, na mesa online ([onlineTable]), a partida.
  static Set<String> keepLocal({Set<String> dirty = const {}, Set<String> unchanged = const {}, required bool started, bool onlineTable = false}) => {
        ...dirty,
        ...unchanged,
        if (started) ...onlyAtStart,
        if (onlineTable) 'game',
      };

  final Map<String, SyncedSection> _sections = {};
  SyncedDecks? decks;

  /// Avisado quando algo muda aqui no aparelho (AccountSync grava na conta).
  void Function(String section)? onLocalChange;
  void Function(String deckId, {bool deleted})? onDeckChange;

  bool _applying = false;

  /// Aplicando o que veio da conta agora (não foi mudado neste aparelho).
  bool get applying => _applying;

  void register(SyncedSection section) => _sections[section.key] = section;

  Iterable<SyncedSection> get sections => _sections.values;

  /// Um provider gravou uma parte: vai para a conta (se não veio dela).
  void changed(String key) {
    if (!_applying) onLocalChange?.call(key);
  }

  void deckChanged(String id, {bool deleted = false}) {
    if (!_applying) onDeckChange?.call(id, deleted: deleted);
  }

  Map<String, dynamic> snapshot(Iterable<String> keys) => {
        for (final k in keys)
          if (_sections[k] != null) k: _sections[k]!.read(),
      };

  /// Aplica o que veio da conta sem gravar de volta nela.
  Future<void> applyRemote(Map<String, dynamic> data, {Set<String> except = const {}}) async {
    _applying = true;
    try {
      for (final s in _sections.values) {
        if (except.contains(s.key) || !data.containsKey(s.key)) continue;
        final value = data[s.key];
        await s.apply(value is Map ? Map<String, dynamic>.from(value) : null);
      }
    } finally {
      _applying = false;
    }
  }

  Future<void> applyRemoteDecks(Map<String, Map<String, dynamic>> remote, {Set<String> keep = const {}}) async {
    _applying = true;
    try {
      await decks?.applyDecks(remote, keep: keep);
    } finally {
      _applying = false;
    }
  }

  /// Saiu da conta: os dados dela não ficam no aparelho.
  Future<void> clearAll() async {
    _applying = true;
    try {
      for (final s in _sections.values) {
        await s.apply(null);
      }
      await decks?.clearDecks();
    } finally {
      _applying = false;
    }
  }
}
