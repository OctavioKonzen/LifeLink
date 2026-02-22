import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../data/providers/game_provider.dart';
import 'continuous_action_button.dart';

class PlayerCardWidget extends StatefulWidget {
  final int index;
  final bool inverted;
  final Color playerColor;
  final GameProvider game;
  final VoidCallback onCommanderTap;
  final VoidCallback onPoisonTap;
  final VoidCallback onStateChanged;

  const PlayerCardWidget({
    super.key,
    required this.index,
    required this.inverted,
    required this.playerColor,
    required this.game,
    required this.onCommanderTap,
    required this.onPoisonTap,
    required this.onStateChanged,
  });

  @override
  State<PlayerCardWidget> createState() => _PlayerCardWidgetState();
}

class _PlayerCardWidgetState extends State<PlayerCardWidget> {
  int _lifeDelta = 0;
  Timer? _lifeDeltaTimer;

  void _updateLife(int amount) {
    widget.game.updateLife(widget.index, amount);
    
    if (amount < 0) {
      AudioPlayer().play(AssetSource('sounds/damage.mp3'));
    }

    setState(() {
      _lifeDelta += amount;
    });
    _lifeDeltaTimer?.cancel();
    _lifeDeltaTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _lifeDelta = 0);
    });

    if (widget.game.lives[widget.index] <= 0) {
      AudioPlayer().play(AssetSource('sounds/death.mp3'));
      HapticFeedback.vibrate();
    }
    widget.onStateChanged();
  }

  void _handlePoisonClick(int amount) {
    if (amount > 0) widget.onPoisonTap();
    widget.game.updatePoison(widget.index, amount);
    
    if (widget.game.poison[widget.index] >= 10 && amount > 0) {
      AudioPlayer().play(AssetSource('sounds/death.mp3'));
      HapticFeedback.vibrate();
    }
    widget.onStateChanged();
  }

  // Janela para digitar a vida
  void _showEditLifeDialog(BuildContext context) {
    final TextEditingController ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Inserir Dano ou Cura", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        content: TextField(
          autofocus: true,
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            hintText: "0",
            hintStyle: TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], minimumSize: const Size(110, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              int val = int.tryParse(ctrl.text) ?? 0;
              if (val > 0) _updateLife(-val); 
              Navigator.pop(ctx);
            },
            child: const Text("- DANO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], minimumSize: const Size(110, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              int val = int.tryParse(ctrl.text) ?? 0;
              if (val > 0) _updateLife(val); 
              Navigator.pop(ctx);
            },
            child: const Text("+ CURA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          )
        ],
      )
    );
  }

  // Janela para renomear
  void _showRenameDialog(BuildContext context) {
    final TextEditingController ctrl = TextEditingController(text: widget.game.playerNames[widget.index]);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Renomear Jogador", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        content: TextField(
          autofocus: true,
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("CANCELAR", style: TextStyle(color: Colors.white54, fontSize: 16))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size(110, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                widget.game.updatePlayerName(widget.index, ctrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text("SALVAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      )
    );
  }

  @override
  void dispose() {
    _lifeDeltaTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int currentLife = widget.game.lives[widget.index];
    final int poisonCount = widget.game.poison[widget.index];
    
    bool hasFatalCmdDmg = false;
    for (int attacker = 0; attacker < widget.game.playerCount; attacker++) {
      if (attacker != widget.index && widget.game.commanderDamage[widget.index][attacker] >= 21) {
        hasFatalCmdDmg = true; break;
      }
    }
    
    final bool isDead = currentLife <= 0 || poisonCount >= 10 || hasFatalCmdDmg;
    final bool isCommanderMode = widget.game.startingLife == 40;

    return RotatedBox(
      quarterTurns: widget.inverted ? 2 : 0,
      child: Container(
        decoration: BoxDecoration(
          color: isDead ? Colors.grey[800] : widget.playerColor,
          borderRadius: BorderRadius.circular(12),
          border: isDead ? Border.all(color: Colors.red[900]!, width: 4) : null,
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(child: GestureDetector(onTap: () => !isDead ? _updateLife(-1) : null, child: Container(color: Colors.transparent))),
                Expanded(child: GestureDetector(onTap: () => !isDead ? _updateLife(1) : null, child: Container(color: Colors.transparent))),
              ],
            ),
            
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => !isDead ? _handlePoisonClick(-1) : null,
                                child: Container(
                                  padding: const EdgeInsets.all(8), 
                                  decoration: const BoxDecoration(color: Colors.black12, shape: BoxShape.circle), 
                                  child: const Icon(Icons.remove, size: 24, color: Colors.black54)
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => !isDead ? _handlePoisonClick(1) : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(15)),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.science, size: 28, color: isDead ? Colors.purple[300] : Colors.purple[900]),
                                      Text("$poisonCount", style: TextStyle(color: isDead ? Colors.purple[300] : Colors.purple[900], fontWeight: FontWeight.bold, fontSize: 16)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          if (isCommanderMode) ...[
                            const SizedBox(width: 20),
                            GestureDetector(
                              onTap: widget.onCommanderTap,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(15)),
                                child: Icon(Icons.shield, size: 32, color: isDead ? Colors.orange[300] : Colors.orange[900]),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 5),

                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // BOTÃO DE SEGURAR (-)
                        ContinuousActionButton(
                          onTap: () => !isDead ? _updateLife(-1) : null,
                          onHoldAction: () => !isDead ? _updateLife(-1) : null,
                          padding: const EdgeInsets.all(8),
                          child: const Icon(Icons.remove, size: 40, color: Colors.black54),
                        ),
                        
                        const SizedBox(width: 5),
                        
                        GestureDetector(
                          onTap: () => !isDead ? _showEditLifeDialog(context) : null,
                          child: SizedBox(
                            width: 120,
                            height: 80,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  isDead ? "💀" : "$currentLife", 
                                  style: TextStyle(color: isDead ? Colors.red[400] : Colors.black, fontSize: isDead ? 50 : 64, fontWeight: FontWeight.bold)
                                ),
                                Positioned(
                                  top: -15,
                                  child: AnimatedOpacity(
                                    opacity: _lifeDelta == 0 ? 0.0 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Text(
                                      _lifeDelta > 0 ? "+$_lifeDelta" : "$_lifeDelta",
                                      style: TextStyle(
                                        fontSize: 28, fontWeight: FontWeight.bold,
                                        color: _lifeDelta > 0 ? Colors.green[800] : Colors.red[800], 
                                        shadows: const [Shadow(color: Colors.white, blurRadius: 4)], 
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 5),

                        // BOTÃO DE SEGURAR (+)
                        ContinuousActionButton(
                          onTap: () => !isDead ? _updateLife(1) : null,
                          onHoldAction: () => !isDead ? _updateLife(1) : null,
                          padding: const EdgeInsets.all(8),
                          child: const Icon(Icons.add, size: 40, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 5),

                  GestureDetector(
                    onTap: () => !isDead ? _showRenameDialog(context) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        widget.game.playerNames[widget.index], 
                        style: TextStyle(
                          color: isDead ? Colors.red[300] : Colors.black87, 
                          fontSize: 18, 
                          fontWeight: FontWeight.bold, 
                          decoration: isDead ? TextDecoration.lineThrough : null
                        )
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}