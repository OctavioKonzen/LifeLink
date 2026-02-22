import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; 
import 'package:audioplayers/audioplayers.dart'; 
import '../../../data/providers/theme_provider.dart'; 
import '../../../data/providers/game_provider.dart';
import '../../widgets/player_card_widget.dart';
import '../../widgets/continuous_action_button.dart';

class LifeCounterScreen extends StatefulWidget {
  const LifeCounterScreen({super.key});

  @override
  State<LifeCounterScreen> createState() => _LifeCounterScreenState();
}

class _LifeCounterScreenState extends State<LifeCounterScreen> {
  final List<Color> _playerColors = [
    const Color(0xFFB5CBE0), const Color(0xFFFCA5A5), 
    const Color(0xFFA5D6A7), const Color(0xFFE8E4D9),
    const Color(0xFFD1C4E9), const Color(0xFFFFCC80)
  ];

  final AudioPlayer _audioSystem = AudioPlayer();

  void _checkGameStatus(BuildContext context, GameProvider game) {
    if (game.playerCount <= 1) return; 

    int aliveCount = 0;
    int winnerIndex = -1;

    for (int i = 0; i < game.playerCount; i++) {
      bool isDead = game.lives[i] <= 0 || game.poison[i] >= 10;
      
      if (!isDead) {
        for (int attacker = 0; attacker < game.playerCount; attacker++) {
          if (i != attacker && game.commanderDamage[i][attacker] >= 21) {
            isDead = true;
            break;
          }
        }
      }

      if (!isDead) {
        aliveCount++;
        winnerIndex = i;
      }
    }

    if (aliveCount == 1 && winnerIndex != -1) {
      Future.delayed(const Duration(milliseconds: 600), () {
        _audioSystem.play(AssetSource('sounds/victory.mp3'));
      });
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
                const SizedBox(height: 16),
                const Text("VITÓRIA!", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 10),
                Text("${game.playerNames[winnerIndex]} venceu a partida!", style: TextStyle(color: _playerColors[winnerIndex], fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    game.resetGame();
                    Navigator.pop(ctx);
                  },
                  child: const Text("JOGAR NOVAMENTE", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _showDiceDialog(GameProvider game) {
    showDialog(context: context, builder: (ctx) => _DiceDialog(playerCount: game.playerCount, playerNames: game.playerNames.sublist(0, game.playerCount), playerColors: _playerColors.sublist(0, game.playerCount)));
  }

  void _showCommanderDamageDialog(int victimIndex) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Consumer<GameProvider>(
          builder: (context, game, child) {
            return Dialog(
              backgroundColor: const Color(0xFF1E1E24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), 
              child: Container(
                width: 400, 
                padding: const EdgeInsets.all(20), 
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    Text("Dano em ${game.playerNames[victimIndex]}", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: game.playerCount,
                        itemBuilder: (ctx, i) => _CommanderAttackerItem(
                          victimIndex: victimIndex,
                          attackerIndex: i,
                          game: game,
                          dialogContext: dialogContext,
                          playerColors: _playerColors,
                          onStateChanged: () => _checkGameStatus(context, game), 
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text("OK", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Provider.of<ThemeProvider>(context).backgroundColor;
    final bool isLightBg = bgColor.computeLuminance() > 0.5;
    
    return Scaffold(
      backgroundColor: bgColor,
      body: Consumer<GameProvider>(
        builder: (context, game, child) {
          final int halfCount = (game.playerCount / 2).floor();
          final int topCount = game.playerCount - halfCount; 
          final int bottomCount = halfCount; 

          return Stack(
            children: [
              SafeArea(
                child: game.playerCount == 1 
                ? Column(
                    children: [
                      Expanded(child: Padding(padding: const EdgeInsets.all(4.0), child: _buildPlayerRow(0, 1, false, game))),
                      _buildCenterMenu(isLightBg, game), 
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: _buildPlayerRow(bottomCount, topCount, true, game)),
                      _buildCenterMenu(isLightBg, game),
                      Expanded(child: _buildPlayerRow(0, bottomCount, false, game)),
                    ],
                  ),
              ),
              Positioned(
                top: 10, left: 10,
                child: SafeArea(
                  child: IconButton(icon: Icon(Icons.close, color: Colors.black.withValues(alpha: 0.45), size: 30), onPressed: () => Navigator.pop(context)),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildPlayerRow(int start, int count, bool inverted, GameProvider game) {
    return Row(
      children: List.generate(count, (i) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: PlayerCardWidget(
              index: start + i,
              inverted: inverted,
              playerColor: _playerColors[start + i],
              game: game,
              onCommanderTap: () => _showCommanderDamageDialog(start + i),
              onPoisonTap: () => _audioSystem.play(AssetSource('sounds/Poison.mp3')),
              onStateChanged: () => _checkGameStatus(context, game), 
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCenterMenu(bool isLightBg, GameProvider game) {
    final color = isLightBg ? Colors.black87 : Colors.white70;
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(icon: Icon(Icons.replay, color: color, size: 28), onPressed: () { game.resetGame(); HapticFeedback.heavyImpact(); }),
            GestureDetector(
              onTap: () { game.toggleCMDMode(); HapticFeedback.mediumImpact(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: game.startingLife == 40 ? Colors.orange.withValues(alpha: 0.2) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: game.startingLife == 40 ? Colors.orange : Colors.transparent)),
                child: Text("CMD", style: TextStyle(color: game.startingLife == 40 ? Colors.orange : color, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            IconButton(icon: CustomPaint(size: const Size(28, 28), painter: GoogleD20IconPainter(color: color)), onPressed: () => _showDiceDialog(game)),
            IconButton(icon: Icon(Icons.person_add, color: color, size: 28), onPressed: () { if (game.playerCount < 6) game.setPlayerCount(game.playerCount + 1); }),
            IconButton(icon: Icon(Icons.remove_circle_outline, color: game.playerCount > 1 ? color : color.withValues(alpha: 0.3), size: 28), onPressed: () { if (game.playerCount > 1) game.setPlayerCount(game.playerCount - 1); }),
          ],
        ),
      ),
    );
  }
}

class _CommanderAttackerItem extends StatefulWidget {
  final int victimIndex;
  final int attackerIndex;
  final GameProvider game;
  final BuildContext dialogContext;
  final List<Color> playerColors;
  final VoidCallback onStateChanged;

  const _CommanderAttackerItem({
    required this.victimIndex,
    required this.attackerIndex,
    required this.game,
    required this.dialogContext,
    required this.playerColors,
    required this.onStateChanged,
  });

  @override
  State<_CommanderAttackerItem> createState() => _CommanderAttackerItemState();
}

class _CommanderAttackerItemState extends State<_CommanderAttackerItem> {
  int _cmdDelta = 0;
  Timer? _cmdDeltaTimer;
  final AudioPlayer _audio = AudioPlayer();

  void _changeCmdDmg(int amount) {
    int current = widget.game.commanderDamage[widget.victimIndex][widget.attackerIndex];
    widget.game.updateCommanderDamage(widget.victimIndex, widget.attackerIndex, amount);
    int newVal = widget.game.commanderDamage[widget.victimIndex][widget.attackerIndex];
    int actualDelta = newVal - current;

    if (actualDelta != 0) {
      if (actualDelta > 0) {
        if (newVal >= 21) {
          _audio.play(AssetSource('sounds/death.mp3'));
          HapticFeedback.vibrate(); 
          widget.onStateChanged(); 
          Navigator.pop(widget.dialogContext);
          return;
        } else {
          _audio.play(AssetSource('sounds/damage.mp3'));
        }
      }
      setState(() => _cmdDelta += actualDelta);
      widget.onStateChanged(); 
      _cmdDeltaTimer?.cancel();
      _cmdDeltaTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _cmdDelta = 0);
      });
    }
  }

  @override
  void dispose() { _cmdDeltaTimer?.cancel(); _audio.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.attackerIndex == widget.victimIndex) return const SizedBox.shrink();
    int dmg = widget.game.commanderDamage[widget.victimIndex][widget.attackerIndex];
    Color dmgColor = dmg >= 21 ? Colors.redAccent : (dmg >= 15 ? Colors.orangeAccent : Colors.white);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: widget.playerColors[widget.attackerIndex], radius: 8),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.game.playerNames[widget.attackerIndex], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
          ContinuousActionButton(onTap: () { if (dmg > 0) _changeCmdDmg(-1); }, onHoldAction: () { if (widget.game.commanderDamage[widget.victimIndex][widget.attackerIndex] > 0) _changeCmdDmg(-1); }, padding: const EdgeInsets.symmetric(horizontal: 4.0), child: const Icon(Icons.remove_circle, color: Colors.white54, size: 40)),
          SizedBox(width: 50, child: Center(child: Text("$dmg", style: TextStyle(color: dmgColor, fontSize: 28, fontWeight: FontWeight.bold)))),
          ContinuousActionButton(onTap: () => _changeCmdDmg(1), onHoldAction: () => _changeCmdDmg(1), padding: const EdgeInsets.symmetric(horizontal: 4.0), child: const Icon(Icons.add_circle, color: Colors.white54, size: 40)),
        ],
      ),
    );
  }
}

class _DiceDialog extends StatefulWidget {
  final int playerCount;
  final List<String> playerNames;
  final List<Color> playerColors;
  const _DiceDialog({required this.playerCount, required this.playerNames, required this.playerColors});
  @override State<_DiceDialog> createState() => _DiceDialogState();
}
class _DiceDialogState extends State<_DiceDialog> {
  late List<int> _vals; bool _rolling = true; final AudioPlayer _audio = AudioPlayer();
  @override void initState() { super.initState(); _vals = List.filled(widget.playerCount, 20); _roll(); }
  void _roll() async {
    setState(() => _rolling = true);
    for (int i = 0; i < widget.playerCount; i++) { AudioPlayer().play(AssetSource('sounds/dice.mp3')); await Future.delayed(const Duration(milliseconds: 120)); }
    int c = 0;
    Timer.periodic(const Duration(milliseconds: 70), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { for (int i = 0; i < widget.playerCount; i++) { _vals[i] = Random().nextInt(20) + 1; } });
      if (c++ > 15) { t.cancel(); setState(() => _rolling = false); HapticFeedback.vibrate(); _audio.play(AssetSource('sounds/victory.mp3')); }
    });
  }
  @override void dispose() { _audio.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    int maxVal = _rolling ? 0 : _vals.reduce(max);
    return Dialog(backgroundColor: const Color(0xFF1E1E24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("Rolar Dados", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 20),
            Wrap(spacing: 20, runSpacing: 20, alignment: WrapAlignment.center, children: List.generate(widget.playerCount, (i) {
                bool isWinner = !_rolling && _vals[i] == maxVal;
                return AnimatedScale(scale: isWinner ? 1.3 : (!_rolling ? 0.8 : 1.0), duration: const Duration(milliseconds: 400), curve: Curves.easeOutBack,
                  child: AnimatedOpacity(opacity: (!_rolling && !isWinner) ? 0.4 : 1.0, duration: const Duration(milliseconds: 400),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Stack(alignment: Alignment.center, children: [Icon(Icons.hexagon, size: 80, color: _rolling ? Colors.white.withValues(alpha: 0.1) : widget.playerColors[i]), Text("${_vals[i]}", style: TextStyle(color: _rolling ? Colors.white : Colors.black, fontSize: 30, fontWeight: FontWeight.bold))]),
                        const SizedBox(height: 5), Text(widget.playerNames[i], style: TextStyle(color: widget.playerColors[i], fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 30),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _rolling ? null : _roll, child: const Text("RODAR NOVAMENTE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ]
        ),
      ),
    );
  }
}

class GoogleD20IconPainter extends CustomPainter {
  final Color color; GoogleD20IconPainter({required this.color});
  @override void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2;
    final path = Path();
    path.moveTo(size.width/2, 0); path.lineTo(size.width, size.height*0.25); path.lineTo(size.width, size.height*0.75); path.lineTo(size.width/2, size.height); path.lineTo(0, size.height*0.75); path.lineTo(0, size.height*0.25); path.close(); path.moveTo(size.width/2, 0); path.lineTo(size.width/2, size.height);
    canvas.drawPath(path, p);
  }
  @override bool shouldRepaint(CustomPainter oldDelegate) => false;
}