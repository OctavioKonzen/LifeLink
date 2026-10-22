import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../account/user_data.dart';

/// Os contadores extras de cada jogador (além de vida e dano de comandante).
enum Counter { poison, energy, experience, tax, treasure, storm, blessing, radiation }

/// Uma mudança na partida, para o histórico e o "desfazer".
class GameEvent {
  final int player;
  final String kind; // 'life', 'cmd' ou o nome de um Counter ('poison', 'treasure'...)
  final int delta;
  final int? attacker; // só no dano de comandante
  final DateTime at;
  GameEvent(this.player, this.kind, this.delta, {this.attacker}) : at = DateTime.now();
}

/// A partida do contador de vida (a mesma no app e no site, pela conta).
class GameProvider with ChangeNotifier {
  static const maxPlayers = 6;

  /// Cores dos jogadores (o jogador escolhe uma delas).
  static const List<Color> palette = [
    Color(0xFF6A3DE8), // roxo
    Color(0xFF1BA655), // verde
    Color(0xFFD32F2F), // vermelho
    Color(0xFF1E6FE0), // azul
    Color(0xFFE08A1E), // laranja
    Color(0xFF00897B), // verde-água
    Color(0xFFC2185B), // rosa
    Color(0xFF5D4037), // marrom
    Color(0xFF455A64), // grafite
    Color(0xFFB8860B), // dourado
    // Mais cores para mesas grandes (ex.: dois verdes). As 10 de cima ficam
    // na mesma ordem: o número salvo de cada jogador continua valendo.
    Color(0xFF7CB342), // verde-claro
    Color(0xFF1B5E20), // verde-escuro
    Color(0xFFC0CA33), // lima
    Color(0xFF00ACC1), // ciano
    Color(0xFFF06292), // rosa-claro
    Color(0xFFF9A825), // amarelo
    Color(0xFF3949AB), // anil
    Color(0xFF212121), // preto
  ];

  int _playerCount = 2;
  int _startingLife = 40;
  List<int> _lives = List.filled(maxPlayers, 40);
  List<int> _poison = List.filled(maxPlayers, 0);
  List<int> _energy = List.filled(maxPlayers, 0);
  List<int> _experience = List.filled(maxPlayers, 0);
  List<int> _tax = List.filled(maxPlayers, 0);
  List<int> _treasure = List.filled(maxPlayers, 0);
  List<int> _storm = List.filled(maxPlayers, 0);
  List<int> _radiation = List.filled(maxPlayers, 0);
  // Dia e noite (cartas de Innistrad): 0 = fora do jogo, 1 = dia, 2 = noite.
  int _dayNight = 0;
  List<int> _blessing = List.filled(maxPlayers, 0); // cidade abençoada: 0 ou 1
  List<int> _colors = List.generate(maxPlayers, (i) => i);
  // Segunda cor (degradê, como deck de duas cores); -1 = só uma cor.
  List<int> _colors2 = List.filled(maxPlayers, -1);
  List<List<int>> _commanderDamage = List.generate(maxPlayers, (_) => List.filled(maxPlayers, 0));
  // Dano do segundo comandante (parceiro) de cada adversário, contado à parte,
  // e quem joga com dois comandantes (0 ou 1).
  List<List<int>> _partnerDamage = List.generate(maxPlayers, (_) => List.filled(maxPlayers, 0));
  List<int> _partners = List.filled(maxPlayers, 0);
  List<String> _playerNames = List.generate(maxPlayers, (i) => "Jogador ${i + 1}");
  // O deck de cada jogador nesta partida (nome; vazio = não disse), para as estatísticas.
  List<String> _decks = List.filled(maxPlayers, '');

  // Quem é o monarca e quem tem a iniciativa (-1 = ninguém).
  int _monarch = -1;
  int _initiative = -1;

