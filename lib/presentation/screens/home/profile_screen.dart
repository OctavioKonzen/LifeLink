import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/providers/xp_provider.dart';
import '../../../data/services/scryfall_service.dart';
import '../../../data/account/auth_service.dart';
import '../../widgets/player.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  ThemeProvider? _theme;

  // Sem conta, o nome digitado fica salvo ao sair (sem precisar tocar em Salvar).
  @override
  void dispose() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty && _theme != null && name != _theme!.playerName && AuthService.instance.status != AuthStatus.signedIn) {
      _theme!.setPlayerName(name);
    }
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = _theme = Provider.of<ThemeProvider>(context, listen: false);
    if (_nameController.text.isEmpty) {
      _nameController.text = themeProvider.playerName;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final xpProvider = context.watch<XpProvider>();
    final bgColor = themeProvider.backgroundColor;
    final bool isLight = bgColor.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;
    // Com conta, o nome é o nick (único e fixo); sem conta, dá para editar.
    final signedIn = context.watch<AuthService>().status == AuthStatus.signedIn;
    final name = playerNameOf(context);

    // Busca os dados do Banner selecionado
    final activeBanner = XpProvider.allBanners.firstWhere(
        (b) => b['id'] == xpProvider.selectedBannerId,
        orElse: () => XpProvider.allBanners[0]);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text("Meu perfil",
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            actions: [
              if (!signedIn)
              TextButton(
                onPressed: () {
                  themeProvider.setPlayerName(_nameController.text);
                  Navigator.pop(context);
                },
                child: const Text("Salvar",
                    style: TextStyle(
                        color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- BANNER DE PERFIL (A PARTE PRETA AGORA DINÂMICA) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: activeBanner['colors'],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const PlayerAvatar(size: 80),
                          const SizedBox(width: 20),
                          Expanded(
                              child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis),
                              if (xpProvider.selectedTitle.isNotEmpty)
                                Text("« ${xpProvider.selectedTitle} »",
                                    style: const TextStyle(
                                        color: Colors.amberAccent,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FontStyle.italic)),
                              Text("Nível ${xpProvider.level} · ${xpProvider.xp}/${xpProvider.xpForNextLevel} XP",
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 6),
                              const LevelBar(),
                            ],
                          )),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // NOME: o nick da conta (fixo) ou, sem conta, editável.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(signedIn ? "NICK" : "EDITAR NOME",
                      style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                if (signedIn)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Expanded(child: Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
                        Icon(Icons.lock_outline, size: 18, color: textColor.withValues(alpha: 0.5)),
                      ]),
                    ),
                  )
                else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _nameController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isLight
                          ? Colors.black.withValues(alpha: 0.05)
                          : Colors.white10,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),

                if (signedIn)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                    child: Text("O nick é da sua conta e não pode ser trocado.",
                        style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12)),
                  ),
                const SizedBox(height: 30),

                // --- SELEÇÃO DE BANNERS (HORIZONTAL) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                      "BANNERS DESBLOQUEADOS (${xpProvider.unlockedBanners.length})",
                      style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text('Vencer partidas no contador desbloqueia banners: na 1ª, 2ª, 4ª, 8ª, 16ª...',
                      style: TextStyle(color: textColor.withValues(alpha: 0.45), fontSize: 12)),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: XpProvider.allBanners.map((banner) {
                      bool isUnlocked =
                          xpProvider.unlockedBanners.contains(banner['id']);
                      bool isSelected = xpProvider.selectedBannerId == banner['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: isUnlocked
                              ? () => xpProvider.selectBanner(banner['id'])
                              : null,
                          child: Container(
                            width: 120,
                            height: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                  colors: isUnlocked
                                      ? banner['colors']
                                      : [Colors.grey, Colors.black]),
                              border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                          color: (banner['colors'] as List<Color>)
                                              .first
                                              .withValues(alpha: 0.5),
                                          blurRadius: 10)
                                    ]
                                  : [],
                            ),
                            child: isUnlocked
                                ? null
                                : const Icon(Icons.lock, color: Colors.white54),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 30),

                // TÍTULOS DESBLOQUEADOS (HORIZONTAL)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                      "TÍTULOS DESBLOQUEADOS (${xpProvider.unlockedTitles.length})",
                      style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                if (xpProvider.unlockedTitles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text('Nenhum ainda: complete as seções das Missões para ganhar títulos.',
                        style: TextStyle(color: textColor.withValues(alpha: 0.45), fontSize: 12)),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: xpProvider.unlockedTitles.map((title) {
                      bool isSelected = xpProvider.selectedTitle == title;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () => xpProvider.selectTitle(title),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.amberAccent.withValues(alpha: 0.2)
                                  : (isLight
                                      ? Colors.black.withValues(alpha: 0.05)
                                      : Colors.white10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: isSelected
                                      ? Colors.amberAccent
                                      : Colors.transparent),
                            ),
                            child: Text(
                              title,
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.amberAccent : textColor,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 30),

                // AVATARES (FOTOS) DESBLOQUEADOS (HORIZONTAL)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                      "FOTOS DESBLOQUEADAS (${xpProvider.unlockedAvatars.length})",
                      style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                if (xpProvider.unlockedAvatars.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text('Nenhuma ainda: complete as seções das Missões para ganhar fotos com artes de cartas.',
                        style: TextStyle(color: textColor.withValues(alpha: 0.45), fontSize: 12)),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: Row(
                    children: xpProvider.unlockedAvatars.map((url) {
                      bool isSelected = xpProvider.selectedAvatar == url;
                      return Padding(
                        padding: const EdgeInsets.only(right: 15),
                        child: GestureDetector(
                          onTap: () => xpProvider.selectAvatar(url),
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: isSelected
                                      ? Colors.blueAccent
                                      : Colors.transparent,
                                  width: 3),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                          color: Colors.blueAccent
                                              .withValues(alpha: 0.5),
                                          blurRadius: 10)
                                    ]
                                  : [],
                            ),
                            child: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: url,
                                httpHeaders: CardImages.headers,
                                fit: BoxFit.cover,
                                placeholder: (c, u) =>
                                    const CircularProgressIndicator(),
                                errorWidget: (c, u, e) => const Icon(Icons.person),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 30),

                // CONTORNOS DESBLOQUEADOS (HORIZONTAL)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                      "CONTORNOS DESBLOQUEADOS (${xpProvider.unlockedBorders.length})",
                      style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: xpProvider.unlockedBorders.map((borderId) {
                      final borderData = XpProvider.allBorders.firstWhere(
                          (b) => b['id'] == borderId,
                          orElse: () => XpProvider.allBorders[0]);
                      bool isSelected = xpProvider.selectedBorderId == borderId;

                      return Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: GestureDetector(
                          onTap: () => xpProvider.selectBorder(borderId),
                          child: Column(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: SweepGradient(colors: borderData['colors']),
                                  border: Border.all(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 2),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                              color: (borderData['colors'] as List<Color>)
                                                  .first
                                                  .withValues(alpha: 0.8),
                                              blurRadius: 10)
                                        ]
                                  : [],
                                ),
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF2A2A35)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  borderData['name'],
                                  style: TextStyle(color: textColor, fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 70),
              ],
            ),
          ),
        ),
      ],
    );
  }
}