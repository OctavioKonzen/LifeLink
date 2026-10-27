import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/providers/theme_provider.dart';
import '../theme/app_theme.dart';

/// Cores das áreas do app. No redesign todas usam o dourado (o contador de
/// vida tem as cores dele).
class AreaColors {
  static const decks = LL.gold;
  static const official = LL.gold;
  static const life = Color(0xFFFF5252);
  static const prices = LL.gold;
  static const missions = LL.gold;
  static const profile = LL.gold;
  static const settings = LL.muted;
}

/// Fundo dos cartões (o "surface" do redesign): no tema escuro, o azul
/// do cartão (#121727) puxado para a cor de fundo escolhida.
Color neonSurface(BuildContext context, Color background) => background.computeLuminance() > 0.5
    ? Colors.white
    : background == LL.bg
        ? LL.surface
        : Color.lerp(background, Colors.white, 0.05)!;

/// O fundo do cartão desta tela (a cor escolhida nas configurações).
Color cardColorOf(BuildContext context) => neonSurface(context, context.read<ThemeProvider>().backgroundColor);

/// A borda dos cartões (#232A42 no escuro).
Color lineOf(Color surface) => surface.computeLuminance() > 0.5 ? const Color(0xFFE1DCCF) : LL.line;

/// O cartão do redesign: fundo escuro, borda fina e cantos de 16. A cor da
/// área só tinge a borda de leve ([glow] fica para compatibilidade).
BoxDecoration neonDecoration(Color color, Color surface, {double radius = 16, double glow = 0}) => BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius > 18 ? 16 : radius),
      border: Border.all(color: Color.lerp(lineOf(surface), color, 0.18)!),
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
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: TextStyle(color: textColor.withValues(alpha: 0.6), height: 1.4)),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: onAction,
              child: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
      ),
    );
  }
}