  // Turnos: de quem é a vez (-1 = sem contar turnos), quem começou, a rodada,
  // quando a vez atual começou (ms desde 1970) e o tempo que cada um já usou.
  int _turnPlayer = -1;
  int _turnFirst = 0;
  int _turnRound = 1;
  int _turnStartedAt = 0;
  List<int> _turnTotals = List.filled(maxPlayers, 0);
  // Quantas vezes o dado planar já rolou nesta vez (a próxima custa isso em mana).
  int planarRollsThisTurn = 0;

  // Planechase e Archenemy: o plano e o esquema virados agora (nome e imagem).
  Map<String, dynamic>? _plane;
  Map<String, dynamic>? _scheme;

  // Histórico da partida (só neste aparelho), do mais antigo ao mais novo.
  final List<GameEvent> _history = [];

  /// Muda a cada partida nova neste aparelho (para saber se o "desfazer"
  /// ainda é da partida que terminou).
  int gameId = 0;

  int get playerCount => _playerCount;
  int get startingLife => _startingLife;
  List<int> get lives => _lives;
  List<int> get poison => _poison;
  List<List<int>> get commanderDamage => _commanderDamage;

  /// O comandante [attacker]: 0..maxPlayers-1 é o comandante de cada jogador;
  /// somando [maxPlayers], o segundo comandante (parceiro) dele.
  int cmdDamage(int victim, int attacker) =>
      attacker >= maxPlayers ? _partnerDamage[victim][attacker - maxPlayers] : _commanderDamage[victim][attacker];
  bool hasPartner(int player) => _partners[player] == 1;
  String commanderName(int attacker) =>
      attacker >= maxPlayers ? '${_playerNames[attacker - maxPlayers]} (2º)' : _playerNames[attacker];

  /// O maior dano recebido de um mesmo comandante (é ele que chega a 21).
  int maxCmdDamage(int victim) {
    var top = 0;
    for (int a = 0; a < _playerCount; a++) {
      if (a == victim) continue;
      top = max(top, max(_commanderDamage[victim][a], _partnerDamage[victim][a]));
    }
    return top;
  }

  void setPartner(int player, bool on) {
    _partners[player] = on ? 1 : 0;
    _saveAndNotify();
  }
  List<String> get playerNames => _playerNames;
  List<GameEvent> get history => List.unmodifiable(_history);
  bool get canUndo => _history.isNotEmpty;
  int get monarch => _monarch;
  int get dayNight => _dayNight;

  /// Dia → noite → dia... (a primeira vez começa de dia).
  void toggleDayNight() {
    _dayNight = _dayNight == 1 ? 2 : 1;
    _saveAndNotify();
  }

  void clearDayNight() {
    _dayNight = 0;
    _saveAndNotify();
  }
  int get initiative => _initiative;
  int get turnPlayer => _turnPlayer;
  int get turnRound => _turnRound;
  bool get countingTurns => _turnPlayer >= 0;
  Map<String, dynamic>? get plane => _plane;
  Map<String, dynamic>? get scheme => _scheme;

  /// Quanto tempo a vez atual já durou.
  Duration get turnElapsed => _turnPlayer < 0 ? Duration.zero : Duration(milliseconds: max(0, DateTime.now().millisecondsSinceEpoch - _turnStartedAt));

  /// Tempo total que o jogador usou nas vezes dele (contando a atual).
  Duration turnTotal(int player) => Duration(milliseconds: _turnTotals[player]) + (player == _turnPlayer ? turnElapsed : Duration.zero);

  /// O nome padrão antigo ("Player 2") vira "Jogador 2".
  static String _ptName(String name) {
    final m = RegExp(r'^Player (\d)$').firstMatch(name);
    return m == null ? name : 'Jogador ${m.group(1)}';
  }

  String deckOf(int player) => _decks[player];

  void setDeck(int player, String deck) {
    _decks[player] = deck.trim();
    _saveAndNotify();
  }

  Color colorOf(int player) => palette[_colors[player] % palette.length];
  int colorIndexOf(int player) => _colors[player];

