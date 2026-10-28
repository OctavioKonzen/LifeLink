import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/providers/theme_provider.dart';

/// As cores do redesign do LifeLink (as mesmas do site, web-site/src/index.css):
/// noite azul, cartões escuros e dourado.
class LL {
  static const bg = Color(0xFF0A0D17);
  static const surface = Color(0xFF121727);
  static const card = Color(0xFF1A2034);
  static const line = Color(0xFF232A42);
  static const text = Color(0xFFECEEF5);
  static const muted = Color(0xFF8D95AD);
  /// A cor de destaque: dourado na noite e no branco; nos fundos rosa, azul e
  /// verde, a cor do fundo mais forte (igual ao site). Muda com [accentFor].
  static Color gold = _gold;
  static Color onGold = _onGold;

  /// O fundo dos quadrinhos e chips nos temas claros (tingido como no site).
  static Color tint = const Color(0xFFF0EDE5);

  /// O fundo dos cartões e botões nos temas claros: rosa, azul e verde bem
  /// claros (como no site); no branco, branco.
  static Color lightSurface = Colors.white;
  static const _gold = Color(0xFFF0B44C);
  static const _onGold = Color(0xFF1B1305);

  /// Escolhe o destaque para a cor de fundo (chamado pelo tema do app).
  static void accentFor(Color background) {
    // ignore: deprecated_member_use
    switch (background.value) {
      case 0xFFF8BBD0: // Rosa
        gold = const Color(0xFFD94687);
        onGold = Colors.white;
        tint = const Color(0xFFF7D2E0);
        lightSurface = const Color(0xFFFDE8F0);
      case 0xFFB3E5FC: // Azul
        gold = const Color(0xFF2B7FD4);
        onGold = Colors.white;
        tint = const Color(0xFFCDE9F8);
        lightSurface = const Color(0xFFE6F5FD);
      case 0xFFC8E6C9: // Verde
        gold = const Color(0xFF2E9A57);
        onGold = Colors.white;
        tint = const Color(0xFFD2EAD4);
        lightSurface = const Color(0xFFEAF6EB);
      default:
        gold = _gold;
        onGold = _onGold;
        tint = const Color(0xFFF0EDE5);
        lightSurface = Colors.white;
    }
    ink = _isLight(background) ? const Color(0xFF141824) : text;
  }

  /// O texto das janelas no tema escolhido (escuro nos temas claros).
  static Color ink = text;
  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFEF4444);

  /// Títulos em Cinzel (a fonte "de Magic" do design).
  static const display = 'Cinzel';
}

bool _isLight(Color bg) => bg.computeLuminance() > 0.5;

