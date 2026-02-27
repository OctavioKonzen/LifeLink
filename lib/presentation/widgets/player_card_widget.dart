import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../data/providers/game_provider.dart';
import 'continuous_action_button.dart';

class PlayerCardWidget extends StatefulWidget {
  final int index;
  final int quarterTurns; 
  final Color playerColor;
  final GameProvider game;
  final VoidCallback onCommanderTap;
  final VoidCallback onPoisonTap;
  final VoidCallback onStateChanged;

  const PlayerCardWidget({
    super.key,
    required this.index,
    required this.quarterTurns,
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
    
    if (amount != 0) {
      AudioPlayer().play(AssetSource('sounds/ploc.mp3'));
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

  void _showEditLifeDialog(BuildContext context) {
    final TextEditingController ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Dano ou Cura", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        // O SingleChildScrollView resolve o bug de esmagamento com a tela deitada!
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                controller: ctrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: "0",
                  hintStyle: TextStyle(color: Colors.white24),
                  isDense: true, // Deixa o campo mais compacto para caber melhor na tela deitada
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                ),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], minimumSize: const Size(100, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              int val = int.tryParse(ctrl.text) ?? 0;
              if (val > 0) _updateLife(-val); 
              Navigator.pop(ctx);
            },
            child: const Text("- DANO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], minimumSize: const Size(100, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              int val = int.tryParse(ctrl.text) ?? 0;
              if (val > 0) _updateLife(val); 
              Navigator.pop(ctx);
            },
            child: const Text("+ CURA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _showRenameDialog(BuildContext context) {
    final TextEditingController ctrl = TextEditingController(text: widget.game.playerNames[widget.index]);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Renomear Jogador", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        // Adicionado ScrollView aqui também para garantir
        content: SingleChildScrollView(
          child: TextField(
            autofocus: true,
            controller: ctrl,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("CANCELAR", style: TextStyle(color: Colors.white54))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                widget.game.updatePlayerName(widget.index, ctrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text("SALVAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      quarterTurns: widget.quarterTurns,
      child: Container(
        decoration: BoxDecoration(
          color: isDead ? Colors.grey[850] : widget.playerColor,
          border: isDead ? Border.all(color: Colors.red[900]!, width: 4) : Border.all(color: Colors.black.withValues(alpha: 0.1), width: 1),
        ),
        child: Stack(
          children: [
            // 1. ÁREA DE TOQUE PARA SOMAR/SUBTRAIR VIDA (Invisível)
            Row(
              children: [
                Expanded(child: GestureDetector(onTap: () => !isDead ? _updateLife(-1) : null, child: Container(color: Colors.transparent))),
                Expanded(child: GestureDetector(onTap: () => !isDead ? _updateLife(1) : null, child: Container(color: Colors.transparent))),
              ],
            ),
            
            // 2. ÍCONES DE VENENO E COMANDANTE
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                // O SEGREDO ESTÁ AQUI: Esse padding de 38 afasta os botões da borda de cima da carta. 
                // Assim, eles fogem do botão de menu redondo, criando um espaço seguro natural!
                padding: const EdgeInsets.only(top: 38.0),
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
                              padding: const EdgeInsets.all(4), 
                              decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle), 
                              child: const Icon(Icons.remove, size: 20, color: Colors.white70)
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => !isDead ? _handlePoisonClick(1) : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.science, size: 20, color: isDead ? Colors.purple[300] : Colors.purpleAccent),
                                  const SizedBox(width: 6),
                                  Text("$poisonCount", style: TextStyle(color: isDead ? Colors.purple[300] : Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 18)),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                Icon(Icons.shield, size: 20, color: isDead ? Colors.orange[300] : Colors.orangeAccent),
                                const SizedBox(width: 6),
                                Text("CMD", style: TextStyle(color: isDead ? Colors.orange[300] : Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ),

            // 3. NÚMERO DA VIDA GIGANTE (No centro)
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ContinuousActionButton(
                      onTap: () => !isDead ? _updateLife(-1) : null,
                      onHoldAction: () => !isDead ? _updateLife(-1) : null,
                      padding: const EdgeInsets.all(8),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.remove, size: 45, color: Colors.white),
                      ),
                    ),
                    
                    const SizedBox(width: 15),
                    
                    GestureDetector(
                      onTap: () => !isDead ? _showEditLifeDialog(context) : null,
                      child: SizedBox(
                        width: 200, 
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Text(
                              isDead ? "💀" : "$currentLife", 
                              style: TextStyle(
                                color: isDead ? Colors.red[400] : Colors.white, 
                                fontSize: isDead ? 70 : 130, 
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                                shadows: [Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
                              )
                            ),
                            Positioned(
                              top: -25, 
                              child: AnimatedOpacity(
                                opacity: _lifeDelta == 0 ? 0.0 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  _lifeDelta > 0 ? "+$_lifeDelta" : "$_lifeDelta",
                                  style: TextStyle(
                                    fontSize: 46, 
                                    fontWeight: FontWeight.bold,
                                    color: _lifeDelta > 0 ? Colors.greenAccent : Colors.redAccent, 
                                    shadows: const [Shadow(color: Colors.black, blurRadius: 4)], 
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 15),

                    ContinuousActionButton(
                      onTap: () => !isDead ? _updateLife(1) : null,
                      onHoldAction: () => !isDead ? _updateLife(1) : null,
                      padding: const EdgeInsets.all(8),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.add, size: 45, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. NOME DO JOGADOR (Fixo perto da borda inferior)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: GestureDetector(
                  onTap: () => !isDead ? _showRenameDialog(context) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      widget.game.playerNames[widget.index], 
                      style: TextStyle(
                        color: isDead ? Colors.red[300] : Colors.white70, 
                        fontSize: 16, 
                        fontWeight: FontWeight.bold, 
                        decoration: isDead ? TextDecoration.lineThrough : null
                      )
                    ),
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}