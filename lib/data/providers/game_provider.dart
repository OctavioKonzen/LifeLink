import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../account/user_data.dart';

/// Os contadores extras de cada jogador (além de vida e dano de comandante).
enum Counter { poison, energy, experience, tax }

/// Uma mudança na partida, para o histórico e o "desfazer".
class GameEvent {
  final int player;
  final String kind; // 'life', 'poison', 'energy', 'experience', 'tax' ou 'cmd'
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
  ];

  int _playerCount = 2;
  int _startingLife = 40;
  List<int> _lives = List.filled(maxPlayers, 40);
  List<int> _poison = List.filled(maxPlayers, 0);
  List<int> _energy = List.filled(maxPlayers, 0);
  List<int> _experience = List.filled(maxPlayers, 0);
  List<int> _tax = List.filled(maxPlayers, 0);
  List<int> _colors = List.generate(maxPlayers, (i) => i);
  List<List<int>> _commanderDamage = List.generate(maxPlayers, (_) => List.filled(maxPlayers, 0));
  List<String> _playerNames = List.generate(maxPlayers, (i) => "Player ${i + 1}");

  // Histórico da partida (só neste aparelho), do mais antigo ao mais novo.
  final List<GameEvent> _history = [];

  int get playerCount => _playerCount;
  int get startingLife => _startingLife;
  List<int> get lives => _lives;
  List<int> get poison => _poison;
  List<List<int>> get commanderDamage => _commanderDamage;
  List<String> get playerNames => _playerNames;
  List<GameEvent> get history => List.unmodifiable(_history);
  bool get canUndo => _history.isNotEmpty;

  Color colorOf(int player) => palette[_colors[player] % palette.length];
  int colorIndexOf(int player) => _colors[player];

  int counter(Counter kind, int player) => switch (kind) {
        Counter.poison => _poison[player],
        Counter.energy => _energy[player],
        Counter.experience => _experience[player],
        Counter.tax => _tax[player],
      };

  List<int> _counterList(Counter kind) => switch (kind) {
        Counter.poison => _poison,
        Counter.energy => _energy,
        Counter.experience => _experience,
        Counter.tax => _tax,
      };

  /// Morto: vida 0, 10 de veneno ou 21 de dano de um mesmo comandante.
  bool isDead(int player) {
    if (_lives[player] <= 0 || _poison[player] >= 10) return true;
    for (int a = 0; a < _playerCount; a++) {
      if (a != player && _commanderDamage[player][a] >= 21) return true;
    }
    return false;
  }

  /// O único vivo, se a partida acabou (senão, null).
  int? get winner {
    if (_playerCount < 2) return null;
    final alive = [for (int i = 0; i < _playerCount; i++) if (!isDead(i)) i];
    return alive.length == 1 ? alive.first : null;
  }

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
        'colors': _colors,
        'commanderDamage': _commanderDamage,
        'playerNames': _playerNames,
      };

  static List<int> _ints(dynamic v, int fill) {
    final list = [for (final x in (v as List? ?? const [])) (x as num).toInt()];
    while (list.length < maxPlayers) {
      list.add(fill);
    }
    return list;
  }

  Future<void> applySync(Map<String, dynamic>? v) async {
    _playerCount = (v?['playerCount'] as num?)?.toInt() ?? 2;
    _startingLife = (v?['startingLife'] as num?)?.toInt() ?? 40;
    _lives = _ints(v?['lives'], _startingLife);
    _poison = _ints(v?['poison'], 0);
    _energy = _ints(v?['energy'], 0);
    _experience = _ints(v?['experience'], 0);
    _tax = _ints(v?['tax'], 0);
    final colors = v?['colors'];
    _colors = colors is List ? _ints(colors, 0) : List.generate(maxPlayers, (i) => i);
    final cmd = (v?['commanderDamage'] as List?) ?? const [];
    _commanderDamage = List.generate(maxPlayers, (i) => _ints(i < cmd.length ? cmd[i] : null, 0));
    final names = [for (final n in (v?['playerNames'] as List? ?? const [])) n.toString()];
    _playerNames = List.generate(maxPlayers, (i) => i < names.length ? names[i] : "Player ${i + 1}");
    _history.clear();
    await _save();
    notifyListeners();
  }

  // ------------------------------------------------------------- mudanças

  void updateLife(int index, int delta) {
    if (delta == 0) return;
    _lives[index] += delta;
    _record(GameEvent(index, 'life', delta));
  }

  void updatePoison(int index, int delta) => updateCounter(Counter.poison, index, delta);

  void updateCounter(Counter kind, int index, int delta) {
    final list = _counterList(kind);
    final max = kind == Counter.poison ? 10 : 99;
    final before = list[index];
    list[index] = (before + delta).clamp(0, max);
    final applied = list[index] - before;
    if (applied != 0) _record(GameEvent(index, kind.name, applied));
  }

  void updateCommanderDamage(int victim, int attacker, int delta) {
    final before = _commanderDamage[victim][attacker];
    final after = (before + delta).clamp(0, 21);
    final applied = after - before;
    if (applied == 0) return;
    _commanderDamage[victim][attacker] = after;
    // O dano de comandante também tira vida.
    _lives[victim] -= applied;
    _record(GameEvent(victim, 'cmd', applied, attacker: attacker));
  }

  /// Desfaz a última mudança da partida.
  void undo() {
    if (_history.isEmpty) return;
    final e = _history.removeLast();
    switch (e.kind) {
      case 'life':
        _lives[e.player] -= e.delta;
      case 'cmd':
        _commanderDamage[e.player][e.attacker!] -= e.delta;
        _lives[e.player] += e.delta;
      default:
        final list = _counterList(Counter.values.byName(e.kind));
        list[e.player] -= e.delta;
    }
    _saveAndNotify();
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

  void setPlayerColor(int index, int paletteIndex) {
    _colors[index] = paletteIndex;
    _saveAndNotify();
  }

  /// Muda a vida inicial (20, 30, 40...) e começa uma partida nova.
  void setStartingLife(int life) {
    _startingLife = life;
    resetGame();
  }

  void toggleCMDMode() => setStartingLife(_startingLife == 20 ? 40 : 20);

  void resetGame() {
    _lives = List.filled(maxPlayers, _startingLife);
    _poison = List.filled(maxPlayers, 0);
    _energy = List.filled(maxPlayers, 0);
    _experience = List.filled(maxPlayers, 0);
    _tax = List.filled(maxPlayers, 0);
    _commanderDamage = List.generate(maxPlayers, (_) => List.filled(maxPlayers, 0));
    _history.clear();
    _saveAndNotify();
  }

  // -------------------------------------------------------------- salvar

  Future<void> _saveAndNotify() async {
    notifyListeners();
    await _save();
    UserData.instance.changed('game');
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
    prefs.setString('playerColors', jsonEncode(_colors));
    prefs.setString('commanderDamage', jsonEncode(_commanderDamage));
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
    _colors = ints('playerColors', 0) ?? _colors;

    final c = prefs.getString('commanderDamage');
    if (c != null) {
      final rows = jsonDecode(c) as List;
      _commanderDamage = List.generate(maxPlayers, (i) => _ints(i < rows.length ? rows[i] : null, 0));
    }

    final n = prefs.getString('playerNames');
    if (n != null) {
      final names = List<String>.from(jsonDecode(n));
      _playerNames = List.generate(maxPlayers, (i) => i < names.length ? names[i] : "Player ${i + 1}");
    }

    notifyListeners();
  }
}