  /// A segunda cor do degradê, ou null se o jogador usa uma cor só.
  Color? secondColorOf(int player) => _colors2[player] < 0 ? null : palette[_colors2[player] % palette.length];
  int secondColorIndexOf(int player) => _colors2[player];

  int counter(Counter kind, int player) => switch (kind) {
        Counter.poison => _poison[player],
        Counter.energy => _energy[player],
        Counter.experience => _experience[player],
        Counter.tax => _tax[player],
        Counter.treasure => _treasure[player],
        Counter.storm => _storm[player],
        Counter.radiation => _radiation[player],
        Counter.blessing => _blessing[player],
      };

  List<int> _counterList(Counter kind) => switch (kind) {
        Counter.poison => _poison,
        Counter.energy => _energy,
        Counter.experience => _experience,
        Counter.tax => _tax,
        Counter.treasure => _treasure,
        Counter.storm => _storm,
        Counter.radiation => _radiation,
        Counter.blessing => _blessing,
      };

  /// Como a vida do jogador mudou nesta partida, do começo até agora (dano,
  /// cura e dano de comandante), com a vida depois de cada mudança. Toques
  /// seguidos já vêm juntos (ex.: −7). A vida antes da primeira mudança é
  /// calculada de trás para frente a partir da vida atual.
  ({int start, List<({DateTime at, int delta, int life, String kind, int? attacker})> changes}) lifeTimeline(int player) {
    final events = [for (final e in _history) if (e.player == player && (e.kind == 'life' || e.kind == 'cmd')) e];
    int lifeDelta(GameEvent e) => e.kind == 'cmd' ? -e.delta : e.delta;
    var life = _lives[player] - events.fold<int>(0, (sum, e) => sum + lifeDelta(e));
    final start = life;
    final changes = <({DateTime at, int delta, int life, String kind, int? attacker})>[];
    for (final e in events) {
      life += lifeDelta(e);
      changes.add((at: e.at, delta: lifeDelta(e), life: life, kind: e.kind, attacker: e.attacker));
    }
    return (start: start, changes: changes);
  }

  /// Morto: vida 0, 10 de veneno ou 21 de dano de um mesmo comandante.
  bool isDead(int player) {
    if (_lives[player] <= 0 || _poison[player] >= 10) return true;
    for (int a = 0; a < _playerCount; a++) {
      if (a != player && (_commanderDamage[player][a] >= 21 || _partnerDamage[player][a] >= 21)) return true;
    }
    return false;
  }

  /// O único vivo, se a partida acabou (senão, null).
  int? get winner {
    if (_playerCount < 2) return null;
    final alive = [for (int i = 0; i < _playerCount; i++) if (!isDead(i)) i];
    return alive.length == 1 ? alive.first : null;
  }

  /// Chamado a cada mudança feita aqui (não nas que vêm da conta), com a
  /// mudança e se o jogador acabou de morrer: o contador usa para os sons.
  void Function(GameEvent change, bool died)? onChange;

  void _changed(GameEvent change, bool wasDead) => onChange?.call(change, !wasDead && isDead(change.player));

  /// Termina quando a partida salva no aparelho foi carregada.
  late final Future<void> ready;

  GameProvider() {
    ready = _loadGame();
    UserData.instance.register(SyncedSection(key: 'game', read: toSync, apply: applySync));
  }

  Map<String, dynamic> toSync() => {
        'playerCount': _playerCount,
        'startingLife': _startingLife,
        'lives': _lives,
        'poison': _poison,
        'energy': _energy,
        'experience': _experience,
        'tax': _tax,
        'treasure': _treasure,
        'storm': _storm,
        'radiation': _radiation,
        'dayNight': _dayNight,
        'blessing': _blessing,
        'monarch': _monarch,
        'initiative': _initiative,
        'turnPlayer': _turnPlayer,
        'turnFirst': _turnFirst,
        'turnRound': _turnRound,
        'turnStartedAt': _turnStartedAt,
        'turnTotals': _turnTotals,
        'plane': _plane,
        'scheme': _scheme,
        'colors': _colors,
        'colors2': _colors2,
        // O Firestore não aceita lista dentro de lista: cada linha do dano de
        // comandante vai como texto ("0,5,0,0,0,0").
        'cmdRows': [for (final row in _commanderDamage) row.join(',')],
        'cmdRows2': [for (final row in _partnerDamage) row.join(',')],
        'partners': _partners,
        'playerNames': _playerNames,
        'playerDecks': _decks,
      };

