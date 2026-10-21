import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/game_provider.dart';
import '../../../data/providers/match_provider.dart';
import '../../../data/providers/theme_provider.dart';

/// Histórico de partidas (vai para a conta) e as estatísticas do grupo:
/// vitórias por jogador e por deck, duração média e a partida mais longa.
class MatchHistoryScreen extends StatelessWidget {
  const MatchHistoryScreen({super.key});

  static String duration(int ms) {
    final m = ms ~/ 60000;
    if (m < 1) return 'menos de 1 min';
    return m >= 60 ? '${m ~/ 60}h${(m % 60).toString().padLeft(2, '0')}' : '$m min';
  }

  static String date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  static Color colorOf(Map<String, dynamic> player) => GameProvider.palette[((player['color'] as num?)?.toInt() ?? 0) % GameProvider.palette.length];

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final matches = context.watch<MatchProvider>();
    final bg = theme.backgroundColor;
    final light = bg.computeLuminance() > 0.5;
    final text = light ? Colors.black87 : Colors.white;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: Text('Partidas', style: TextStyle(color: text, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: text),
          bottom: TabBar(
            labelColor: text,
            unselectedLabelColor: text.withValues(alpha: 0.5),
            indicatorColor: Colors.amber,
            tabs: const [Tab(text: 'Histórico'), Tab(text: 'Estatísticas')],
          ),
          actions: [
            if (matches.matches.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                tooltip: 'Apagar o histórico',
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Apagar o histórico?'),
                      content: const Text('Todas as partidas e as estatísticas somem (também no site).'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar')),
                      ],
                    ),
                  );
                  if (ok == true) matches.clear();
                },
              ),
          ],
        ),
        body: matches.matches.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.history_toggle_off, size: 80, color: text.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    Text('Nenhuma partida ainda.\nQuando sobrar um jogador vivo no contador, a partida aparece aqui.',
                        textAlign: TextAlign.center, style: TextStyle(color: text.withValues(alpha: 0.55), fontSize: 15)),
                  ]),
                ),
              )
            : TabBarView(children: [
                ListView(padding: const EdgeInsets.all(16), children: [for (final m in matches.matches) _MatchTile(m, text: text, light: light)]),
                _Stats(matches.matches, text: text, light: light),
              ]),
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final MatchRecord match;
  final Color text;
  final bool light;
  const _MatchTile(this.match, {required this.text, required this.light});

  @override
  Widget build(BuildContext context) {
    final m = match;
    final winner = m.winner >= 0 && m.winner < m.players.length ? m.players[m.winner] : null;
    final details = [
      MatchHistoryScreen.duration(m.durationMs),
      if (m.rounds > 0) '${m.rounds} rodadas',
      'vida ${m.startingLife}',
    ].join(' · ');
    return Card(
      color: light ? Colors.black.withValues(alpha: 0.05) : const Color(0xFF1E1E24),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.amber.withValues(alpha: winner != null ? 0.3 : 0))),
      child: ExpansionTile(
        shape: const Border(),
        leading: CircleAvatar(
          backgroundColor: winner != null ? MatchHistoryScreen.colorOf(winner) : Colors.grey,
          child: const Icon(Icons.emoji_events, color: Colors.white),
        ),
        title: Text(winner != null ? '${winner['name']} venceu' : 'Empate', style: TextStyle(color: text, fontWeight: FontWeight.w800, fontSize: 17)),
        subtitle: Text('${MatchHistoryScreen.date(m.at)}\n$details', style: TextStyle(color: text.withValues(alpha: 0.55), fontSize: 12)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          SizedBox(height: 130, child: CustomPaint(size: Size.infinite, painter: _LinesPainter(m, light: light))),
          const SizedBox(height: 10),
          for (int i = 0; i < m.players.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                CircleAvatar(radius: 7, backgroundColor: MatchHistoryScreen.colorOf(m.players[i])),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${m.players[i]['name']}', style: TextStyle(color: text, fontWeight: i == m.winner ? FontWeight.w900 : FontWeight.w600)),
                    if (m.deckOf(i).isNotEmpty) TextSpan(text: '  ·  ${m.deckOf(i)}', style: TextStyle(color: text.withValues(alpha: 0.55))),
                  ])),
                ),
                if (i == m.winner) const Text('👑 ', style: TextStyle(fontSize: 14)),
                Text('${m.players[i]['life']}', style: TextStyle(color: text, fontWeight: FontWeight.w900)),
              ]),
            ),
        ],
      ),
    );
  }
}

