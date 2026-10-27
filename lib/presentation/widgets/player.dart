import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../data/account/auth_service.dart';
import '../../data/providers/theme_provider.dart';
import '../../data/providers/xp_provider.dart';
import '../../data/services/scryfall_service.dart';

/// O nome de quem está usando: o nick da conta (único e fixo) ou, sem conta,
/// o nome escolhido no perfil.
String playerNameOf(BuildContext context) {
  final auth = context.watch<AuthService>();
  final nick = auth.status == AuthStatus.signedIn ? auth.user?.name : null;
  return (nick != null && nick.isNotEmpty) ? nick : context.watch<ThemeProvider>().playerName;
}

/// O avatar do jogador com a borda escolhida nas missões.
class PlayerAvatar extends StatelessWidget {
  final double size;
  const PlayerAvatar({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    final xp = context.watch<XpProvider>();
    final border = XpProvider.allBorders.firstWhere((b) => b['id'] == xp.selectedBorderId, orElse: () => XpProvider.allBorders[0]);
    final colors = border['colors'] as List<Color>;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: colors),
        boxShadow: xp.selectedBorderId != "0" ? [BoxShadow(color: colors.first.withValues(alpha: 0.5), blurRadius: 10)] : null,
      ),
      // Sem foto: a inicial do nome no círculo dourado (como no site).
      child: CircleAvatar(
        backgroundColor: LL.gold,
        backgroundImage: xp.selectedAvatar.isNotEmpty ? CachedNetworkImageProvider(xp.selectedAvatar, headers: CardImages.headers) : null,
        child: xp.selectedAvatar.isEmpty
            ? Text(
                playerNameOf(context).trim().isEmpty ? '?' : playerNameOf(context).trim()[0].toUpperCase(),
                style: TextStyle(fontFamily: 'Cinzel', fontWeight: FontWeight.w700, color: LL.onGold, fontSize: size * 0.42),
              )
            : null,
      ),
    );
  }
}

/// Barra de progresso do nível (XP até o próximo nível).
class LevelBar extends StatelessWidget {
  /// A cor da barra (sem ela, a de destaque do tema).
  final Color? color;
  final double height;
  const LevelBar({super.key, this.color, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final xp = context.watch<XpProvider>();
    final start = xp.level > 1 ? (xp.level - 1) * (xp.level - 1) * 100 : 0;
    final end = xp.xpForNextLevel;
    final progress = end > start ? ((xp.xp - start) / (end - start)).clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: height,
        color: color ?? LL.gold,
        backgroundColor: Colors.grey.withValues(alpha: 0.28), // aparece no tema claro e no escuro
      ),
    );
  }
}