  static List<int> _ints(dynamic v, int fill) {
    final list = [for (final x in (v as List? ?? const [])) (x as num).toInt()];
    while (list.length < maxPlayers) {
      list.add(fill);
    }
    return list;
  }

  /// Aplica a partida que veio de fora (da conta ou da mesa online). Na mesa
  /// online ([keepHistory]) o histórico daqui fica, para o desfazer e o gráfico.
  Future<void> applySync(Map<String, dynamic>? v, {bool keepHistory = false}) async {
    _playerCount = (v?['playerCount'] as num?)?.toInt() ?? 2;
    _startingLife = (v?['startingLife'] as num?)?.toInt() ?? 40;
    _lives = _ints(v?['lives'], _startingLife);
    _poison = _ints(v?['poison'], 0);
    _energy = _ints(v?['energy'], 0);
    _experience = _ints(v?['experience'], 0);
    _tax = _ints(v?['tax'], 0);
    _readExtras(v);
    final colors = v?['colors'];
    _colors = colors is List ? _ints(colors, 0) : List.generate(maxPlayers, (i) => i);
    _colors2 = _ints(v?['colors2'], -1);
    final rows = v?['cmdRows'] as List?;
    final cmd = rows != null
        ? [for (final r in rows) '$r'.split(',').where((x) => x.isNotEmpty).map((x) => int.tryParse(x) ?? 0).toList()]
        : (v?['commanderDamage'] as List?) ?? const []; // formato antigo
    _commanderDamage = List.generate(maxPlayers, (i) => _ints(i < cmd.length ? cmd[i] : null, 0));
    final rows2 = [for (final r in (v?['cmdRows2'] as List? ?? const [])) '$r'.split(',').where((x) => x.isNotEmpty).map((x) => int.tryParse(x) ?? 0).toList()];
    _partnerDamage = List.generate(maxPlayers, (i) => _ints(i < rows2.length ? rows2[i] : null, 0));
    _partners = _ints(v?['partners'], 0);
    final decks = [for (final d in (v?['playerDecks'] as List? ?? const [])) d.toString()];
    _decks = List.generate(maxPlayers, (i) => i < decks.length ? decks[i] : '');
    final names = [for (final n in (v?['playerNames'] as List? ?? const [])) _ptName(n.toString())];
    _playerNames = List.generate(maxPlayers, (i) => i < names.length ? names[i] : "Jogador ${i + 1}");
    if (!keepHistory) _history.clear();
    await _save();
    notifyListeners();
  }

  /// Os campos novos (contadores extras, monarca, turnos, plano), da conta ou do aparelho.
  void _readExtras(Map<String, dynamic>? v) {
    _treasure = _ints(v?['treasure'], 0);
    _storm = _ints(v?['storm'], 0);
    _radiation = _ints(v?['radiation'], 0);
    _dayNight = (v?['dayNight'] as num?)?.toInt() ?? 0;
    _blessing = _ints(v?['blessing'], 0);
    _monarch = (v?['monarch'] as num?)?.toInt() ?? -1;
    _initiative = (v?['initiative'] as num?)?.toInt() ?? -1;
    final turn = (v?['turnPlayer'] as num?)?.toInt() ?? -1;
    if (turn != _turnPlayer) planarRollsThisTurn = 0;
    _turnPlayer = turn;
    _turnFirst = (v?['turnFirst'] as num?)?.toInt() ?? 0;
    _turnRound = (v?['turnRound'] as num?)?.toInt() ?? 1;
    _turnStartedAt = (v?['turnStartedAt'] as num?)?.toInt() ?? 0;
    _turnTotals = _ints(v?['turnTotals'], 0);
    _plane = v?['plane'] is Map ? Map<String, dynamic>.from(v!['plane'] as Map) : null;
    _scheme = v?['scheme'] is Map ? Map<String, dynamic>.from(v!['scheme'] as Map) : null;
  }

