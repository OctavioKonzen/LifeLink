import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; 
import 'package:audioplayers/audioplayers.dart'; 
import '../../../data/providers/game_provider.dart';
import '../../../data/providers/theme_provider.dart'; 
import '../../widgets/player_card_widget.dart';
import '../../widgets/continuous_action_button.dart'; // <-- IMPORT CORRIGIDO PARA O TOPO!

class LifeCounterScreen extends StatefulWidget {
  const LifeCounterScreen({super.key});

  @override
  State<LifeCounterScreen> createState() => _LifeCounterScreenState();
}

class _LifeCounterScreenState extends State<LifeCounterScreen> {
  final List<Color> _playerColors = [
    const Color(0xFF4B32C3), // Roxo
    const Color(0xFF1BA655), // Verde
    const Color(0xFFD32029), // Vermelho
    const Color(0xFF0073E6), // Azul
    const Color(0xFFD49E4A), // Laranja
    const Color(0xFF6B6B6B)  // Cinzento
  ];

  final AudioPlayer _audioSystem = AudioPlayer();
  
  bool _isMenuOpen = false;

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
      
      final theme = context.read<ThemeProvider>();
      final bgColor = theme.backgroundColor;
      final textColor = bgColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
                const SizedBox(height: 16),
                Text("VITÓRIA!", style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2)),
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
            final theme = context.read<ThemeProvider>();
            final bgColor = theme.backgroundColor;
            final isLight = bgColor.computeLuminance() > 0.5;
            final textColor = isLight ? Colors.black87 : Colors.white;

            return Dialog(
              backgroundColor: bgColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), 
              child: Container(
                width: 400, 
                padding: const EdgeInsets.all(20), 
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    Text("Dano em ${game.playerNames[victimIndex]}", style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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
                          isLight: isLight,
                          textColor: textColor,
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

  Widget _buildMenuIcon(IconData icon, String label, VoidCallback onTap, Color circleColor, Color iconColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: circleColor, 
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withValues(alpha: 0.3), width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
              ),
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard(int index, int quarterTurns, GameProvider game) {
    return PlayerCardWidget(
      index: index,
      quarterTurns: quarterTurns,
      playerColor: _playerColors[index],
      game: game,
      onCommanderTap: () => _showCommanderDamageDialog(index),
      onPoisonTap: () => _audioSystem.play(AssetSource('sounds/Poison.mp3')),
      onStateChanged: () => _checkGameStatus(context, game), 
    );
  }

  Widget _buildPlayerRow(int start, int count, int quarterTurns, GameProvider game) {
    return Row(
      children: List.generate(count, (i) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(1.5),
            child: _buildPlayerCard(start + i, quarterTurns, game),
          ),
        );
      }),
    );
  }

  Widget _buildLayout(GameProvider game) {
    if (game.playerCount <= 1) {
      return Column(children: [Expanded(child: _buildPlayerRow(0, 1, 0, game))]);
    } 
    else if (game.playerCount == 3) {
      return Column(
        children: [
          Expanded(
            flex: 3, 
            child: Row(
              children: [
                Expanded(child: Padding(padding: const EdgeInsets.all(1.5), child: _buildPlayerCard(1, 1, game))), 
                Expanded(child: Padding(padding: const EdgeInsets.all(1.5), child: _buildPlayerCard(2, 3, game))), 
              ],
            ),
          ),
          Expanded(
            flex: 2, 
            child: _buildPlayerRow(0, 1, 0, game) 
          ),
        ],
      );
    } 
    else {
      final int halfCount = (game.playerCount / 2).floor();
      final int topCount = game.playerCount - halfCount; 
      final int bottomCount = halfCount; 

      return Column(
        children: [
          Expanded(child: _buildPlayerRow(bottomCount, topCount, 2, game)), 
          Expanded(child: _buildPlayerRow(0, bottomCount, 0, game)),       
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    
    final buttonBgColor = theme.backgroundColor; 
    final isLight = buttonBgColor.computeLuminance() > 0.5;
    
    final buttonIconColor = isLight ? Colors.black87 : Colors.white;
    final borderColor = isLight ? Colors.black26 : Colors.white38;

    return Scaffold(
      backgroundColor: buttonBgColor, 
      body: Consumer<GameProvider>(
        builder: (context, game, child) {
          
          final double dynamicYAlignment = game.playerCount == 3 ? 0.2 : 0.0;

          return Stack(
            children: [
              SafeArea(
                bottom: false,
                top: false,
                child: _buildLayout(game),
              ),

              AnimatedOpacity(
                opacity: _isMenuOpen ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 250),
                child: Align(
                  alignment: Alignment(0.0, dynamicYAlignment),
                  child: IgnorePointer(
                    ignoring: _isMenuOpen,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        setState(() => _isMenuOpen = true);
                      },
                      child: Container(
                        width: 55, 
                        height: 55,
                        decoration: BoxDecoration(
                          color: buttonBgColor, 
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 2),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)],
                        ),
                        child: Icon(Icons.menu, color: buttonIconColor, size: 28),
                      ),
                    ),
                  ),
                ),
              ),

              Align(
                alignment: Alignment(1.0, dynamicYAlignment),
                child: AnimatedSlide(
                  offset: _isMenuOpen ? const Offset(1.5, 0) : Offset.zero,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context); 
                    },
                    child: CustomPaint(
                      painter: EdgeTrianglePainter(fillColor: buttonBgColor, borderColor: borderColor),
                      child: SizedBox(
                        width: 45,
                        height: 90,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6.0), 
                            child: RotatedBox(
                              quarterTurns: 3, 
                              child: Text("Sair", style: TextStyle(color: buttonIconColor, fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _isMenuOpen
                  ? GestureDetector(
                      key: const ValueKey("MenuOverlay"),
                      onTap: () => setState(() => _isMenuOpen = false), 
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.85),
                        width: double.infinity,
                        height: double.infinity,
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildMenuIcon(Icons.casino, "Rolar Dado", () { setState(() => _isMenuOpen = false); _showDiceDialog(game); }, buttonBgColor, buttonIconColor),
                                _buildMenuIcon(Icons.shield, "CMD: ${game.startingLife == 40 ? 'ON' : 'OFF'}", () { game.toggleCMDMode(); setState(() => _isMenuOpen = false); }, game.startingLife == 40 ? Colors.green : buttonBgColor, game.startingLife == 40 ? Colors.white : buttonIconColor),
                                _buildMenuIcon(Icons.replay, "Reiniciar Partida", () { game.resetGame(); setState(() => _isMenuOpen = false); }, buttonBgColor, buttonIconColor),
                                _buildMenuIcon(Icons.person_add, "Adicionar Jogador", () { if (game.playerCount < 6) game.setPlayerCount(game.playerCount + 1); }, buttonBgColor, buttonIconColor),
                                _buildMenuIcon(Icons.person_remove, "Remover Jogador", () { if (game.playerCount > 2) { game.setPlayerCount(game.playerCount - 1); } }, buttonBgColor, buttonIconColor),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey("Empty")),
              )

            ],
          );
        }
      ),
    );
  }
}

class EdgeTrianglePainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;

  const EdgeTrianglePainter({required this.fillColor, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
      
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    path.moveTo(size.width, 0);               
    path.lineTo(0, size.height / 2);          
    path.lineTo(size.width, size.height);     
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant EdgeTrianglePainter oldDelegate) {
    return oldDelegate.fillColor != fillColor || oldDelegate.borderColor != borderColor;
  }
}

class _CommanderAttackerItem extends StatefulWidget {
  final int victimIndex;
  final int attackerIndex;
  final GameProvider game;
  final BuildContext dialogContext;
  final List<Color> playerColors;
  final bool isLight;
  final Color textColor;
  final VoidCallback onStateChanged;

  const _CommanderAttackerItem({
    required this.victimIndex,
    required this.attackerIndex,
    required this.game,
    required this.dialogContext,
    required this.playerColors,
    required this.isLight,
    required this.textColor,
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
    
    Color dmgColor = dmg >= 21 
        ? Colors.redAccent 
        : (dmg >= 15 ? Colors.orangeAccent : widget.textColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05), 
        borderRadius: BorderRadius.circular(16)
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: widget.playerColors[widget.attackerIndex], radius: 8),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.game.playerNames[widget.attackerIndex], style: TextStyle(color: widget.textColor, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
          ContinuousActionButton(onTap: () { if (dmg > 0) _changeCmdDmg(-1); }, onHoldAction: () { if (widget.game.commanderDamage[widget.victimIndex][widget.attackerIndex] > 0) _changeCmdDmg(-1); }, padding: const EdgeInsets.symmetric(horizontal: 4.0), child: Icon(Icons.remove_circle, color: widget.textColor.withValues(alpha: 0.5), size: 40)),
          SizedBox(width: 50, child: Center(child: Text("$dmg", style: TextStyle(color: dmgColor, fontSize: 28, fontWeight: FontWeight.bold)))),
          ContinuousActionButton(onTap: () => _changeCmdDmg(1), onHoldAction: () => _changeCmdDmg(1), padding: const EdgeInsets.symmetric(horizontal: 4.0), child: Icon(Icons.add_circle, color: widget.textColor.withValues(alpha: 0.5), size: 40)),
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
  
  @override 
  Widget build(BuildContext context) {
    int maxVal = _rolling ? 0 : _vals.reduce(max);
    final theme = Provider.of<ThemeProvider>(context);
    final bgColor = theme.backgroundColor;
    final isLight = bgColor.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return Dialog(
      backgroundColor: bgColor, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("Rolar Dados", style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 20),
            Wrap(spacing: 20, runSpacing: 20, alignment: WrapAlignment.center, children: List.generate(widget.playerCount, (i) {
                bool isWinner = !_rolling && _vals[i] == maxVal;
                return AnimatedScale(scale: isWinner ? 1.3 : (!_rolling ? 0.8 : 1.0), duration: const Duration(milliseconds: 400), curve: Curves.easeOutBack,
                  child: AnimatedOpacity(opacity: (!_rolling && !isWinner) ? 0.4 : 1.0, duration: const Duration(milliseconds: 400),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Stack(alignment: Alignment.center, children: [Icon(Icons.hexagon, size: 80, color: _rolling ? textColor.withValues(alpha: 0.1) : widget.playerColors[i]), Text("${_vals[i]}", style: TextStyle(color: _rolling ? textColor : Colors.black, fontSize: 30, fontWeight: FontWeight.bold))]),
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