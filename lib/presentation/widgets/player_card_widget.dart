import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/providers/game_provider.dart';

/// O quadro de um jogador no contador de vida, como nos apps do gênero:
///   • toque na metade esquerda tira 1 de vida, na direita soma 1;
///   • segurando, vai de 10 em 10 (e continua enquanto segura);
///   • o quanto mudou (ex.: −7) aparece em cima da vida por 2 segundos;
///   • os contadores (veneno, energia, experiência, imposto e dano de
///     comandante) ficam embaixo; tocar abre todos eles;
///   • tocar no nome (embaixo, com os contadores) troca o nome e a cor.
class PlayerCardWidget extends StatefulWidget {
  final int index;
  final int quarterTurns;
  final GameProvider game;
  final VoidCallback onCounters;
  final VoidCallback onSettings;

  const PlayerCardWidget({
    super.key,
    required this.index,
    required this.quarterTurns,
    required this.game,
    required this.onCounters,
    required this.onSettings,
  });

  @override
  State<PlayerCardWidget> createState() => _PlayerCardWidgetState();
}

class _PlayerCardWidgetState extends State<PlayerCardWidget> {
  int _lifeDelta = 0;
  Timer? _deltaTimer;
  Timer? _holdTimer;

  void _change(int amount) {
    final wasDead = widget.game.isDead(widget.index);
    widget.game.updateLife(widget.index, amount);
    HapticFeedback.selectionClick();
    setState(() => _lifeDelta += amount);
    _deltaTimer?.cancel();
    _deltaTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _lifeDelta = 0);
    });
    if (!wasDead && widget.game.isDead(widget.index)) HapticFeedback.heavyImpact();
  }

  // Segurar: −10/+10 na hora e a cada meio segundo enquanto segura.
  void _startHold(int sign) {
    _change(10 * sign);
    HapticFeedback.mediumImpact();
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 550), (_) => _change(10 * sign));
  }

  void _stopHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  @override
  void dispose() {
    _deltaTimer?.cancel();
    _holdTimer?.cancel();
    super.dispose();
  }

  Widget _zone(int sign) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _change(sign),
        onLongPressStart: (_) => _startHold(sign),
        onLongPressEnd: (_) => _stopHold(),
        onLongPressCancel: _stopHold,
        child: Align(
          alignment: sign < 0 ? const Alignment(-0.75, 0) : const Alignment(0.75, 0),
          child: Icon(sign < 0 ? Icons.remove : Icons.add, color: Colors.white.withValues(alpha: 0.35), size: 34),
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String text, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final i = widget.index;
    final life = game.lives[i];
    final dead = game.isDead(i);
    final color = game.colorOf(i);
    int cmdTotal = 0;
    for (int a = 0; a < game.playerCount; a++) {
      if (a != i) cmdTotal += game.commanderDamage[i][a];
    }
    final commander = game.startingLife >= 30;

    final badges = <Widget>[
      if (game.counter(Counter.poison, i) > 0) _badge(Icons.science, '${game.counter(Counter.poison, i)}', const Color(0xFFE1BEE7)),
      if (commander || cmdTotal > 0) _badge(Icons.shield, '$cmdTotal', const Color(0xFFFFE0B2)),
      if (game.counter(Counter.energy, i) > 0) _badge(Icons.bolt, '${game.counter(Counter.energy, i)}', const Color(0xFFFFF59D)),
      if (game.counter(Counter.experience, i) > 0) _badge(Icons.auto_awesome, '${game.counter(Counter.experience, i)}', Colors.white),
      if (game.counter(Counter.tax, i) > 0) _badge(Icons.account_balance, '+${game.counter(Counter.tax, i)}', const Color(0xFFB2DFDB)),
    ];

    return RotatedBox(
      quarterTurns: widget.quarterTurns,
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dead ? [Colors.grey.shade800, Colors.grey.shade900] : [Color.lerp(color, Colors.white, 0.08)!, Color.lerp(color, Colors.black, 0.25)!],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          // Toque: metade esquerda −, metade direita +.
          Row(children: [_zone(-1), _zone(1)]),

          // A vida, do tamanho que couber, e o quanto mudou em cima.
          IgnorePointer(
            child: LayoutBuilder(builder: (context, box) {
              final size = (box.maxHeight * 0.42).clamp(40.0, 200.0);
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedOpacity(
                    opacity: _lifeDelta == 0 ? 0 : 1,
                    duration: const Duration(milliseconds: 150),
                    child: Text(
                      _lifeDelta > 0 ? '+$_lifeDelta' : '$_lifeDelta',
                      style: TextStyle(
                        fontSize: size * 0.28,
                        fontWeight: FontWeight.w900,
                        color: _lifeDelta >= 0 ? const Color(0xFFB9F6CA) : const Color(0xFFFFCDD2),
                        shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                      ),
                    ),
                  ),
                  FittedBox(
                    child: Text(
                      '$life',
                      style: TextStyle(
                        color: dead ? Colors.white38 : Colors.white,
                        fontSize: size,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        shadows: [Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                    ),
                  ),
                ]),
              );
            }),
          ),

          // Derrotado: caveira por cima (ainda dá para mexer, se foi engano).
          if (dead)
            IgnorePointer(
              child: Center(
                child: Opacity(opacity: 0.85, child: Text('💀', style: TextStyle(fontSize: 64, shadows: [Shadow(color: Colors.red.shade900, blurRadius: 20)]))),
              ),
            ),

          // Embaixo (o lado de quem joga, longe do botão do meio): o nome,
          // que troca nome e cor, e os contadores em uso, que abrem todos.
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 8, right: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    onTap: widget.onSettings,
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          game.playerNames[i],
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, decoration: dead ? TextDecoration.lineThrough : null),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.edit, size: 14, color: Colors.white70),
                      ]),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onCounters,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      ...badges,
                      _badge(Icons.add_circle_outline, badges.isEmpty ? 'Contadores' : '', Colors.white70),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