  // ------------------------------------------------------------- mudanças

  void updateLife(int index, int delta) {
    if (delta == 0) return;
    final wasDead = isDead(index);
    _lives[index] += delta;
    _record(GameEvent(index, 'life', delta));
    _changed(GameEvent(index, 'life', delta), wasDead);
  }

  void updateCounter(Counter kind, int index, int delta) {
    final list = _counterList(kind);
    final top = switch (kind) { Counter.poison => 10, Counter.blessing => 1, _ => 99 };
    final wasDead = isDead(index);
    final before = list[index];
    list[index] = (before + delta).clamp(0, top);
    final applied = list[index] - before;
    if (applied != 0) {
      _record(GameEvent(index, kind.name, applied));
      _changed(GameEvent(index, kind.name, applied), wasDead);
    }
  }

  void updateCommanderDamage(int victim, int attacker, int delta) {
    final wasDead = isDead(victim);
    final before = cmdDamage(victim, attacker);
    final after = (before + delta).clamp(0, 21);
    final applied = after - before;
    if (applied == 0) return;
    _cmdAdd(victim, attacker, applied);
    // O dano de comandante também tira vida.
    _lives[victim] -= applied;
    _record(GameEvent(victim, 'cmd', applied, attacker: attacker));
    _changed(GameEvent(victim, 'cmd', applied, attacker: attacker), wasDead);
  }

  void _cmdAdd(int victim, int attacker, int delta) {
    if (attacker >= maxPlayers) {
      _partnerDamage[victim][attacker - maxPlayers] += delta;
    } else {
      _commanderDamage[victim][attacker] += delta;
    }
  }

  /// Desfaz a última mudança da partida.
  void undo() {
    if (_history.isEmpty) return;
    final e = _history.removeLast();
    switch (e.kind) {
      case 'life':
        _lives[e.player] -= e.delta;
      case 'cmd':
        _cmdAdd(e.player, e.attacker!, -e.delta);
        _lives[e.player] += e.delta;
      default:
        final list = _counterList(Counter.values.byName(e.kind));
        list[e.player] -= e.delta;
    }
    _saveAndNotify();
  }

  /// Passa a coroa de monarca (tocar em quem já é monarca tira a coroa).
  void setMonarch(int player) {
    _monarch = _monarch == player ? -1 : player;
    _saveAndNotify();
  }

  /// Dá a iniciativa (tocar em quem já tem tira).
  void setInitiative(int player) {
    _initiative = _initiative == player ? -1 : player;
    _saveAndNotify();
  }

  // ---------------------------------------------------------------- turnos

  /// Começa a contar os turnos, com [first] jogando primeiro.
  void startTurns(int first) {
    _turnFirst = first;
    _turnPlayer = first;
    _turnRound = 1;
    _turnTotals = List.filled(maxPlayers, 0);
    _turnStartedAt = DateTime.now().millisecondsSinceEpoch;
    planarRollsThisTurn = 0;
    _saveAndNotify();
  }

  /// O próximo vivo no sentido horário da mesa (a ordem dos quadros).
  int _nextAlive(int from) {
    for (int k = 1; k <= _playerCount; k++) {
      final i = (from + k) % _playerCount;
      if (!isDead(i)) return i;
    }
    return from;
  }

