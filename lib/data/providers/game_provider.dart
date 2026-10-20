import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../account/user_data.dart';

class GameProvider with ChangeNotifier {
  int _playerCount = 2;
  int _startingLife = 40;
  List<int> _lives = List.filled(6, 40);
  List<int> _poison = List.filled(6, 0);
  List<List<int>> _commanderDamage = List.generate(6, (_) => List.filled(6, 0));
  List<String> _playerNames = ["Player 1", "Player 2", "Player 3", "Player 4", "Player 5", "Player 6"];

  int get playerCount => _playerCount;
  int get startingLife => _startingLife;
  List<int> get lives => _lives;
  List<int> get poison => _poison;
  List<List<int>> get commanderDamage => _commanderDamage;
  List<String> get playerNames => _playerNames;

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
        'commanderDamage': _commanderDamage,
        'playerNames': _playerNames,
      };

  static List<int> _ints(dynamic v, int fill) {
    final list = [for (final x in (v as List? ?? const [])) (x as num).toInt()];
    while (list.length < 6) {
      list.add(fill);
    }
    return list;
  }

  Future<void> applySync(Map<String, dynamic>? v) async {
    _playerCount = (v?['playerCount'] as num?)?.toInt() ?? 2;
    _startingLife = (v?['startingLife'] as num?)?.toInt() ?? 40;
    _lives = _ints(v?['lives'], _startingLife);
    _poison = _ints(v?['poison'], 0);
    final cmd = (v?['commanderDamage'] as List?) ?? const [];
    _commanderDamage = List.generate(6, (i) => _ints(i < cmd.length ? cmd[i] : null, 0));
    final names = [for (final n in (v?['playerNames'] as List? ?? const [])) n.toString()];
    _playerNames = List.generate(6, (i) => i < names.length ? names[i] : "Player ${i + 1}");
    await _save();
    notifyListeners();
  }

  void updateLife(int index, int delta) {
    _lives[index] += delta;
    _saveAndNotify();
  }

  void updatePoison(int index, int delta) {
    _poison[index] = (_poison[index] + delta).clamp(0, 10);
    _saveAndNotify();
  }

  void updateCommanderDamage(int victim, int attacker, int delta) {
    int currentDamage = _commanderDamage[victim][attacker];
    int newDamage = (currentDamage + delta).clamp(0, 21);
    
    // Calcula a diferença real para saber quanto de dano entrou ou saiu
    int actualDelta = newDamage - currentDamage; 
    
    _commanderDamage[victim][attacker] = newDamage;
    
    // O dano de comandante reduz a vida total automaticamente!
    // Como o 'actualDelta' é positivo quando ganha dano, nós subtraímos (-) da vida.
    _lives[victim] -= actualDelta; 
    
    _saveAndNotify();
  }

  void setPlayerCount(int count) {
    _playerCount = count;
    _saveAndNotify();
  }

  void updatePlayerName(int index, String name) {
    _playerNames[index] = name;
    _saveAndNotify();
  }

  void toggleCMDMode() {
    _startingLife = (_startingLife == 20) ? 40 : 20;
    resetGame();
  }

  void resetGame() {
    _lives = List.filled(6, _startingLife);
    _poison = List.filled(6, 0);
    _commanderDamage = List.generate(6, (_) => List.filled(6, 0));
    _saveAndNotify();
  }

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
    prefs.setString('commanderDamage', jsonEncode(_commanderDamage));
    await prefs.setString('playerNames', jsonEncode(_playerNames));
  }

  Future<void> _loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    _playerCount = prefs.getInt('playerCount') ?? 2;
    _startingLife = prefs.getInt('startingLife') ?? 40;
    
    final l = prefs.getString('lives');
    if (l != null) _lives = List<int>.from(jsonDecode(l));

    final p = prefs.getString('poison');
    if (p != null) _poison = List<int>.from(jsonDecode(p));

    final c = prefs.getString('commanderDamage');
    if (c != null) {
      _commanderDamage = (jsonDecode(c) as List).map((i) => List<int>.from(i)).toList();
    }
    
    final n = prefs.getString('playerNames');
    if (n != null) {
      _playerNames = List<String>.from(jsonDecode(n));
    }
    
    notifyListeners();
  }
}