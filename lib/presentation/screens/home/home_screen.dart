import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/providers/xp_provider.dart';
import '../../../data/services/scryfall_service.dart';
import 'life_counter_screen.dart';
import 'settings_screen.dart'; 
import 'match_history_screen.dart'; 
import '../deck/my_decks_screen.dart';
import '../deck/community_decks_screen.dart';
import '../search/card_search_screen.dart'; 
import '../search/today_prices_screen.dart'; 
import 'arena_missions_screen.dart';
import 'profile_screen.dart'; 
import 'account_screen.dart';
import '../../../data/account/auth_service.dart';
import '../../widgets/neon.dart';
import '../../widgets/player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late PageController _pageController;
  
  int _currentIndex = 0; 
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85, initialPage: 999);
    _startCarouselTimer();
    
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        _pageController.nextPage(duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// A logo "LIFE LINK" em neon (a original do app).
  Widget _buildLogo(Color textColor) {
    // Desenhada em 360x160 e encolhida para o espaço que sobrar na tela.
    return FittedBox(
      child: SizedBox(
      height: 160, width: 360,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(angle: 0.7, child: Icon(Icons.colorize_rounded, size: 100, color: Colors.grey[400], shadows: [Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10)])),
          Positioned(
            top: 15, left: 80,
            child: Transform.rotate(angle: -0.15, child: Text('LIFE', style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: textColor, letterSpacing: -2, shadows: [Shadow(color: Colors.blueAccent.withValues(alpha: 0.6), blurRadius: 15)]))),
          ),
          Positioned(
            bottom: 15, right: 65,
            child: Transform.rotate(angle: 0.1, child: Text('LINK', style: TextStyle(fontSize: 60, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.redAccent, letterSpacing: -4, shadows: [Shadow(color: Colors.redAccent.withValues(alpha: 0.7), blurRadius: 20), const Shadow(color: Colors.orangeAccent, blurRadius: 5)]))),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, Color cardColor, Color textColor, bool isPt) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CardSearchScreen())),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            Icon(Icons.search, color: textColor.withValues(alpha: 0.6), size: 28),
            const SizedBox(width: 16),
            Text(isPt ? "Procurar carta" : "Search card", style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 18)),
          ]),
        ),
      ),
    );
  }

  /// Os botões das áreas, coloridos, como no Pocketdex.
  Widget _buildMenuGrid(BuildContext context, bool isPt, Color cardColor) {
    void go(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    final tiles = [
      (isPt ? "Meus decks" : "My decks", Icons.layers, const Color(0xFF448AFF), () => go(const MyDecksScreen())),
      (isPt ? "Decks oficiais" : "Official decks", Icons.style, const Color(0xFFB388FF), () => go(const CommunityDecksScreen())),
      (isPt ? "Contador" : "Life", Icons.favorite, const Color(0xFFFF5252), () => go(const LifeCounterScreen())),
      (isPt ? "Preços" : "Prices", Icons.monetization_on, const Color(0xFFFFA000), () => go(const TodayPricesScreen())),
      (isPt ? "Missões" : "Missions", Icons.auto_awesome, const Color(0xFF26A69A), () => go(const ArenaMissionsScreen())),
      (isPt ? "Perfil" : "Profile", Icons.emoji_events, const Color(0xFF00B0FF), () => go(const ProfileScreen())),
    ];
    // As 3 linhas dividem a altura que sobra na tela (sem rolar).
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 12));
      rows.add(Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _buildMenuTile(tiles[i].$1, tiles[i].$2, tiles[i].$3, tiles[i].$4, cardColor)),
          const SizedBox(width: 12),
          Expanded(child: _buildMenuTile(tiles[i + 1].$1, tiles[i + 1].$2, tiles[i + 1].$3, tiles[i + 1].$4, cardColor)),
        ]),
      ));
    }
    return Column(children: rows);
  }

  /// Um botão escuro com o brilho neon da cor da área, o ícone grande e
  /// transparente no canto e o nome em cima (organização do Pocketdex).
  Widget _buildMenuTile(String title, IconData icon, Color color, VoidCallback onTap, Color cardColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.2),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 14)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned(right: -14, bottom: -18, child: Icon(icon, size: 100, color: color.withValues(alpha: 0.22))),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: color, size: 26, shadows: [Shadow(color: color.withValues(alpha: 0.8), blurRadius: 10)]),
              const SizedBox(height: 8),
              Text(title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final xpProvider = context.watch<XpProvider>(); 
    
    final bgColor = themeProvider.backgroundColor;
    final bool isLight = bgColor.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;
    final Color cardColor = isLight ? Colors.black.withValues(alpha: 0.05) : Color.lerp(bgColor, Colors.white, 0.03)!;
    final bool isPt = themeProvider.cardLanguage == 'pt';

    final List<Map<String, dynamic>> newsList = [
      {"image": CardImages.artCropByName("Nadu, Winged Wisdom"), "tag": isPt ? "NOTÍCIAS" : "NEWS", "title": isPt ? "Novidades de Magic\nna Wizards" : "Latest Magic\nNews", "tagColor": const Color(0xFF3B82F6), "url": "https://magic.wizards.com/en/news"},
      {"image": CardImages.artCropByName("Ulamog, the Defiler"), "tag": isPt ? "BANIDAS" : "BANNED", "title": isPt ? "Lista de Banidas\ne Restritas" : "Banned and\nRestricted List", "tagColor": const Color(0xFF8B5CF6), "url": "https://magic.wizards.com/en/banned-restricted-list"},
      {"image": CardImages.artCropByName("Sheoldred, the Apocalypse"), "tag": "ARENA", "title": isPt ? "Jogue Magic\nno MTG Arena" : "Play Magic\non MTG Arena", "tagColor": const Color(0xFF10B981), "url": "https://magic.wizards.com/en/mtgarena"},
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgColor,
      drawer: _buildDrawer(context, bgColor, textColor, isLight, isPt, themeProvider, xpProvider),
      // Organização do Pocketdex (busca e botões das áreas em duas colunas)
      // com as cores do LifeLink: fundo escuro, botões com brilho neon.
      // Tudo cabe na tela, sem rolar: o logo e os botões se ajustam à altura
      // e os anúncios ficam no rodapé.
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final newsHeight = (box.maxHeight * 0.17).clamp(96.0, 160.0);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(context, cardColor, textColor, isPt, xpProvider),
                Flexible(
                  flex: 2,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Center(child: _buildLogo(textColor))),
                  ),
                ),
                _buildSearchBar(context, cardColor, textColor, isPt),
                const SizedBox(height: 14),
                Expanded(flex: 5, child: _buildMenuGrid(context, isPt, cardColor)),
                const SizedBox(height: 14),
                _buildNewsCarousel(newsList, newsHeight),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// O topo: o jogador (avatar, nick, nível e XP), que abre o menu, e as
  /// configurações.
  Widget _buildTopBar(BuildContext context, Color cardColor, Color textColor, bool isPt, XpProvider xp) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: Ink(
                padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                decoration: neonDecoration(AreaColors.profile, cardColor, radius: 20, glow: 0.12),
                child: Row(children: [
                  const PlayerAvatar(size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(playerNameOf(context),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text(isPt ? "Nív. ${xp.level}" : "Lvl. ${xp.level}",
                            style: const TextStyle(color: AreaColors.profile, fontWeight: FontWeight.bold, fontSize: 12)),
                        if (xp.selectedTitle.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(xp.selectedTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 6),
                      const LevelBar(color: AreaColors.profile, height: 5),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          tooltip: isPt ? "Configurações" : "Settings",
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
          icon: Icon(Icons.settings, color: textColor.withValues(alpha: 0.7)),
          style: IconButton.styleFrom(backgroundColor: cardColor, fixedSize: const Size(48, 48)),
        ),
      ],
    );
  }

  /// Abre o anúncio direto no navegador do celular.
  Future<void> _openNews(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o link.')));
    }
  }

  Widget _buildNewsCarousel(List<Map<String, dynamic>> newsList, double height) {
    return Column(
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentIndex = index % newsList.length),
            itemBuilder: (context, index) {
              final item = newsList[index % newsList.length];
              return GestureDetector(
                onTap: () => _openNews(item["url"]),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(image: CachedNetworkImageProvider(item["image"]), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.darken)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end, 
                      children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: item["tagColor"], borderRadius: BorderRadius.circular(4)), child: Text(item["tag"], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                        const SizedBox(height: 8),
                        Text(item["title"], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.2)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(newsList.length, (index) => Container(width: 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(shape: BoxShape.circle, color: _currentIndex == index ? Colors.blue : Colors.grey.withValues(alpha: 0.5)))),
        ),
      ],
    );
  }

  // --- DRAWER COM O BANNER NO CABEÇALHO ---
  Widget _buildDrawer(BuildContext context, Color bgColor, Color textColor, bool isLight, bool isPt, ThemeProvider themeProvider, XpProvider xp) {
    final activeBanner = XpProvider.allBanners.firstWhere((b) => b['id'] == xp.selectedBannerId, orElse: () => XpProvider.allBanners[0]);

    return Drawer(
      backgroundColor: bgColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: activeBanner['colors'],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            accountName: Text(playerNameOf(context), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            accountEmail: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isPt ? "Nível ${xp.level}" : "Level ${xp.level}", style: const TextStyle(color: Colors.white70)),
                if (xp.selectedTitle.isNotEmpty)
                  Text("« ${xp.selectedTitle} »", style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
            currentAccountPicture: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
              },
              child: const PlayerAvatar(size: 72),
            ),
          ),
          ListTile(
            leading: Icon(Icons.account_circle, color: textColor),
            title: Text(isPt ? "Conta (app e site)" : "Account (app & site)", style: TextStyle(color: textColor)),
            subtitle: Text(
              AuthService.instance.user?.email ?? (isPt ? "Entrar para sincronizar" : "Sign in to sync"),
              style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.person, color: textColor),
            title: Text(isPt ? "Meu Perfil / Cosméticos" : "My Profile", style: TextStyle(color: textColor)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.history, color: textColor),
            title: Text(isPt ? "Histórico de Partidas" : "Match History", style: TextStyle(color: textColor)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MatchHistoryScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.settings, color: textColor),
            title: Text(isPt ? "Configurações" : "Settings", style: TextStyle(color: textColor)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
            },
          ),
        ],
      ),
    );
  }
}