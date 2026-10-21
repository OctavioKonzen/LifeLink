import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../data/providers/game_provider.dart';
import '../../../data/providers/xp_provider.dart';
import '../../widgets/player_card_widget.dart';
import '../../widgets/dice_table.dart';
import '../../widgets/continuous_action_button.dart';

/// O contador de vida, inspirado nos apps do gênero (Lifetap, MTG Companion):
/// cada jogador virado para o seu lado da mesa, toque para ±1 e segurar para
/// ±10, contadores por jogador, e o menu do meio com reiniciar, jogadores,
/// vida inicial, dados, quem começa, desfazer e histórico. A tela fica acesa.
class LifeCounterScreen extends StatefulWidget {
  const LifeCounterScreen({super.key});

  @override
  State<LifeCounterScreen> createState() => _LifeCounterScreenState();
}

class _LifeCounterScreenState extends State<LifeCounterScreen> {
  bool _menuOpen = false;
  int? _shownWinner; // a vitória já mostrada nesta partida

  @override
  void initState() {
    super.initState();
    // Tela cheia (sem relógio e bateria) e sempre acesa durante a partida.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable().catchError((_) {});
    final game = context.read<GameProvider>();
    _shownWinner = game.winner;
    game.addListener(_onGameChanged);
  }

  @override
  void dispose() {
    context.read<GameProvider>().removeListener(_onGameChanged);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  // Sobrou um só vivo: a vitória vale XP (uma vez por partida) e aparece na tela.
  void _onGameChanged() {
    final game = context.read<GameProvider>();
    final winner = game.winner;
    if (winner == _shownWinner) return;
    _shownWinner = winner;
    if (winner == null || !mounted) return;
    final banner = context.read<XpProvider>().incrementMatches();
    HapticFeedback.heavyImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showVictory(game, winner, banner);
    });
  }

  // ----------------------------------------------------------- disposição

  /// Como cada quadro fica virado: 0 = para baixo (quem segura o celular),
  /// 2 = de cabeça para baixo (do outro lado da mesa), 1 e 3 = de lado.
  Widget _card(GameProvider game, int index, int turns) {
    return Expanded(
      child: PlayerCardWidget(
        key: ValueKey(index),
        index: index,
        quarterTurns: turns,
        game: game,
        onCounters: () => _showCounters(game, index, turns),
        onSettings: () => _showPlayerSettings(game, index, turns),
      ),
    );
  }

  Widget _layout(GameProvider game) {
    final n = game.playerCount;
    if (n == 2) {
      return Column(children: [_card(game, 1, 2), _card(game, 0, 0)]);
    }
    if (n == 3) {
      return Column(children: [
        Expanded(flex: 3, child: Row(children: [_card(game, 1, 1), _card(game, 2, 3)])),
        Expanded(flex: 2, child: Row(children: [_card(game, 0, 0)])),
      ]);
    }
    if (n == 4) {
      return Column(children: [
        Expanded(child: Row(children: [_card(game, 2, 1), _card(game, 3, 3)])),
        Expanded(child: Row(children: [_card(game, 1, 1), _card(game, 0, 3)])),
      ]);
    }
    // 5 e 6: duas colunas de lado e, com 5, um embaixo.
    final side = n == 5 ? 2 : 3;
    final first = n == 5 ? 1 : 0; // com 5, o 0 fica embaixo
    return Column(children: [
      Expanded(
        flex: side,
        child: Row(children: [
          Expanded(child: Column(children: [for (int k = side - 1; k >= 0; k--) _card(game, first + k, 1)])),
          Expanded(child: Column(children: [for (int k = 0; k < side; k++) _card(game, first + side + k, 3)])),
        ]),
      ),
      if (n == 5) Expanded(flex: 1, child: Row(children: [_card(game, 0, 0)])),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<GameProvider>(builder: (context, game, _) {
        return Stack(children: [
          Positioned.fill(child: Padding(padding: const EdgeInsets.all(3), child: _layout(game))),

          // O botão do meio, com a vida inicial em cima.
          Center(
            child: AnimatedScale(
              scale: _menuOpen ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  setState(() => _menuOpen = true);
                },
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, spreadRadius: 2)],
                  ),
                  child: const Icon(Icons.casino_outlined, color: Colors.white, size: 30),
                ),
              ),
            ),
          ),

          if (_menuOpen) _menu(game),
        ]);
      }),
    );
  }

  // ----------------------------------------------------------------- menu

  Widget _menuButton(IconData icon, String label, Color color, VoidCallback onTap, {bool enabled = true}) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 92,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFF26262E),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12)],
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF448AFF) : const Color(0xFF26262E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF448AFF).withValues(alpha: 0.6)),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _menu(GameProvider game) {
    void close() => setState(() => _menuOpen = false);
    return GestureDetector(
      onTap: close,
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: GestureDetector(
                onTap: () {}, // toques dentro do menu não fecham
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('JOGADORES', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Row(mainAxisSize: MainAxisSize.min, children: [for (int n = 2; n <= 6; n++) _chip('$n', game.playerCount == n, () => game.setPlayerCount(n))]),
                  const SizedBox(height: 18),
                  const Text('VIDA INICIAL', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    for (final life in [20, 30, 40]) _chip('$life', game.startingLife == life, () => _confirmNewGame(game, () => game.setStartingLife(life))),
                  ]),
                  const SizedBox(height: 26),
                  Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 18, children: [
                    _menuButton(Icons.undo, 'Desfazer', const Color(0xFF00B0FF), () => game.undo(), enabled: game.canUndo),
                    _menuButton(Icons.replay, 'Reiniciar', const Color(0xFFFF5252), () => _confirmNewGame(game, game.resetGame)),
                    _menuButton(Icons.casino, 'Dados', const Color(0xFFFFA000), () => _showDice()),
                    _menuButton(Icons.emoji_people, 'Quem começa', const Color(0xFF69F0AE), () => _showFirstPlayer(game)),
                    _menuButton(Icons.history, 'Histórico', const Color(0xFFB388FF), () => _showHistory(game)),
                    _menuButton(Icons.close, 'Fechar', Colors.white70, close),
                    _menuButton(Icons.logout, 'Sair', Colors.white70, () => Navigator.pop(context)),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmNewGame(GameProvider game, VoidCallback start) {
    final playing = game.history.isNotEmpty;
    if (!playing) {
      start();
      setState(() => _menuOpen = false);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('Nova partida?', style: TextStyle(color: Colors.white)),
        content: const Text('A vida e os contadores de todos voltam ao começo.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              start();
              setState(() => _menuOpen = false);
            },
            child: const Text('Começar'),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------- janelas do jogador

  /// Uma janela virada para o lado da mesa de quem tocou.
  Future<void> _playerDialog(int turns, Widget Function(BuildContext) builder) {
    return showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E1E24),
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: RotatedBox(quarterTurns: turns, child: builder(ctx)),
      ),
    );
  }

  void _showCounters(GameProvider game, int index, int turns) {
    _playerDialog(turns, (ctx) {
      return AnimatedBuilder(
        animation: game,
        builder: (context, _) {
          Widget row(String label, IconData icon, Color color, int value, void Function(int) change, {int step = 1}) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                ContinuousActionButton(
                  onTap: () => change(-step),
                  onHoldAction: () => change(-step),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.remove_circle, color: Colors.white54, size: 34),
                ),
                SizedBox(width: 44, child: Text('$value', textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900))),
                ContinuousActionButton(
                  onTap: () => change(step),
                  onHoldAction: () => change(step),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.add_circle, color: Colors.white54, size: 34),
                ),
              ]),
            );
          }

          final others = [for (int a = 0; a < game.playerCount; a++) if (a != index) a];
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(game.playerNames[index], textAlign: TextAlign.center, style: TextStyle(color: game.colorOf(index), fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                row('Veneno', Icons.science, const Color(0xFFCE93D8), game.counter(Counter.poison, index), (d) => game.updateCounter(Counter.poison, index, d)),
                row('Energia', Icons.bolt, const Color(0xFFFFF176), game.counter(Counter.energy, index), (d) => game.updateCounter(Counter.energy, index, d)),
                row('Experiência', Icons.auto_awesome, Colors.white, game.counter(Counter.experience, index), (d) => game.updateCounter(Counter.experience, index, d)),
                row('Imposto do comandante', Icons.account_balance, const Color(0xFF80CBC4), game.counter(Counter.tax, index), (d) => game.updateCounter(Counter.tax, index, d), step: 2),
                const Divider(color: Colors.white12, height: 24),
                const Text('DANO DE COMANDANTE RECEBIDO', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                for (final a in others)
                  row(game.playerNames[a], Icons.shield, game.colorOf(a), game.commanderDamage[index][a], (d) => game.updateCommanderDamage(index, a, d)),
                const SizedBox(height: 8),
                const Text('O dano de comandante também tira vida. 21 de um mesmo comandante derrota.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Pronto')),
              ]),
            ),
          );
        },
      );
    });
  }

  void _showPlayerSettings(GameProvider game, int index, int turns) {
    final ctrl = TextEditingController(text: game.playerNames[index]);
    _playerDialog(turns, (ctx) {
      return AnimatedBuilder(
        animation: game,
        builder: (context, _) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Jogador', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: false,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(hintText: 'Nome', hintStyle: TextStyle(color: Colors.white24)),
                onChanged: (v) {
                  if (v.trim().isNotEmpty) game.updatePlayerName(index, v.trim());
                },
              ),
              const SizedBox(height: 18),
              const Text('COR', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                for (int c = 0; c < GameProvider.palette.length; c++)
                  GestureDetector(
                    onTap: () => game.setPlayerColor(index, c),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: GameProvider.palette[c],
                        shape: BoxShape.circle,
                        border: Border.all(color: game.colorIndexOf(index) == c ? Colors.white : Colors.transparent, width: 3),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Pronto')),
            ]),
          ),
        ),
      );
    });
  }

  // ----------------------------------------------------- dados e sorteio

  void _showDice() {
    showDialog(context: context, builder: (_) => const _DiceDialog());
  }

  void _showFirstPlayer(GameProvider game) {
    showDialog(context: context, builder: (_) => _FirstPlayerDialog(game: game));
  }

  void _showHistory(GameProvider game) {
    const labels = {'life': 'vida', 'poison': 'veneno', 'energy': 'energia', 'experience': 'experiência', 'tax': 'imposto', 'cmd': 'comandante'};
    final events = game.history.reversed.toList();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('Histórico da partida', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 360,
          height: 380,
          child: events.isEmpty
              ? const Center(child: Text('Nada ainda nesta partida.', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, k) {
                    final e = events[k];
                    final time = '${e.at.hour.toString().padLeft(2, '0')}:${e.at.minute.toString().padLeft(2, '0')}';
                    final what = e.kind == 'cmd' ? 'comandante de ${game.playerNames[e.attacker!]}' : labels[e.kind]!;
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(radius: 6, backgroundColor: game.colorOf(e.player)),
                      title: Text(game.playerNames[e.player], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      subtitle: Text('$what · $time', style: const TextStyle(color: Colors.white54)),
                      trailing: Text(
                        e.delta > 0 ? '+${e.delta}' : '${e.delta}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: (e.kind == 'life') == (e.delta > 0) ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
      ),
    );
  }

  void _showVictory(GameProvider game, int winner, String? banner) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
            const SizedBox(height: 12),
            const Text('VITÓRIA!', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 8),
            Text('${game.playerNames[winner]} venceu a partida!', textAlign: TextAlign.center, style: TextStyle(color: game.colorOf(winner), fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(banner == null ? '+50 XP' : '+50 XP · Novo banner: $banner', style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    game.undo();
                  },
                  child: const Text('Desfazer'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(ctx);
                    game.resetGame();
                  },
                  child: const Text('Jogar de novo'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Dados: d6, d20 e moeda, com uma rolagem curta.
/// Dados 3D (D4 a D20 e D100, com física: o resultado é a face que fica para
/// cima) e moeda. Toque na mesa ou em "Rolar".
class _DiceDialog extends StatefulWidget {
  const _DiceDialog();

  @override
  State<_DiceDialog> createState() => _DiceDialogState();
}

class _DiceDialogState extends State<_DiceDialog> {
  static const _kinds = [
    ('d4', 'D4', Color(0xFF43A047)),
    ('d6', 'D6', Color(0xFF1E88E5)),
    ('d8', 'D8', Color(0xFF8E24AA)),
    ('d10', 'D10', Color(0xFFF4511E)),
    ('d12', 'D12', Color(0xFFE53935)),
    ('d20', 'D20', Color(0xFFFFA000)),
    ('d100', 'D100', Color(0xFF00897B)),
  ];

  final _random = Random();
  final _table = GlobalKey<DiceTableState>();
  String? _kind = 'd20'; // null = moeda
  String _lastDie = 'd20';
  String _result = '';
  bool _rolling = false;

  void _select(String? kind) {
    if (_rolling) return;
    setState(() {
      _kind = kind;
      if (kind != null) _lastDie = kind;
      _result = '';
    });
  }

  Future<void> _roll() async {
    if (_rolling) return;
    HapticFeedback.lightImpact();
    if (_kind != null) {
      _table.currentState?.roll();
      return;
    }
    // Moeda: vira algumas vezes e para.
    setState(() {
      _rolling = true;
      _result = '';
    });
    for (int k = 0; k < 10; k++) {
      await Future.delayed(Duration(milliseconds: 50 + k * 14));
      if (!mounted) return;
      setState(() => _result = k.isEven ? 'Cara' : 'Coroa');
    }
    _land(_random.nextBool() ? 'Cara' : 'Coroa');
  }

  void _land(String result) {
    HapticFeedback.heavyImpact();
    if (mounted) {
      setState(() {
        _result = result;
        _rolling = false;
      });
    }
  }

  void _onResult(DiceResult r) => _land(r.values.length > 1 ? '${r.total}  (${r.values.join(' + ')})' : '${r.total}');

  Widget _kindChip(String? kind, String label, Color color) {
    final on = _kind == kind;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: on ? Colors.white : Colors.white70, fontWeight: FontWeight.w800)),
      selected: on,
      showCheckmark: false,
      selectedColor: color,
      backgroundColor: const Color(0xFF26262E),
      side: BorderSide(color: on ? color : Colors.white12),
      onSelected: (_) => _select(kind),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kind;
    final color = kind == null ? const Color(0xFFFFA000) : _kinds.firstWhere((k) => k.$1 == kind).$3;
    final hint = !_rolling && _result.isEmpty;
    final text = _rolling ? '' : (hint ? (kind == null ? 'Toque em Rolar' : 'Toque na mesa para rolar') : _result);

    return Dialog(
      backgroundColor: const Color(0xFF1E1E24),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Dados', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
            for (final k in _kinds) _kindChip(k.$1, k.$2, k.$3),
            _kindChip(null, 'Moeda', const Color(0xFFFFA000)),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(children: [
                // A mesa fica aberta mesmo na moeda (não recarrega o 3D).
                Offstage(
                  offstage: kind == null,
                  child: DiceTable(
                    key: _table,
                    kind: _lastDie,
                    onRolling: () => setState(() {
                      _rolling = true;
                      _result = '';
                    }),
                    onResult: _onResult,
                  ),
                ),
                if (kind == null)
                  Center(
                    child: Container(
                      width: 150,
                      height: 150,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(colors: [Color(0xFFFFE082), Color(0xFFFFA000)]),
                        boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 24)],
                      ),
                      child: Text(_result.isEmpty ? '?' : _result, style: const TextStyle(color: Color(0xFF5D4037), fontSize: 30, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ]),
            ),
          ),
          SizedBox(
            height: 56,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                child: Text(
                  text,
                  key: ValueKey(text),
                  style: hint
                      ? const TextStyle(color: Colors.white38, fontSize: 14)
                      : TextStyle(color: color, fontSize: 40, fontWeight: FontWeight.w900, shadows: [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 16)]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
            onPressed: _rolling ? null : _roll,
            icon: const Icon(Icons.casino),
            label: const Text('Rolar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ]),
      ),
    );
  }
}

/// Sorteia quem começa: passa pelos nomes e para em um.
class _FirstPlayerDialog extends StatefulWidget {
  final GameProvider game;
  const _FirstPlayerDialog({required this.game});

  @override
  State<_FirstPlayerDialog> createState() => _FirstPlayerDialogState();
}

class _FirstPlayerDialogState extends State<_FirstPlayerDialog> {
  final _random = Random();
  int _current = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _spin();
  }

  Future<void> _spin() async {
    setState(() => _done = false);
    final n = widget.game.playerCount;
    final target = _random.nextInt(n);
    final steps = n * 3 + ((target - _current) % n + n) % n;
    for (int k = 0; k < steps; k++) {
      await Future.delayed(Duration(milliseconds: 60 + (k * 180 ~/ steps)));
      if (!mounted) return;
      setState(() => _current = (_current + 1) % n);
      HapticFeedback.selectionClick();
    }
    HapticFeedback.heavyImpact();
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return Dialog(
      backgroundColor: game.colorOf(_current),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_done ? 'Quem começa' : 'Sorteando...', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text(game.playerNames[_current], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          if (_done)
            Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(onPressed: _spin, child: const Text('Sortear de novo', style: TextStyle(color: Colors.white))),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ]),
        ]),
      ),
    );
  }
}
