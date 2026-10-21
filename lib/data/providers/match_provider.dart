import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../account/user_data.dart';
import 'game_provider.dart';

/// Uma partida terminada: quem jogou (nome, cor e deck), quem ganhou, quanto
/// durou, as rodadas e como a vida de cada um mudou. O mesmo formato do site
/// (web-site/src/lib/matches.js), em users/{uid}.data.matches.list.
class MatchRecord {
  final String id;
  final int at; // quando terminou (ms desde 1970)
  final int durationMs;
  final int startingLife;
  final int rounds; // 0 = não contou turnos
  final int winner; // índice em players (-1 = empate)
  final List<Map<String, dynamic>> players; // {name, color, color2, deck, life}
  final List<List<int>> timelines; // vida de cada jogador ao longo da partida

  MatchRecord({
    required this.id,
    required this.at,
    required this.durationMs,
    required this.startingLife,
    required this.rounds,
    required this.winner,
    required this.players,
    required this.timelines,
  });

  String get winnerName => winner < 0 || winner >= players.length ? '' : '${players[winner]['name']}';
  String deckOf(int i) => '${players[i]['deck'] ?? ''}'.trim();

  Map<String, dynamic> toMap() => {
        'id': id,
        'at': at,
        'durationMs': durationMs,
        'startingLife': startingLife,
        'rounds': rounds,
        'winner': winner,
        'players': players,
        // O Firestore não guarda lista dentro de lista: cada linha vira texto.
        'timelines': [for (final t in timelines) t.join(',')],
      };

  factory MatchRecord.fromMap(Map<String, dynamic> m) => MatchRecord(
        id: '${m['id']}',
        at: (m['at'] as num?)?.toInt() ?? 0,
        durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
        startingLife: (m['startingLife'] as num?)?.toInt() ?? 40,
        rounds: (m['rounds'] as num?)?.toInt() ?? 0,
        winner: (m['winner'] as num?)?.toInt() ?? -1,
        players: [for (final p in (m['players'] as List? ?? const [])) Map<String, dynamic>.from(p as Map)],
        timelines: [
          for (final t in (m['timelines'] as List? ?? const []))
            [for (final v in '$t'.split(',')) if (v.isNotEmpty) int.tryParse(v) ?? 0],
        ],
      );

  /// A partida que acabou de terminar, a partir do contador.
  factory MatchRecord.fromGame(GameProvider game, {DateTime? now}) {
    final end = now ?? DateTime.now();
    final n = game.playerCount;
    final events = game.history;
    final start = events.isEmpty ? end : events.first.at;
    return MatchRecord(
      id: '${end.millisecondsSinceEpoch}',
      at: end.millisecondsSinceEpoch,
      durationMs: end.difference(start).inMilliseconds,
      startingLife: game.startingLife,
      rounds: game.countingTurns ? game.turnRound : 0,
      winner: game.winner ?? -1,
      players: [
        for (int i = 0; i < n; i++)
          {
            'name': game.playerNames[i],
            'color': game.colorIndexOf(i),
            'color2': game.secondColorIndexOf(i),
            'deck': game.deckOf(i),
            'life': game.lives[i],
          },
      ],
      timelines: [
        for (int i = 0; i < n; i++)
          () {
            final t = game.lifeTimeline(i);
            final points = [t.start, for (final c in t.changes) c.life];
            // Partidas longas: no máximo 60 pontos por jogador (pula do meio).
            if (points.length <= 60) return points;
            final step = points.length / 59;
            return [for (int k = 0; k < 59; k++) points[(k * step).floor()], points.last];
          }(),
      ],
    );
  }
}

/// Vitórias e partidas de um jogador ou de um deck.
class MatchStat {
  final String name;
  int played = 0;
  int wins = 0;
  MatchStat(this.name);
  double get rate => played == 0 ? 0 : wins / played;
}

/// O histórico de partidas (vai para a conta, como o resto).
class MatchProvider with ChangeNotifier {
  static const maxMatches = 150;

  List<MatchRecord> _matches = []; // mais nova primeiro
  List<MatchRecord> get matches => List.unmodifiable(_matches);

  late final Future<void> ready;

  MatchProvider() {
    ready = _load();
    UserData.instance.register(SyncedSection(key: 'matches', read: toSync, apply: applySync));
  }

  Map<String, dynamic> toSync() => {'list': [for (final m in _matches) m.toMap()]};

  Future<void> applySync(Map<String, dynamic>? v) async {
    _matches = [for (final m in (v?['list'] as List? ?? const [])) MatchRecord.fromMap(Map<String, dynamic>.from(m as Map))];
    await _save();
    notifyListeners();
  }

  void add(MatchRecord match) {
    _matches.insert(0, match);
    if (_matches.length > maxMatches) _matches = _matches.sublist(0, maxMatches);
    _changed();
  }

  void remove(String id) {
    _matches.removeWhere((m) => m.id == id);
    _changed();
  }

  void clear() {
    _matches = [];
    _changed();
  }

  /// Por jogador (pelo nome, sem diferença de maiúscula) ou por deck.
  static List<MatchStat> stats(Iterable<MatchRecord> matches, {bool byDeck = false}) {
    final table = <String, MatchStat>{};
    for (final m in matches) {
      for (int i = 0; i < m.players.length; i++) {
        final name = byDeck ? m.deckOf(i) : '${m.players[i]['name']}'.trim();
        if (name.isEmpty) continue;
        final s = table.putIfAbsent(name.toLowerCase(), () => MatchStat(name));
        s.played++;
        if (m.winner == i) s.wins++;
      }
    }
    return table.values.toList()
      ..sort((a, b) {
        final byWins = b.wins.compareTo(a.wins);
        return byWins != 0 ? byWins : b.rate.compareTo(a.rate);
      });
  }

  /// Duração média das partidas (as que duraram mais de um minuto).
  static Duration averageDuration(Iterable<MatchRecord> matches) {
    final real = [for (final m in matches) if (m.durationMs > 60000) m.durationMs];
    if (real.isEmpty) return Duration.zero;
    return Duration(milliseconds: real.reduce((a, b) => a + b) ~/ real.length);
  }

  static int longest(Iterable<MatchRecord> matches) => matches.fold(0, (a, m) => max(a, m.rounds));

  Future<void> _changed() async {
    notifyListeners();
    await _save();
    UserData.instance.changed('matches');
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('matches_v2', jsonEncode(toSync()));
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('matches_v2');
    if (raw == null) return;
    final list = (jsonDecode(raw) as Map<String, dynamic>)['list'] as List? ?? const [];
    _matches = [for (final m in list) MatchRecord.fromMap(Map<String, dynamic>.from(m as Map))];
    notifyListeners();
  }
}