/// A vida de todos os jogadores ao longo da partida (uma linha por jogador).
class _LinesPainter extends CustomPainter {
  final MatchRecord match;
  final bool light;
  _LinesPainter(this.match, {required this.light});

  @override
  void paint(Canvas canvas, Size size) {
    final lines = match.timelines.where((t) => t.length >= 2).toList();
    final grid = Paint()..color = (light ? Colors.black : Colors.white).withValues(alpha: 0.08);
    for (int k = 0; k <= 2; k++) {
      canvas.drawLine(Offset(0, size.height * k / 2), Offset(size.width, size.height * k / 2), grid);
    }
    if (lines.isEmpty) return;
    final all = [for (final t in lines) ...t];
    final hi = all.reduce(max) + 2, lo = max(0, all.reduce(min) - 2);
    final span = max(1, hi - lo);
    for (int i = 0; i < match.timelines.length && i < match.players.length; i++) {
      final t = match.timelines[i];
      if (t.length < 2) continue;
      Offset at(int k) => Offset(size.width * k / (t.length - 1), size.height * (1 - (t[k] - lo) / span));
      final path = Path()..moveTo(at(0).dx, at(0).dy);
      for (int k = 1; k < t.length; k++) {
        path.lineTo(at(k).dx, at(k).dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = MatchHistoryScreen.colorOf(match.players[i])
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == match.winner ? 3.5 : 2.2
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_LinesPainter old) => old.match.id != match.id;
}

class _Stats extends StatelessWidget {
  final List<MatchRecord> matches;
  final Color text;
  final bool light;
  const _Stats(this.matches, {required this.text, required this.light});

  Widget _card(String title, List<Widget> children) => Card(
        color: light ? Colors.black.withValues(alpha: 0.05) : const Color(0xFF1E1E24),
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: TextStyle(color: text.withValues(alpha: 0.6), fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: 12)),
            const SizedBox(height: 10),
            ...children,
          ]),
        ),
      );

  Widget _row(MatchStat s, int rank) {
    final pct = (s.rate * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SizedBox(width: 26, child: Text(rank == 0 ? '🥇' : rank == 1 ? '🥈' : rank == 2 ? '🥉' : '${rank + 1}.', style: TextStyle(color: text))),
          Expanded(child: Text(s.name, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontWeight: FontWeight.w700))),
          Text('${s.wins}/${s.played} · $pct%', style: TextStyle(color: text.withValues(alpha: 0.7), fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: s.rate, minHeight: 6, backgroundColor: text.withValues(alpha: 0.08), color: Colors.amber),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final players = MatchProvider.stats(matches);
    final decks = MatchProvider.stats(matches, byDeck: true);
    final avg = MatchProvider.averageDuration(matches);
    final rounds = MatchProvider.longest(matches);
    Widget number(String value, String label) => Expanded(
          child: Column(children: [
            Text(value, style: TextStyle(color: text, fontSize: 24, fontWeight: FontWeight.w900)),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: text.withValues(alpha: 0.55), fontSize: 12)),
          ]),
        );
    return ListView(padding: const EdgeInsets.all(16), children: [
      _card('RESUMO', [
        Row(children: [
          number('${matches.length}', 'partidas'),
          number(avg == Duration.zero ? '—' : MatchHistoryScreen.duration(avg.inMilliseconds), 'duração média'),
          number(rounds == 0 ? '—' : '$rounds', 'mais rodadas'),
        ]),
      ]),
      _card('VITÓRIAS POR JOGADOR', [for (int k = 0; k < players.length; k++) _row(players[k], k)]),
      _card('VITÓRIAS POR DECK / COMANDANTE', [
        if (decks.isEmpty)
          Text('Escolha o deck de cada jogador no contador (toque no nome do jogador) para ver qual deck mais ganha.', style: TextStyle(color: text.withValues(alpha: 0.55)))
        else
          for (int k = 0; k < decks.length; k++) _row(decks[k], k),
      ]),
    ]);
  }
}