  /// Passa a vez: soma o tempo de quem jogou e a rodada avança quando volta
  /// para quem começou (ou passa por ele, se ele já morreu).
  void nextTurn() {
    if (_turnPlayer < 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _turnTotals[_turnPlayer] += max(0, now - _turnStartedAt);
    final from = _turnPlayer;
    final next = _nextAlive(from);
    // Andando de [from] até [next], passamos por quem começou?
    for (int k = 1; k <= _playerCount; k++) {
      final i = (from + k) % _playerCount;
      if (i == _turnFirst) {
        _turnRound++;
        break;
      }
      if (i == next) break;
    }
    _turnPlayer = next;
    _turnStartedAt = now;
    planarRollsThisTurn = 0;
    _saveAndNotify();
  }

  void stopTurns() {
    _turnPlayer = -1;
    _saveAndNotify();
  }

  // ------------------------------------------------- Planechase e Archenemy

  /// O plano em jogo (null tira). Vem da Scryfall: nome, imagem e texto.
  void setPlane(Map<String, dynamic>? plane) {
    _plane = plane;
    _saveAndNotify();
  }

  void setScheme(Map<String, dynamic>? scheme) {
    _scheme = scheme;
    _saveAndNotify();
  }

  /// Rolou o dado planar nesta vez (a próxima rolagem custa mais 1 de mana).
  void countPlanarRoll() {
    planarRollsThisTurn++;
    notifyListeners();
  }

  void _record(GameEvent e) {
    // Toques seguidos no mesmo jogador viram uma mudança só (ex.: −7).
    final last = _history.isEmpty ? null : _history.last;
    if (last != null &&
        last.player == e.player &&
        last.kind == e.kind &&
        last.attacker == e.attacker &&
        e.at.difference(last.at) < const Duration(seconds: 3) &&
        (last.delta > 0) == (e.delta > 0)) {
      _history[_history.length - 1] = GameEvent(e.player, e.kind, last.delta + e.delta, attacker: e.attacker);
    } else {
      _history.add(e);
      if (_history.length > 200) _history.removeAt(0);
    }
    _saveAndNotify();
  }

  void setPlayerCount(int count) {
    _playerCount = count.clamp(2, maxPlayers);
    _saveAndNotify();
  }

  void updatePlayerName(int index, String name) {
    _playerNames[index] = name;
    _saveAndNotify();
  }

  /// A segunda cor do degradê (-1 tira o degradê).
  void setSecondColor(int index, int paletteIndex) {
    _colors2[index] = paletteIndex;
    _saveAndNotify();
  }

  void setPlayerColor(int index, int paletteIndex) {
    _colors[index] = paletteIndex;
    _saveAndNotify();
  }

  /// Muda a vida inicial (20, 30, 40...) e começa uma partida nova.
  void setStartingLife(int life) {
    _startingLife = life;
    resetGame();
  }

  /// Sorteia os lugares: cada jogador (nome, cores, deck e parceiro) vai
  /// para um lugar da mesa ao acaso, e começa uma partida nova.
  void shuffleSeats([Random? rng]) {
    final order = List.generate(_playerCount, (i) => i)..shuffle(rng ?? Random());
    List<T> move<T>(List<T> list) => [for (int i = 0; i < maxPlayers; i++) i < _playerCount ? list[order[i]] : list[i]];
    _playerNames = move(_playerNames);
    _colors = move(_colors);
    _colors2 = move(_colors2);
    _decks = move(_decks);
    _partners = move(_partners);
    resetGame();
  }

  void resetGame() {
    gameId++;
    _lives = List.filled(maxPlayers, _startingLife);
    _poison = List.filled(maxPlayers, 0);
    _energy = List.filled(maxPlayers, 0);
    _experience = List.filled(maxPlayers, 0);
    _tax = List.filled(maxPlayers, 0);
    _treasure = List.filled(maxPlayers, 0);
    _storm = List.filled(maxPlayers, 0);
    _radiation = List.filled(maxPlayers, 0);
    _dayNight = 0;
    _blessing = List.filled(maxPlayers, 0);
    _monarch = -1;
    _initiative = -1;
    _turnPlayer = -1;
    _turnRound = 1;
    _turnTotals = List.filled(maxPlayers, 0);
    planarRollsThisTurn = 0;
    _plane = null;
    _scheme = null;
    _commanderDamage = List.generate(maxPlayers, (_) => List.filled(maxPlayers, 0));
    _partnerDamage = List.generate(maxPlayers, (_) => List.filled(maxPlayers, 0));
    _history.clear();
    _saveAndNotify();
  }

  // -------------------------------------------------------------- salvar

  static const _extraKeys = [
    'treasure', 'storm', 'blessing', 'radiation', 'dayNight', 'monarch', 'initiative', 'turnPlayer', 'turnFirst', //
    'turnRound', 'turnStartedAt', 'turnTotals', 'plane', 'scheme',
  ];

  /// Chamado a cada mudança feita aqui (a mesa online manda para os outros).
  void Function()? onLocalChange;

  // Segurando o + ou o −, a vida muda várias vezes por segundo: grava no
  // aparelho e avisa a conta uma vez só, logo depois que para.
  Timer? _saveTimer;

  Future<void> _saveAndNotify() async {
    notifyListeners();
    onLocalChange?.call();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), () {
      _save();
      UserData.instance.changed('game');
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('playerCount', _playerCount);
    prefs.setInt('startingLife', _startingLife);
    prefs.setString('lives', jsonEncode(_lives));
    prefs.setString('poison', jsonEncode(_poison));
    prefs.setString('energy', jsonEncode(_energy));
    prefs.setString('experience', jsonEncode(_experience));
    prefs.setString('tax', jsonEncode(_tax));
    final sync = toSync();
    prefs.setString('gameExtras', jsonEncode({for (final k in _extraKeys) k: sync[k]}));
    prefs.setString('playerColors', jsonEncode(_colors));
    prefs.setString('playerColors2', jsonEncode(_colors2));
    prefs.setString('commanderDamage', jsonEncode(_commanderDamage));
    prefs.setString('partnerDamage', jsonEncode(_partnerDamage));
    prefs.setString('partners', jsonEncode(_partners));
    prefs.setString('playerDecks', jsonEncode(_decks));
    await prefs.setString('playerNames', jsonEncode(_playerNames));
  }

  Future<void> _loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    _playerCount = prefs.getInt('playerCount') ?? 2;
    _startingLife = prefs.getInt('startingLife') ?? 40;

    List<int>? ints(String key, int fill) {
      final raw = prefs.getString(key);
      return raw == null ? null : _ints(jsonDecode(raw), fill);
    }

    _lives = ints('lives', _startingLife) ?? _lives;
    _poison = ints('poison', 0) ?? _poison;
    _energy = ints('energy', 0) ?? _energy;
    _experience = ints('experience', 0) ?? _experience;
    _tax = ints('tax', 0) ?? _tax;
    final extras = prefs.getString('gameExtras');
    if (extras != null) _readExtras(jsonDecode(extras) as Map<String, dynamic>);
    _colors = ints('playerColors', 0) ?? _colors;
    _colors2 = ints('playerColors2', -1) ?? _colors2;

    final c = prefs.getString('commanderDamage');
    if (c != null) {
      final rows = jsonDecode(c) as List;
      _commanderDamage = List.generate(maxPlayers, (i) => _ints(i < rows.length ? rows[i] : null, 0));
    }
    final c2 = prefs.getString('partnerDamage');
    if (c2 != null) {
      final rows = jsonDecode(c2) as List;
      _partnerDamage = List.generate(maxPlayers, (i) => _ints(i < rows.length ? rows[i] : null, 0));
    }
    _partners = ints('partners', 0) ?? _partners;

    final d = prefs.getString('playerDecks');
    if (d != null) {
      final decks = List<String>.from(jsonDecode(d));
      _decks = List.generate(maxPlayers, (i) => i < decks.length ? decks[i] : '');
    }

    final n = prefs.getString('playerNames');
    if (n != null) {
      final names = [for (final x in jsonDecode(n) as List) _ptName(x.toString())];
      _playerNames = List.generate(maxPlayers, (i) => i < names.length ? names[i] : "Jogador ${i + 1}");
    }

    notifyListeners();
  }
}
