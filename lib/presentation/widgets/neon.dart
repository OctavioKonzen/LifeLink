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