/// O tema do app no desenho novo (Inter no texto, Cinzel nos títulos,
/// botões e campos como os do site). [background] é a cor escolhida nas
/// configurações (o padrão é a noite azul).
ThemeData appTheme(Color background) {
  LL.accentFor(background);
  final light = _isLight(background);
  final text = light ? const Color(0xFF141824) : LL.text;
  final muted = light ? const Color(0xFF5D6478) : LL.muted;
  final surface = light ? LL.lightSurface : Color.lerp(background, LL.surface, background == LL.bg ? 1 : 0.6)!;
  final line = light ? const Color(0xFFE1DCCF) : LL.line;
  final scheme = ColorScheme.fromSeed(
    seedColor: LL.gold,
    brightness: light ? Brightness.light : Brightness.dark,
  ).copyWith(
    primary: LL.gold,
    onPrimary: LL.onGold,
    secondary: LL.gold,
    onSecondary: LL.onGold,
    surface: surface,
    onSurface: text,
    onSurfaceVariant: muted,
    outline: line,
    outlineVariant: line,
    error: LL.danger,
    surfaceContainerHighest: light ? LL.tint : LL.card,
    surfaceContainerHigh: light ? const Color(0xFFF4F2EC) : LL.card,
    surfaceContainer: surface,
    surfaceContainerLow: surface,
    surfaceContainerLowest: background,
  );
  final shape10 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
  final base = ThemeData(useMaterial3: true, brightness: scheme.brightness, fontFamily: 'Inter');
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    dividerColor: line,
    dividerTheme: DividerThemeData(color: line, space: 1),
    textTheme: base.textTheme.apply(bodyColor: text, displayColor: text).copyWith(
          headlineLarge: TextStyle(fontFamily: LL.display, fontWeight: FontWeight.w700, color: text),
          headlineMedium: TextStyle(fontFamily: LL.display, fontWeight: FontWeight.w700, color: text),
          headlineSmall: TextStyle(fontFamily: LL.display, fontWeight: FontWeight.w700, color: text),
        ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: text,
      titleTextStyle: TextStyle(fontFamily: LL.display, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: text),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: line)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: TextStyle(color: muted.withValues(alpha: 0.8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: LL.gold, width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: LL.gold,
        foregroundColor: LL.onGold,
        shape: shape10,
        minimumSize: const Size(0, 44),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: LL.gold,
        foregroundColor: LL.onGold,
        elevation: 0,
        shape: shape10,
        minimumSize: const Size(0, 44),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        side: BorderSide(color: line),
        shape: shape10,
        minimumSize: const Size(0, 44),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: LL.gold, textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: light ? LL.tint : LL.card,
      selectedColor: LL.gold,
      labelStyle: TextStyle(color: text, fontWeight: FontWeight.w500),
      secondaryLabelStyle: TextStyle(color: LL.onGold, fontWeight: FontWeight.w600),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: text,
      unselectedLabelColor: muted,
      indicatorColor: LL.gold,
      dividerColor: line,
      labelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: LL.gold, linearTrackColor: light ? LL.tint : LL.card),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? LL.onGold : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? LL.gold : null),
    ),
    listTileTheme: ListTileThemeData(iconColor: muted, textColor: text),
    iconTheme: IconThemeData(color: text),
    // Janelas, avisos e painéis no mesmo cartão escuro com borda.
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: line)),
      titleTextStyle: TextStyle(fontFamily: LL.display, fontSize: 22, fontWeight: FontWeight.w700, color: text),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: light ? const Color(0xFF141824) : LL.card,
      contentTextStyle: TextStyle(color: light ? Colors.white : LL.text, fontFamily: 'Inter'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    popupMenuTheme: PopupMenuThemeData(color: surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: line))),
    drawerTheme: DrawerThemeData(backgroundColor: background),
    // Troca de tela suave (a do Android mais novo), em todo o app.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}

/// O contador de vida com o tema escolhido (as cores de destaque e as janelas
/// do tema), mas com a letra de sempre nos números (Roboto).
class LegacyTheme extends StatelessWidget {
  final Widget child;
  const LegacyTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = appTheme(context.watch<ThemeProvider>().backgroundColor);
    return Theme(data: t.copyWith(textTheme: t.textTheme.apply(fontFamily: 'Roboto')), child: child);
  }
}

/// As cores do contador de vida no tema escolhido: o fundo da mesa, as
/// janelas e o menu, o texto e o destaque (os quadros dos jogadores têm as
/// cores deles).
class CounterLook {
  final bool light;
  final Color bg; // a mesa (entre os quadros)
  final Color surface; // janelas e o botão do meio
  final Color raised; // botões e opções dentro do menu e das janelas
  final Color text;
  final Color scrim; // o fundo do menu do meio
  const CounterLook._(this.light, this.bg, this.surface, this.raised, this.text, this.scrim);

  Color get accent => LL.gold;
  Color get onAccent => LL.onGold;
  Color muted(double alpha) => text.withValues(alpha: alpha);

  factory CounterLook.of(BuildContext context) {
    final background = context.read<ThemeProvider>().backgroundColor;
    LL.accentFor(background);
    if (_isLight(background)) {
      return CounterLook._(true, background, LL.lightSurface, LL.tint, const Color(0xFF141824), background.withValues(alpha: 0.94));
    }
    return CounterLook._(false, background == LL.bg ? LL.bg : background, LL.surface, LL.card, Colors.white, Colors.black.withValues(alpha: 0.88));
  }
}
