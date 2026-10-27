import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/providers/xp_provider.dart';
import '../../../data/providers/game_provider.dart';
import '../../../data/services/scryfall_service.dart';
import 'life_counter_screen.dart';
import 'settings_screen.dart'; 
import 'match_history_screen.dart';
import 'online_screens.dart';
import '../deck/my_decks_screen.dart';
import '../deck/community_decks_screen.dart';
import '../search/card_search_screen.dart';
import '../search/card_scan_screen.dart';
import '../search/set_cards_screen.dart';
import '../search/today_prices_screen.dart'; 
import 'arena_missions_screen.dart';
import 'profile_screen.dart'; 
import 'account_screen.dart';
import '../collection/collection_screen.dart';
import '../../../data/providers/collection_provider.dart';
import '../../../data/account/auth_service.dart';
import '../../widgets/neon.dart';
import '../../theme/app_theme.dart';
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
  // Coleções novas e as que estão para sair (anúncios que abrem a coleção).
  List<Map<String, dynamic>> _sets = const [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85, initialPage: 999);
    _startCarouselTimer();
    ScryfallService.instance.featuredSets().then((sets) {
      if (mounted) setState(() => _sets = sets);
    }).catchError((_) {});
    // Uma vez por dia: avisa se alguma carta da lista de desejos ficou mais barata.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkWishPrices());
  }

  Future<void> _checkWishPrices() async {
    final drops = await context.read<CollectionProvider>().dailyCheck();
    if (!mounted || drops.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ficou mais barata!'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final d in drops.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${d.card.name}: US\$ ${d.before.toStringAsFixed(2)} → US\$ ${d.card.usd.toStringAsFixed(2)}'),
            ),
          if (drops.length > 8) Text('e mais ${drops.length - 8}...'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CollectionScreen(initialTab: 1)));
            },
            child: const Text('Ver lista'),
          ),
        ],
      ),
    );
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
            child: Transform.rotate(angle: -0.15, child: Text('LIFE', style: TextStyle(fontFamily: 'Roboto', fontSize: 52, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: textColor, letterSpacing: -2, shadows: [Shadow(color: LL.gold.withValues(alpha: 0.6), blurRadius: 15)]))),
          ),
          Positioned(
            bottom: 15, right: 65,
            child: Transform.rotate(angle: 0.1, child: Text('LINK', style: TextStyle(fontFamily: 'Roboto', fontSize: 60, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.redAccent, letterSpacing: -4, shadows: [Shadow(color: Colors.redAccent.withValues(alpha: 0.7), blurRadius: 20), const Shadow(color: Colors.orangeAccent, blurRadius: 5)]))),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, Color cardColor, Color textColor, bool isPt) {
    return Material(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: lineOf(cardColor))),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CardSearchScreen())),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            Icon(Icons.search, color: textColor.withValues(alpha: 0.55), size: 24),
            const SizedBox(width: 14),
            Expanded(child: Text("Procurar carta", style: TextStyle(color: textColor.withValues(alpha: 0.55), fontSize: 16))),
            // Escanear com a câmera.
            IconButton(
              icon: const Icon(Icons.document_scanner, color: LL.gold, size: 24),
              tooltip: 'Escanear carta com a câmera',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CardScanScreen())),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ),
      ),
    );
  }

  /// Os botões das áreas, coloridos, como no Pocketdex.
  Widget _buildMenuGrid(BuildContext context, bool isPt, Color cardColor) {
    void go(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    final tiles = [
      ("Meus decks", Icons.layers, LL.gold, () => go(const MyDecksScreen())),
      ("Decks oficiais", Icons.style, const Color(0xFFB388FF), () => go(const CommunityDecksScreen())),
      ("Contador", Icons.favorite, const Color(0xFFFF5252), () => go(const LegacyTheme(child: LifeCounterScreen()))),
      ("Preços", Icons.monetization_on, const Color(0xFFFFA000), () => go(const TodayPricesScreen())),
      ("Missões", Icons.auto_awesome, const Color(0xFF26A69A), () => go(const ArenaMissionsScreen())),
      ("Perfil", Icons.emoji_events, const Color(0xFF00B0FF), () => go(const ProfileScreen())),
      ("Minha coleção", Icons.inventory_2, const Color(0xFFFFD54F), () => go(const CollectionScreen())),
      ("Desejos", Icons.favorite, const Color(0xFFFF4081), () => go(const CollectionScreen(initialTab: 1))),
    ];
    // As linhas dividem a altura que sobra na tela (sem rolar).
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

  /// Um botão da área no desenho novo: cartão escuro com borda, o ícone
  /// dourado num quadrado e o nome embaixo (o menu de sempre).
  Widget _buildMenuTile(String title, IconData icon, Color color, VoidCallback onTap, Color cardColor) {
    final light = cardColor.computeLuminance() > 0.5;
    return Material(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: lineOf(cardColor))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(children: [
          Positioned(right: -12, bottom: -16, child: Icon(icon, size: 92, color: LL.gold.withValues(alpha: light ? 0.12 : 0.07))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: LL.gold.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: LL.gold, size: 22),
              ),
              const Spacer(),
              Text(title, style: TextStyle(color: light ? const Color(0xFF141824) : LL.text, fontSize: 15, fontWeight: FontWeight.w600)),
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
    final Color cardColor = neonSurface(context, bgColor);
    final bool isPt = themeProvider.cardLanguage == 'pt';

    // Cada anúncio abre exatamente o que ele mostra: a página da coleção
    // (com todas as cartas), a lista de banidas ou o MTG Arena.
    final today = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final List<Map<String, dynamic>> newsList = [
      for (final set in _sets)
        () {
          final date = set['date'] as DateTime;
          final upcoming = date.isAfter(today);
          final recent = today.difference(date).inDays <= 60;
          final when = "${two(date.day)}/${two(date.month)}/${date.year}";
          return {
            "image": CardImages.artCropOfSet(set['code'] as String),
            "tag": upcoming ? "EM BREVE" : recent ? "NOVA COLEÇÃO" : "COLEÇÃO",
            "title": set['name'],
            "subtitle": upcoming ? "Chega em $when · veja as cartas" : "Veja todas as cartas",
            "tagColor": upcoming ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6),
            "url": set['scryfall_uri'],
            "setCode": set['code'],
            "setName": set['name'],
          };
        }(),
      {"image": CardImages.artCropByName("Nadu, Winged Wisdom"), "tag": "BANIDAS", "title": "Lista de Banidas\ne Restritas", "tagColor": const Color(0xFFEF4444), "url": "https://magic.wizards.com/en/banned-restricted-list"},
      {"image": CardImages.artCropByName("Sheoldred, the Apocalypse"), "tag": "ARENA", "title": "Jogue Magic\nno MTG Arena", "tagColor": const Color(0xFF10B981), "url": "https://magic.wizards.com/en/mtgarena"},
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
                const SizedBox(height: 10),
                _buildShortcuts(context, cardColor, textColor),
                const SizedBox(height: 10),
                _buildNewsCarousel(newsList, newsHeight),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// Atalhos pequenos: amigos, partidas e mesa online.
  Widget _buildShortcuts(BuildContext context, Color cardColor, Color textColor) {
    Widget chip(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 42,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: lineOf(cardColor)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: LL.gold, size: 18),
                const SizedBox(width: 6),
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13))),
              ]),
            ),
          ),
        );
    void go(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    return Row(children: [
      chip(Icons.group, 'Amigos', const Color(0xFF64FFDA), () => go(const FriendsScreen())),
      chip(Icons.history, 'Partidas', const Color(0xFFB388FF), () => go(const MatchHistoryScreen())),
      chip(Icons.wifi_tethering, 'Mesa online', const Color(0xFF40C4FF), () {
        showDialog(context: context, builder: (_) => OnlineTableDialog(game: context.read<GameProvider>()));
      }),
    ]);
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
                decoration: neonDecoration(AreaColors.profile, cardColor, radius: 16),
                child: Row(children: [
                  const PlayerAvatar(size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(playerNameOf(context),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text("Nív. ${xp.level}",
                            style: const TextStyle(color: LL.gold, fontWeight: FontWeight.w600, fontSize: 12)),
                        if (xp.selectedTitle.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(xp.selectedTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: LL.gold, fontSize: 11, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 6),
                      const LevelBar(color: LL.gold, height: 5),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          tooltip: "Configurações",
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
          icon: Icon(Icons.settings, color: textColor.withValues(alpha: 0.7)),
          style: IconButton.styleFrom(
            backgroundColor: cardColor,
            fixedSize: const Size(48, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: lineOf(cardColor))),
          ),
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
                // Coleção: a tela do app com as cartas na ordem dos números.
                onTap: () => item["setCode"] != null
                    ? Navigator.push(context, MaterialPageRoute(builder: (_) => SetCardsScreen(code: '${item["setCode"]}', name: '${item["setName"]}')))
                    : _openNews(item["url"]),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: lineOf(cardColorOf(context))),
                    // Fundo na cor do anúncio enquanto a arte carrega (ou se falhar).
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [(item["tagColor"] as Color).withValues(alpha: 0.55), const Color(0xFF15151A)],
                    ),
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(item["image"], headers: CardImages.headers),
                      fit: BoxFit.cover,
                      onError: (_, _) {},
                      colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.darken),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end, 
                      children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: item["tagColor"], borderRadius: BorderRadius.circular(4)), child: Text(item["tag"], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                        const SizedBox(height: 8),
                        Text(item["title"], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.2)),
                        if (item["subtitle"] != null)
                          Text(item["subtitle"], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
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
          children: List.generate(newsList.length, (index) => Container(width: 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(shape: BoxShape.circle, color: _currentIndex == index ? LL.gold : Colors.grey.withValues(alpha: 0.4)))),
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
            accountName: Text(playerNameOf(context), style: const TextStyle(fontFamily: LL.display, color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
            accountEmail: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Nível ${xp.level}", style: const TextStyle(color: Colors.white70)),
                if (xp.selectedTitle.isNotEmpty)
                  Text("« ${xp.selectedTitle} »", style: const TextStyle(color: LL.gold, fontWeight: FontWeight.bold, fontSize: 12, fontStyle: FontStyle.italic)),
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
            leading: const Icon(Icons.account_circle, color: LL.gold),
            title: Text("Conta (app e site)", style: TextStyle(color: textColor)),
            subtitle: Text(
              AuthService.instance.user?.email ?? "Entrar para sincronizar",
              style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.person, color: LL.gold),
            title: Text("Meu Perfil / Cosméticos", style: TextStyle(color: textColor)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.group, color: LL.gold),
            title: Text("Amigos", style: TextStyle(color: textColor)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2, color: LL.gold),
            title: Text("Minha coleção", style: TextStyle(color: textColor)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const CollectionScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.history, color: LL.gold),
            title: Text("Histórico de Partidas", style: TextStyle(color: textColor)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MatchHistoryScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: LL.gold),
            title: Text("Configurações", style: TextStyle(color: textColor)),
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