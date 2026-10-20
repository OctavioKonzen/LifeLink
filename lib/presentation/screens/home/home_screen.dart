import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/providers/xp_provider.dart';
import '../../../data/services/scryfall_service.dart';
import 'life_counter_screen.dart';
import 'settings_screen.dart'; 
import 'match_history_screen.dart'; 
import '../deck/my_decks_screen.dart';
import '../search/card_search_screen.dart'; 
import '../search/today_prices_screen.dart'; 
import 'news_web_screen.dart';
import 'arena_missions_screen.dart';
import 'profile_screen.dart'; 
import 'account_screen.dart';
import '../../../data/account/auth_service.dart';

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

  /// A logo do LifeLink (o D20) com o nome embaixo.
  Widget _buildLogo(Color textColor) {
    return Column(children: [
      Image.asset('assets/logo/lifelink.png', width: 120, height: 120),
      const SizedBox(height: 6),
      Text("LIFELINK", style: TextStyle(color: textColor, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 2)),
    ]);
  }

  Widget _buildSearchBar(BuildContext context, Color cardColor, Color textColor, bool isPt) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CardSearchScreen())),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
  Widget _buildMenuGrid(BuildContext context, bool isPt) {
    void go(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    final tiles = [
      (isPt ? "Meus decks" : "My decks", Icons.layers, const Color(0xFF7C4DFF), () => go(const MyDecksScreen())),
      (isPt ? "Cartas" : "Cards", Icons.search, const Color(0xFF448AFF), () => go(const CardSearchScreen())),
      (isPt ? "Contador" : "Life", Icons.favorite, const Color(0xFFFF5252), () => go(const LifeCounterScreen())),
      (isPt ? "Preços" : "Prices", Icons.monetization_on, const Color(0xFFFFA000), () => go(const TodayPricesScreen())),
      (isPt ? "Missões" : "Missions", Icons.auto_awesome, const Color(0xFF26A69A), () => go(const ArenaMissionsScreen())),
      (isPt ? "Perfil" : "Profile", Icons.emoji_events, const Color(0xFF00B0FF), () => go(const ProfileScreen())),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 14));
      rows.add(Row(children: [
        Expanded(child: _buildMenuTile(tiles[i].$1, tiles[i].$2, tiles[i].$3, tiles[i].$4)),
        const SizedBox(width: 14),
        Expanded(child: _buildMenuTile(tiles[i + 1].$1, tiles[i + 1].$2, tiles[i + 1].$3, tiles[i + 1].$4)),
      ]));
    }
    return Column(children: rows);
  }

  /// Um botão colorido com o ícone grande e transparente no canto e a sombra
  /// mais escura embaixo (o "degrau" dos botões do Pocketdex).
  Widget _buildMenuTile(String title, IconData icon, Color color, VoidCallback onTap) {
    final shade = Color.lerp(color, Colors.black, 0.3)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 104,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: shade, offset: const Offset(0, 6))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned(right: -18, bottom: -22, child: Icon(icon, size: 110, color: Colors.white.withValues(alpha: 0.22))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
            child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, shadows: [Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 3)])),
          ),
        ]),
      ),
    );
  }
  Widget _buildDynamicAvatar(XpProvider xpProvider, double size) {
    final borderData = XpProvider.allBorders.firstWhere((b) => b['id'] == xpProvider.selectedBorderId, orElse: () => XpProvider.allBorders[0]);
    
    return Container(
      width: size, height: size,
      padding: const EdgeInsets.all(3), 
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: borderData['colors']),
        boxShadow: xpProvider.selectedBorderId != "0" ? [BoxShadow(color: borderData['colors'][0].withValues(alpha: 0.5), blurRadius: 10)] : [],
      ),
      child: CircleAvatar(
        backgroundColor: const Color(0xFF2A2A35),
        backgroundImage: xpProvider.selectedAvatar.isNotEmpty ? CachedNetworkImageProvider(xpProvider.selectedAvatar) : null,
        child: xpProvider.selectedAvatar.isEmpty ? Icon(Icons.person, color: Colors.white, size: size * 0.5) : null,
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
    final Color cardColor = isLight ? Colors.black.withValues(alpha: 0.05) : Color.lerp(bgColor, Colors.black, 0.18)!;
    final bool isPt = themeProvider.cardLanguage == 'pt';

    final List<Map<String, dynamic>> newsList = [
      {"image": CardImages.artCropByName("Nadu, Winged Wisdom"), "tag": isPt ? "DESTAQUE" : "FEATURED", "title": isPt ? "Anúncio de Banidas\ne Restritas" : "Banned and Restricted\nAnnouncement", "tagColor": const Color(0xFF3B82F6), "url": "https://magic.wizards.com/en/news/announcements/banned-and-restricted-announcement-2024"},
      {"image": CardImages.artCropByName("Ulamog, the Defiler"), "tag": "SPOILERS", "title": isPt ? "Prévias de Cartas\nModern Horizons 3" : "Modern Horizons 3\nCard Previews", "tagColor": const Color(0xFF8B5CF6), "url": "https://magic.wizards.com/en/news/card-image-gallery/modern-horizons-3"},
      {"image": CardImages.artCropByName("Sheoldred, the Apocalypse"), "tag": isPt ? "EVENTOS" : "EVENTS", "title": isPt ? "Arena Open:\nGanhe \$2,000" : "Arena Open:\nWin \$2,000", "tagColor": const Color(0xFF10B981), "url": "https://magic.wizards.com/en/mtgarena"},
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgColor,
      drawer: _buildDrawer(context, bgColor, textColor, isLight, isPt, themeProvider, xpProvider),
      // Estilo do Pocketdex: o D20 grande e transparente no fundo, a logo no
      // topo, a busca e os botões coloridos das áreas em duas colunas.
      body: Stack(
        children: [
          Positioned(
            right: -120,
            bottom: -80,
            child: Opacity(opacity: 0.06, child: Image.asset('assets/logo/lifelink.png', width: 420, height: 420)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopBar(context, cardColor, textColor, isPt, xpProvider),
                    const SizedBox(height: 8),
                    _buildLogo(textColor),
                    const SizedBox(height: 24),
                    _buildSearchBar(context, cardColor, textColor, isPt),
                    const SizedBox(height: 16),
                    _buildMenuGrid(context, isPt),
                    const SizedBox(height: 28),
                    _buildNewsCarousel(newsList),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Color cardColor, Color textColor, bool isPt, XpProvider xp) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          child: _buildDynamicAvatar(xp, 44),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isPt ? "Nív. ${xp.level}" : "Lvl. ${xp.level}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          if (xp.selectedTitle.isNotEmpty)
             Text(xp.selectedTitle, style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))
          else
             const Row(children: [Icon(Icons.shield, color: Colors.blue, size: 14), SizedBox(width: 4), Icon(Icons.flash_on, color: Colors.red, size: 14)]),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle),
            child: Icon(Icons.settings, color: textColor.withValues(alpha: 0.6), size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildNewsCarousel(List<Map<String, dynamic>> newsList) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentIndex = index % newsList.length),
            itemBuilder: (context, index) {
              final item = newsList[index % newsList.length];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => NewsWebScreen(url: item["url"], title: item["tag"]))),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(image: CachedNetworkImageProvider(item["image"]), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.darken)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
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
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(newsList.length, (index) => Container(width: 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(shape: BoxShape.circle, color: _currentIndex == index ? Colors.blue : Colors.grey.withValues(alpha: 0.5)))),
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
            accountName: Text(themeProvider.playerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
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
              child: _buildDynamicAvatar(xp, 72),
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