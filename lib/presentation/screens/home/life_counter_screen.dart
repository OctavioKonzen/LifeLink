import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../data/providers/game_provider.dart';
import '../../../data/providers/xp_provider.dart';
import '../../../data/providers/match_provider.dart';
import '../../../data/providers/deck_provider.dart';
import '../../../data/services/sound_service.dart';
import '../../widgets/player_card_widget.dart';
import '../../widgets/dice_table.dart';
import '../../widgets/continuous_action_button.dart';
import 'planar_dialogs.dart';
import 'online_screens.dart';
import '../../../data/account/online.dart';

/// O contador de vida, inspirado nos apps do gênero (Lifetap, MTG Companion):
/// cada jogador virado para o seu lado da mesa, toque para ±1 e segurar para
/// ir de 1 em 1, acelerando, contadores por jogador, e o menu do meio com reiniciar, jogadores,
/// vida inicial, dados, quem começa, desfazer e histórico. A tela fica acesa.
class LifeCounterScreen extends StatefulWidget {
  const LifeCounterScreen({super.key});

  @override
  State<LifeCounterScreen> createState() => _LifeCounterScreenState();
}

class _LifeCounterScreenState extends State<LifeCounterScreen> {
  bool _menuOpen = false;
  bool _firstPlayer = false; // "Quem começa" aberto (dados em cima de cada um)
  int? _shownWinner; // a vitória já mostrada nesta partida
  final Map<int, GlobalKey> _cardKeys = {};
  final Map<int, int> _turns = {}; // para que lado cada quadro está virado

  @override
  void initState() {
    super.initState();
    // Tela cheia (sem relógio e bateria) e sempre acesa durante a partida.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable().catchError((_) {});
    final game = context.read<GameProvider>();
    _shownWinner = game.winner;
    game.addListener(_onGameChanged);
    game.onChange = _playSound;
    SoundService.instance.load();
  }

