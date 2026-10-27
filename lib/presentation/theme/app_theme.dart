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
      case 0xFFB3E5FC: // Azul
        gold = const Color(0xFF2B7FD4);
        onGold = Colors.white;
        tint = const Color(0xFFCDE9F8);
      case 0xFFC8E6C9: // Verde
        gold = const Color(0xFF2E9A57);
        onGold = Colors.white;
        tint = const Color(0xFFD2EAD4);
      default:
        gold = _gold;
        onGold = _onGold;
        tint = const Color(0xFFF0EDE5);
    }
  }
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
  final surface = light ? Colors.white : Color.lerp(background, LL.surface, background == LL.bg ? 1 : 0.6)!;
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

/// O tema de antes do redesign. O contador de vida continua com ele (pedido:
/// a mesa fica como era).
ThemeData legacyTheme(Color background) {
  final light = _isLight(background);
  return ThemeData(
    useMaterial3: true,
    brightness: light ? Brightness.light : Brightness.dark,
    colorSchemeSeed: Colors.blue,
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: light ? Colors.black87 : Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)))),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)))),
    dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}

/// Mostra [child] com o tema de antes (o contador de vida e as janelas dele).
class LegacyTheme extends StatelessWidget {
  final Widget child;
  const LegacyTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // O contador sempre foi escuro com o fundo antigo.
    final bg = context.watch<ThemeProvider>().backgroundColor;
    return Theme(data: legacyTheme(bg == LL.bg ? const Color(0xFF1E1E24) : bg), child: child);
  }
}
