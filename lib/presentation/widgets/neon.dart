import 'package:flutter/material.dart';

/// Cores das áreas do app (as mesmas dos botões da tela inicial).
class AreaColors {
  static const decks = Color(0xFF448AFF);
  static const official = Color(0xFFB388FF);
  static const life = Color(0xFFFF5252);
  static const prices = Color(0xFFFFA000);
  static const missions = Color(0xFF26A69A);
  static const profile = Color(0xFF00B0FF);
  static const settings = Color(0xFF9E9E9E);
}

/// Fundo dos cartões no tema escuro: um pouco mais claro que o fundo da tela.
Color neonSurface(BuildContext context, Color background) =>
    background.computeLuminance() > 0.5 ? Colors.white : Color.lerp(background, Colors.white, 0.04)!;

/// O cartão escuro com borda e brilho neon da cor da área (estilo da tela inicial).
BoxDecoration neonDecoration(Color color, Color surface, {double radius = 20, double glow = 0.22}) => BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: color.withValues(alpha: 0.45), width: 1.2),
      boxShadow: [BoxShadow(color: color.withValues(alpha: glow), blurRadius: 14)],
    );

/// Aviso no meio da tela (lista vazia, erro...), com um botão opcional.
class StatusMessage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const StatusMessage({
    super.key,
    required this.icon,
    required this.title,
    this.color = AreaColors.decks,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.light ? Colors.black87 : Colors.white;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 24)],
            ),
            child: Icon(icon, size: 40, color: color),
          ),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w800)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: TextStyle(color: textColor.withValues(alpha: 0.6), height: 1.4)),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, minimumSize: const Size(0, 46)),
              onPressed: onAction,
              child: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
      ),
    );
  }
}