  @override
  void dispose() {
    final game = context.read<GameProvider>();
    game.removeListener(_onGameChanged);
    game.onChange = null;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  /// O som de cada mudança: dano, cura, veneno, comandante ou, se o jogador
  /// acabou de morrer, o da morte.
  void _playSound(GameEvent change, bool died) {
    final sound = died
        ? GameSound.morte
        : switch (change.kind) {
            'life' => change.delta < 0 ? GameSound.dano : GameSound.cura,
            'poison' => change.delta > 0 ? GameSound.veneno : GameSound.cura,
            'cmd' => change.delta > 0 ? GameSound.comandante : GameSound.cura,
            _ => null,
          };
    if (sound != null) SoundService.instance.play(sound);
  }

  // Sobrou um só vivo: a vitória vale XP (uma vez por partida) e aparece na tela.
  void _onGameChanged() {
    final game = context.read<GameProvider>();
    final winner = game.winner;
    if (winner == _shownWinner) return;
    _shownWinner = winner;
    if (winner == null || !mounted) return;
    final banner = context.read<XpProvider>().incrementMatches();
    // A partida vai para o histórico (e para as estatísticas).
    final match = MatchRecord.fromGame(game);
    context.read<MatchProvider>().add(match);
    HapticFeedback.heavyImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showVictory(game, winner, banner, match.id);
    });
  }

  // ----------------------------------------------------------- disposição

  /// Como cada quadro fica virado: 0 = para baixo (quem segura o celular),
  /// 2 = de cabeça para baixo (do outro lado da mesa), 1 e 3 = de lado.
  Widget _card(GameProvider game, int index, int turns) {
    _turns[index] = turns;
    return Expanded(
      child: PlayerCardWidget(
        key: _cardKeys.putIfAbsent(index, GlobalKey.new),
        index: index,
        quarterTurns: turns,
        game: game,
        onCounters: () => _showCounters(game, index, turns),
        onSettings: () => _showPlayerSettings(game, index, turns),
        onHistory: () => _showLifeHistory(game, index, turns),
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

  /// Onde os quadros se encontram (a mesma divisão de [_layout]).
  static Alignment _menuAlignment(int players) {
    final fromTop = switch (players) {
      3 => 3 / 5, // fileira de cima com flex 3, a de baixo com 2
      5 => 2 / 3, // colunas com flex 2, o de baixo com 1
      _ => 0.5,
    };
    return Alignment(0, fromTop * 2 - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<GameProvider>(builder: (context, game, _) {
        return Stack(children: [
          Positioned.fill(child: Padding(padding: const EdgeInsets.all(3), child: _layout(game))),

          // O botão do meio, no encontro dos quadros (com 3 e 5 jogadores a
          // fileira de baixo é menor, então o encontro fica mais para baixo).
          Align(
            alignment: _menuAlignment(game.playerCount),
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

          if (_firstPlayer)
            Positioned.fill(
              child: _FirstPlayerOverlay(
                game: game,
                cardRects: () => {
                  for (final e in _cardKeys.entries)
                    if (e.key < game.playerCount && e.value.currentContext?.findRenderObject() is RenderBox)
                      e.key: () {
                        final box = e.value.currentContext!.findRenderObject() as RenderBox;
                        return box.localToGlobal(Offset.zero) & box.size;
                      }(),
                },
                turns: _turns,
                onClose: () => setState(() => _firstPlayer = false),
                // "Começar a partida": já conta os turnos a partir de quem ganhou.
                onStart: (winner) {
                  game.startTurns(winner);
                  setState(() => _firstPlayer = false);
                },
              ),
            ),
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
                  Wrap(alignment: WrapAlignment.center, children: [
                    for (final life in _lifeOptions) _chip('$life', game.startingLife == life, () => _confirmNewGame(game, () => game.setStartingLife(life))),
                    _chip(_lifeOptions.contains(game.startingLife) ? 'Outro' : '${game.startingLife}', !_lifeOptions.contains(game.startingLife), () => _askStartingLife(game)),
                  ]),
                  const SizedBox(height: 26),
                  Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 18, children: [
                    _menuButton(Icons.undo, 'Desfazer', const Color(0xFF00B0FF), () => game.undo(), enabled: game.canUndo),
                    _menuButton(Icons.replay, 'Reiniciar', const Color(0xFFFF5252), () => _confirmNewGame(game, game.resetGame)),
                    _menuButton(Icons.casino, 'Dados', const Color(0xFFFFA000), () => _showDice()),
                    _menuButton(Icons.emoji_people, 'Quem começa', const Color(0xFF69F0AE), () => _showFirstPlayer(game)),
                    _menuButton(Icons.history, 'Histórico', const Color(0xFFB388FF), () => _showHistory(game)),
                    _menuButton(Icons.timer, game.countingTurns ? 'Turnos' : 'Contar turnos', const Color(0xFFFFFFFF), () => _showTurns(game)),
                    _menuButton(Icons.wifi_tethering, OnlineTable.instance.active ? 'Mesa ${OnlineTable.instance.code}' : 'Mesa online', const Color(0xFF64FFDA), () {
                      close();
                      showDialog(context: context, builder: (_) => OnlineTableDialog(game: game));
                    }),
                    _menuButton(Icons.public, 'Planechase', const Color(0xFF90A4AE), () {
                      close();
                      showDialog(context: context, builder: (_) => PlanechaseDialog(game: game));
                    }),
                    _menuButton(Icons.local_fire_department, 'Archenemy', const Color(0xFFFF7043), () {
                      close();
                      showDialog(context: context, builder: (_) => ArchenemyDialog(game: game));
                    }),
                    _menuButton(
                      SoundService.instance.enabled ? Icons.volume_up : Icons.volume_off,
                      SoundService.instance.enabled ? 'Som ligado' : 'Som desligado',
                      const Color(0xFF26C6DA),
                      () async {
                        await SoundService.instance.setEnabled(!SoundService.instance.enabled);
                        setState(() {});
                      },
                    ),
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

  static const _lifeOptions = [20, 25, 30, 40, 50, 60];

  /// Vida inicial à vontade (ex.: 15, 100).
  Future<void> _askStartingLife(GameProvider game) async {
    final ctrl = TextEditingController(text: '${game.startingLife}');
    final life = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('Vida inicial', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(helperText: 'De 1 a 999', helperStyle: TextStyle(color: Colors.white38)),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)), child: const Text('OK')),
        ],
      ),
    );
    if (life == null || life < 1 || life > 999 || !mounted) return;
    _confirmNewGame(game, () => game.setStartingLife(life));
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
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(game.playerNames[index], textAlign: TextAlign.center, style: TextStyle(color: game.colorOf(index), fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                row('Veneno', Icons.science, const Color(0xFFCE93D8), game.counter(Counter.poison, index), (d) => game.updateCounter(Counter.poison, index, d)),
                row('Energia', Icons.bolt, const Color(0xFFFFF176), game.counter(Counter.energy, index), (d) => game.updateCounter(Counter.energy, index, d)),
                row('Experiência', Icons.auto_awesome, Colors.white, game.counter(Counter.experience, index), (d) => game.updateCounter(Counter.experience, index, d)),
                row('Imposto do comandante', Icons.account_balance, const Color(0xFF80CBC4), game.counter(Counter.tax, index), (d) => game.updateCounter(Counter.tax, index, d), step: 2),
                row('Tesouro', Icons.paid, const Color(0xFFFFD54F), game.counter(Counter.treasure, index), (d) => game.updateCounter(Counter.treasure, index, d)),
                row('Tempestade', Icons.thunderstorm, const Color(0xFF90CAF9), game.counter(Counter.storm, index), (d) => game.updateCounter(Counter.storm, index, d)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.location_city, color: Color(0xFFFFF8E1)),
                  title: const Text('Cidade abençoada', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  value: game.counter(Counter.blessing, index) > 0,
                  onChanged: (on) => game.updateCounter(Counter.blessing, index, on ? 1 : -1),
                ),
                Row(children: [
                  Expanded(
                    child: FilterChip(
                      avatar: const Icon(Icons.workspace_premium, color: Color(0xFFFFD54F), size: 18),
                      label: const Text('Monarca'),
                      selected: game.monarch == index,
                      onSelected: (_) => game.setMonarch(index),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilterChip(
                      avatar: const Icon(Icons.fort, color: Color(0xFFFFAB91), size: 18),
                      label: const Text('Iniciativa'),
                      selected: game.initiative == index,
                      onSelected: (_) => game.setInitiative(index),
                    ),
                  ),
                ]),
                const Divider(color: Colors.white12, height: 24),
                // O comandante deste jogador atacou: o dano vai para o outro.
                Text('MEU COMANDANTE ATACOU', style: TextStyle(color: game.colorOf(index), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                for (final a in others)
                  row('em ${game.playerNames[a]}', Icons.gps_fixed, game.colorOf(a), game.commanderDamage[a][index], (d) => game.updateCommanderDamage(a, index, d)),
                const SizedBox(height: 12),
                const Text('DANO DE COMANDANTE QUE RECEBI', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                for (final a in others)
                  row('de ${game.playerNames[a]}', Icons.shield, game.colorOf(a), game.commanderDamage[index][a], (d) => game.updateCommanderDamage(index, a, d)),
                const SizedBox(height: 8),
                const Text('O dano de comandante também tira vida de quem recebe. 21 de um mesmo comandante derrota.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Pronto')),
              ]),
            ),
          );
        },
      );
    });
  }

  /// Como a vida do jogador foi mudando: gráfico e a lista (mais novo em cima).
  void _showLifeHistory(GameProvider game, int index, int turns) {
    String ago(DateTime at) {
      final d = DateTime.now().difference(at);
      if (d.inSeconds < 60) return 'agora';
      if (d.inMinutes < 60) return 'há ${d.inMinutes} min';
      return 'há ${d.inHours} h';
    }

    _playerDialog(turns, (ctx) {
      return AnimatedBuilder(
        animation: game,
        builder: (context, _) {
          final timeline = game.lifeTimeline(index);
          final color = game.colorOf(index);
          final points = [timeline.start, for (final c in timeline.changes) c.life];
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Vida de ${game.playerNames[index]}', textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                SizedBox(height: 110, child: CustomPaint(painter: _LifeChartPainter(points, Color.lerp(color, Colors.white, 0.25)!))),
                const SizedBox(height: 8),
                if (timeline.changes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Ainda sem mudanças de vida nesta partida.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                  )
                else
                  Flexible(
                    child: ListView(shrinkWrap: true, children: [
                      for (final c in timeline.changes.reversed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            SizedBox(
                              width: 56,
                              child: Text(c.delta > 0 ? '+${c.delta}' : '${c.delta}',
                                  style: TextStyle(color: c.delta < 0 ? const Color(0xFFFF8A80) : const Color(0xFFB9F6CA), fontSize: 18, fontWeight: FontWeight.w900)),
                            ),
                            Expanded(
                              child: Text(
                                c.kind == 'cmd' ? 'comandante de ${game.playerNames[c.attacker ?? 0]}' : (c.delta < 0 ? 'dano' : 'cura'),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                            Text('${c.life}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                            const SizedBox(width: 10),
                            SizedBox(width: 58, child: Text(ago(c.at), textAlign: TextAlign.right, style: const TextStyle(color: Colors.white38, fontSize: 12))),
                          ]),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Text('Começou com ${timeline.start}', style: const TextStyle(color: Colors.white38)),
                      ),
                    ]),
                  ),
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
    final deckCtrl = TextEditingController(text: game.deckOf(index));
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
              const SizedBox(height: 12),
              // O deck que a pessoa está usando (para as estatísticas).
              () {
                final myDecks = [for (final d in context.read<DeckProvider>().allDecks) d.name];
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  const Text('DECK (OPCIONAL, PARA AS ESTATÍSTICAS)', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800)),
                  TextField(
                    controller: deckCtrl,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(hintText: 'Nome do deck ou comandante', hintStyle: TextStyle(color: Colors.white24)),
                    onChanged: (v) => game.setDeck(index, v),
                  ),
                  if (myDecks.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final name in myDecks.take(12))
                        ChoiceChip(
                          label: Text(name, overflow: TextOverflow.ellipsis),
                          selected: game.deckOf(index) == name.trim(),
                          onSelected: (_) {
                            final pick = game.deckOf(index) == name.trim() ? '' : name.trim();
                            deckCtrl.text = pick;
                            game.setDeck(index, pick);
                          },
                        ),
                    ]),
                  ],
                ]);
              }(),
              const SizedBox(height: 18),
              () {
              Widget dot({required Color? color, required bool selected, required VoidCallback onTap}) => GestureDetector(
                    onTap: onTap,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color ?? Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: selected ? Colors.white : (color == null ? Colors.white38 : Colors.transparent), width: 3),
                      ),
                      child: color == null ? const Icon(Icons.block, color: Colors.white54, size: 20) : null,
                    ),
                  );
              final second = game.secondColorOf(index);
              final first = game.colorOf(index);
              return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Como vai ficar o quadro (uma cor ou o degradê).
                Container(
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(colors: second != null ? [first, second] : [first, Color.lerp(first, Colors.black, 0.25)!]),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('COR', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                  for (int c = 0; c < GameProvider.palette.length; c++)
                    dot(color: GameProvider.palette[c], selected: game.colorIndexOf(index) == c, onTap: () => game.setPlayerColor(index, c)),
                ]),
                const SizedBox(height: 16),
                const Text('COR 2 (DEGRADÊ, COMO DECK DE DUAS CORES)', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                  dot(color: null, selected: second == null, onTap: () => game.setSecondColor(index, -1)),
                  for (int c = 0; c < GameProvider.palette.length; c++)
                    dot(color: GameProvider.palette[c], selected: game.secondColorIndexOf(index) == c, onTap: () => game.setSecondColor(index, c)),
                ]),
              ]);
            }(),
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
    setState(() {
      _menuOpen = false;
      _firstPlayer = true;
    });
  }

  /// Turnos: escolher quem começa, ou ver o tempo de cada um e parar.
  void _showTurns(GameProvider game) {
    setState(() => _menuOpen = false);
    showDialog(
      context: context,
      builder: (ctx) => AnimatedBuilder(
        animation: game,
        builder: (context, _) {
          final players = [for (int i = 0; i < game.playerCount; i++) i];
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            title: Text(game.countingTurns ? 'Turnos · rodada ${game.turnRound}' : 'Quem joga primeiro?', style: const TextStyle(color: Colors.white)),
            content: SizedBox(
              width: 340,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (!game.countingTurns)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('A vez passa no sentido horário. No quadro de quem joga aparece o tempo e o botão de passar.', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  ),
                for (final i in players)
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(radius: 8, backgroundColor: game.colorOf(i)),
                    title: Text(game.playerNames[i], style: TextStyle(color: Colors.white, fontWeight: game.turnPlayer == i ? FontWeight.w900 : FontWeight.w600)),
                    subtitle: game.countingTurns ? Text('Tempo total: ${_clock(game.turnTotal(i))}', style: const TextStyle(color: Colors.white54)) : null,
                    trailing: game.turnPlayer == i ? const Icon(Icons.play_arrow, color: Colors.white) : null,
                    onTap: game.countingTurns
                        ? null
                        : () {
                            game.startTurns(i);
                            Navigator.pop(ctx);
                          },
                  ),
              ]),
            ),
            actions: [
              if (game.countingTurns) TextButton(onPressed: () => game.stopTurns(), child: const Text('Parar de contar')),
              if (game.countingTurns) TextButton(onPressed: () => game.nextTurn(), child: const Text('Passar a vez')),
              if (!game.countingTurns)
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showFirstPlayer(game);
                  },
                  child: const Text('Sortear nos dados'),
                ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
            ],
          );
        },
      ),
    );
  }

  static String _clock(Duration d) {
    final m = d.inMinutes, s = d.inSeconds % 60;
    return m >= 60 ? '${m ~/ 60}h${(m % 60).toString().padLeft(2, '0')}min' : '${m}min${s.toString().padLeft(2, '0')}s';
  }

  void _showHistory(GameProvider game) {
    const labels = {
      'life': 'vida', 'poison': 'veneno', 'energy': 'energia', 'experience': 'experiência', 'tax': 'imposto', 'cmd': 'comandante', //
      'treasure': 'tesouro', 'storm': 'tempestade', 'blessing': 'cidade abençoada',
    };
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

  void _showVictory(GameProvider game, int winner, String? banner, String matchId) {
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
                    // Foi engano: a partida não acabou (sai do histórico).
                    context.read<MatchProvider>().remove(matchId);
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

/// "Quem começa": cada jogador joga um D20 que cai em cima do quadro dele (a
/// mesa 3D cobre a tela toda). Ganha o maior; se empatar, os empatados jogam
/// de novo.
class _FirstPlayerOverlay extends StatefulWidget {
  final GameProvider game;
  final Map<int, Rect> Function() cardRects; // na tela
  final Map<int, int> turns;
  final VoidCallback onClose;
  final ValueChanged<int> onStart;

  const _FirstPlayerOverlay({required this.game, required this.cardRects, required this.turns, required this.onClose, required this.onStart});

  @override
  State<_FirstPlayerOverlay> createState() => _FirstPlayerOverlayState();
}

class _FirstPlayerOverlayState extends State<_FirstPlayerOverlay> {
  final _table = GlobalKey<DiceTableState>();
  final Map<int, int> _rolls = {};
  List<int> _round = [];
  Set<int> _tied = {};
  int? _winner;
  String _status = 'Jogando os dados...';

  /// Para que lado fica o "alto" de cada quadro na tela (ele pode estar virado).
  static const _towardTop = {0: Offset(0, -1), 1: Offset(1, 0), 2: Offset(0, 1), 3: Offset(-1, 0)};

  String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  void _throw(List<int> players) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final rects = widget.cardRects();
    final items = <({double x, double y, String color, String kind})>[];
    final thrown = <int>[];
    for (final i in players) {
      final r = rects[i];
      if (r == null) continue;
      // O dado cai um pouco para o "alto" do quadro (o número de cada um fica
      // perto do jogador, sem cobrir o dado).
      final dir = _towardTop[widget.turns[i] ?? 0]!;
      final center = r.center + Offset(dir.dx * r.width * 0.16, dir.dy * r.height * 0.16);
      final local = box.globalToLocal(center);
      items.add((x: local.dx / box.size.width, y: local.dy / box.size.height, color: _hex(widget.game.colorOf(i)), kind: 'd20'));
      thrown.add(i);
    }
    setState(() {
      _round = thrown;
      for (final i in thrown) {
        _rolls.remove(i);
      }
    });
    _table.currentState?.rollAt(items);
  }

  void _onResult(DiceResult r) {
    for (var k = 0; k < _round.length && k < r.values.length; k++) {
      _rolls[_round[k]] = r.values[k];
    }
    final best = _round.map((i) => _rolls[i] ?? 0).fold(0, max);
    final tied = _round.where((i) => _rolls[i] == best).toList();
    if (tied.length > 1) {
      HapticFeedback.mediumImpact();
      setState(() {
        _tied = tied.toSet();
        _status = 'Empate no $best! Jogando de novo...';
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _throw(tied);
      });
      return;
    }
    HapticFeedback.heavyImpact();
    SoundService.instance.play(GameSound.cura);
    setState(() {
      _winner = tied.first;
      _tied = {};
      _status = '👑 ${widget.game.playerNames[tied.first]} começa!';
    });
  }

  Widget _badge(int i) {
    final value = _rolls[i];
    if (value == null) return const SizedBox.shrink();
    final win = _winner == i;
    final lost = _winner != null && !win;
    final tied = _tied.contains(i);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: lost ? 0.45 : 1,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 350),
        curve: Curves.elasticOut,
        scale: win ? 1.25 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: win ? const Color(0xFFFFC107) : Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: tied ? const Color(0xFFFFC107) : Colors.white24, width: tied ? 2.5 : 1),
            boxShadow: win ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.7), blurRadius: 24)] : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (win) const Padding(padding: EdgeInsets.only(right: 6), child: Text('👑', style: TextStyle(fontSize: 22))),
            if (win)
              Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${widget.game.playerNames[i]} começa!', style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900)),
                Text('Tirou $value', style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w700)),
              ])
            else
              Text('$value', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rects = widget.cardRects();
    final box = context.findRenderObject() as RenderBox?;
    return Stack(children: [
      Positioned.fill(child: GestureDetector(onTap: _winner != null ? widget.onClose : null, child: Container(color: Colors.black.withValues(alpha: 0.35)))),
      Positioned.fill(
        child: IgnorePointer(
          child: DiceTable(
            key: _table,
            fullScreen: true,
            onReady: () => _throw([for (int i = 0; i < widget.game.playerCount; i++) i]),
            onResult: _onResult,
          ),
        ),
      ),
      // O número de cada jogador, virado para ele, perto da borda dele.
      if (box != null && box.hasSize)
        for (final e in rects.entries)
          Positioned.fromRect(
            rect: box.globalToLocal(e.value.topLeft) & e.value.size,
            child: IgnorePointer(
              child: RotatedBox(
                quarterTurns: widget.turns[e.key] ?? 0,
                child: Align(alignment: const Alignment(0, 0.62), child: _badge(e.key)),
              ),
            ),
          ),
      Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF1E1E24), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white24)),
            child: Text(_status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const SizedBox(height: 10),
          if (_winner != null)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF69F0AE), foregroundColor: Colors.black),
              onPressed: () => widget.onStart(_winner!),
              child: const Text('Começar a partida', style: TextStyle(fontWeight: FontWeight.w900)),
            )
          else
            TextButton(onPressed: widget.onClose, child: const Text('Cancelar', style: TextStyle(color: Colors.white70))),
        ]),
      ),
    ]);
  }
}

/// Gráfico da vida ao longo da partida (linha com a área embaixo).
class _LifeChartPainter extends CustomPainter {
  final List<int> points;
  final Color color;
  _LifeChartPainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = Colors.white10;
    for (int k = 0; k <= 2; k++) {
      final y = size.height * k / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (points.length < 2) return;
    // A faixa da partida (com folga), para as mudanças aparecerem no gráfico.
    final hi = points.reduce(max) + 2, lo = max(0, points.reduce(min) - 2);
    final span = max(1, hi - lo);
    Offset at(int i) => Offset(size.width * i / (points.length - 1), size.height * (1 - (points[i] - lo) / span));
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (int i = 1; i < points.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawPath(line, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round);
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(at(i), 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_LifeChartPainter old) => old.points.toString() != points.toString() || old.color != color;
}
