import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/providers/xp_provider.dart';
import '../../../data/services/scryfall_service.dart';
import '../../../data/account/auth_service.dart';
import '../../widgets/player.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neon.dart';
import '../../../data/providers/deck_provider.dart';
import 'arena_missions_screen.dart';

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

  /// Trocar o nick (com conta): o novo precisa estar livre.
  Future<void> _changeNick(String current) async {
    final ctrl = TextEditingController(text: current);
    String? error;
    var busy = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          Future<void> save() async {
            setDialog(() {
              busy = true;
              error = null;
            });
            try {
              await AuthService.instance.changeNick(ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Agora seu nick é ${ctrl.text.trim()}.')));
            } catch (e) {
              setDialog(() {
                busy = false;
                error = e.toString();
              });
            }
          }

          return AlertDialog(
            title: const Text('Trocar nick'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: ctrl, autofocus: true, maxLength: 20, onSubmitted: (_) => save(), decoration: InputDecoration(errorText: error, errorMaxLines: 3)),
              const Text('De 3 a 20 letras, números, espaço, _ ou -. Seus amigos continuam vendo o nick antigo até tirarem e adicionarem de novo.', style: TextStyle(fontSize: 12)),
            ]),
            actions: [
              TextButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'Salvando...' : 'Trocar')),
            ],
          );
        },
      ),
    );
    ctrl.dispose();
  }

  /// Um quadro com o ícone dourado, o nome e o número.
  Widget _stat(BuildContext context, Color bg, Color text, IconData icon, String label, String value) {
    final surface = neonSurface(context, bg);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: lineOf(surface))),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: bg.computeLuminance() > 0.5 ? LL.tint : LL.card, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: LL.gold, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text.withValues(alpha: 0.55), fontSize: 13)),
            Text(value, style: TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
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
            title: const Text("Perfil"),
            actions: [
              if (!signedIn)
              TextButton(
                onPressed: () {
                  themeProvider.setPlayerName(_nameController.text);
                  Navigator.pop(context);
                },
                child: Text("Salvar",
                    style: TextStyle(
                        color: LL.gold, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- O CARTÃO DO PERFIL (o mesmo desenho do site) ---
                // O banner escolhido aparece suave no fundo, com o brilho dourado.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: neonSurface(context, bgColor),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: lineOf(neonSurface(context, bgColor))),
                    ),
                    child: Stack(children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.25,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: activeBanner['colors'], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -60,
                        top: -60,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: LL.gold.withValues(alpha: 0.12), blurRadius: 80, spreadRadius: 20)]),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const PlayerAvatar(size: 88),
                          const SizedBox(height: 16),
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: LL.display, color: textColor, fontSize: 28, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(xpProvider.selectedTitle.isNotEmpty ? xpProvider.selectedTitle : 'Sem título ainda',
                              style: TextStyle(color: xpProvider.selectedTitle.isNotEmpty ? LL.gold : textColor.withValues(alpha: 0.55), fontSize: 14)),
                          const SizedBox(height: 18),
                          Row(children: [
                            Text("Nível ${xpProvider.level}", style: TextStyle(color: LL.gold, fontWeight: FontWeight.w600, fontSize: 13)),
                            const Spacer(),
                            Text("${xpProvider.xp} / ${xpProvider.xpForNextLevel} XP", style: TextStyle(color: textColor.withValues(alpha: 0.55), fontSize: 13)),
                          ]),
                          const SizedBox(height: 8),
                          LevelBar(color: LL.gold, height: 8),
                        ]),
                      ),
                    ]),
                  ),
                ),

                const SizedBox(height: 16),
                // Os números do perfil, em quadros com ícone (como no site).
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.9,
                    children: [
                      _stat(context, bgColor, textColor, Icons.layers_outlined, 'Decks', '${context.watch<DeckProvider>().allDecks.length}'),
                      _stat(context, bgColor, textColor, Icons.construction, 'Decks criados', '${xpProvider.statDecksCreated}'),
                      _stat(context, bgColor, textColor, Icons.add_box_outlined, 'Cartas', '${xpProvider.statCardsAdded}'),
                      _stat(context, bgColor, textColor, Icons.search, 'Buscas', '${xpProvider.statSearches}'),
                      _stat(context, bgColor, textColor, Icons.visibility_outlined, 'Artes vistas', '${xpProvider.statArtsViewed}'),
                      _stat(context, bgColor, textColor, Icons.sports_kabaddi, 'Partidas', '${xpProvider.totalMatchesPlayed}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Material(
                    color: neonSurface(context, bgColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: lineOf(neonSurface(context, bgColor)))),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArenaMissionsScreen())),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: LL.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.track_changes, color: LL.gold),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Missões', style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 16)),
                              Text('Seção ${xpProvider.currentTier}: recompensas iguais às do site.', style: TextStyle(color: textColor.withValues(alpha: 0.55), fontSize: 13)),
                            ]),
                          ),
                          Icon(Icons.chevron_right, color: textColor.withValues(alpha: 0.4)),
                        ]),
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
                    child: Row(children: [
                      Expanded(
                        child: Text("Um nick por pessoa: ao trocar, o antigo fica livre para outros.",
                            style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12)),
                      ),
                      TextButton.icon(onPressed: () => _changeNick(name), icon: const Icon(Icons.edit, size: 16), label: const Text('Trocar nick')),
                    ]),
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
                                  ? LL.gold.withValues(alpha: 0.2)
                                  : (isLight
                                      ? Colors.black.withValues(alpha: 0.05)
                                      : Colors.white10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: isSelected
                                      ? LL.gold
                                      : Colors.transparent),
                            ),
                            child: Text(
                              title,
                              style: TextStyle(
                                color:
                                    isSelected ? LL.gold : textColor,
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
                                      ? LL.gold
                                      : Colors.transparent,
                                  width: 3),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                          color: LL.gold
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