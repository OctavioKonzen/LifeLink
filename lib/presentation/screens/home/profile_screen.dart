import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/providers/xp_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    if (_nameController.text.isEmpty) {
      _nameController.text = themeProvider.playerName;
    }
  }

  // Auxiliar para construir o avatar com borda mística
  Widget _buildDynamicAvatar(XpProvider xpProvider, double size) {
    final borderData = XpProvider.allBorders.firstWhere(
        (b) => b['id'] == xpProvider.selectedBorderId,
        orElse: () => XpProvider.allBorders[0]);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(colors: borderData['colors'])),
      child: CircleAvatar(
        backgroundColor: const Color(0xFF2A2A35),
        backgroundImage: xpProvider.selectedAvatar.isNotEmpty
            ? CachedNetworkImageProvider(xpProvider.selectedAvatar)
            : null,
        child: xpProvider.selectedAvatar.isEmpty
            ? Icon(Icons.person, color: Colors.white, size: size * 0.5)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final xpProvider = context.watch<XpProvider>();
    final bgColor = themeProvider.backgroundColor;
    final bool isLight = bgColor.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;

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
              TextButton(
                onPressed: () {
                  themeProvider.setPlayerName(_nameController.text);
                  Navigator.pop(context);
                },
                child: const Text("SALVAR",
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
                          _buildDynamicAvatar(xpProvider, 80),
                          const SizedBox(width: 20),
                          Expanded(
                              child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(themeProvider.playerName,
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
                              Text("Nível ${xpProvider.level}",
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          )),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // NOME DO JOGADOR (CAMPO DE EDIÇÃO)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text("EDITAR NOME",
                      style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
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