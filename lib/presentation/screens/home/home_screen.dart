import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/theme_provider.dart';
import 'life_counter_screen.dart';
import 'settings_screen.dart'; 
import 'match_history_screen.dart'; 
import '../deck/my_decks_screen.dart';
import '../search/card_search_screen.dart'; 
import 'news_web_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late PageController _pageController;
  
  int _currentIndex = 0; 
  Timer? _carouselTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85, initialPage: 999);
    _startCarouselTimer();
    
    _pulseController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 2)
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
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
    _pulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildVersusLogo(Color textColor) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: SizedBox(
        height: 160,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: 0.7, 
              child: Icon(
                Icons.colorize_rounded, 
                size: 100,
                color: Colors.grey[400],
                shadows: [
                  Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10)
                ],
              ),
            ),
            
            Positioned(
              top: 15,
              left: MediaQuery.of(context).size.width * 0.22, 
              child: Transform.rotate(
                angle: -0.15, 
                child: Text(
                  'LIFE',
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: textColor,
                    letterSpacing: -2,
                    shadows: [
                      Shadow(color: Colors.blueAccent.withValues(alpha: 0.6), blurRadius: 15),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 15,
              right: MediaQuery.of(context).size.width * 0.18,
              child: Transform.rotate(
                angle: 0.1, 
                child: Text(
                  'LINK',
                  style: TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: Colors.redAccent,
                    letterSpacing: -4,
                    shadows: [
                      Shadow(color: Colors.redAccent.withValues(alpha: 0.7), blurRadius: 20),
                      const Shadow(color: Colors.orangeAccent, blurRadius: 5),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bgColor = themeProvider.backgroundColor;
    final bool isLight = bgColor.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;
    final Color cardColor = isLight ? Colors.black.withValues(alpha: 0.05) : const Color(0xFF1E1E24);
    
    final bool isPt = themeProvider.cardLanguage == 'pt';

    final List<Map<String, dynamic>> newsList = [
      {
        "image": "assets/images/banned.jpg", 
        "tag": isPt ? "DESTAQUE" : "FEATURED", 
        "title": isPt ? "Anúncio de Banidas\ne Restritas" : "Banned and Restricted\nAnnouncement", 
        "tagColor": const Color(0xFF3B82F6),
        "url": "https://magic.wizards.com/en/news/announcements/banned-and-restricted-announcement-2024"
      },
      {
        "image": "assets/images/mh3.jpg", 
        "tag": "SPOILERS", 
        "title": isPt ? "Prévias de Cartas\nModern Horizons 3" : "Modern Horizons 3\nCard Previews", 
        "tagColor": const Color(0xFF8B5CF6),
        "url": "https://magic.wizards.com/en/news/card-image-gallery/modern-horizons-3"
      },
      {
        "image": "assets/images/arena.jpg", 
        "tag": isPt ? "EVENTOS" : "EVENTS", 
        "title": isPt ? "Arena Open:\nGanhe \$2,000" : "Arena Open:\nWin \$2,000", 
        "tagColor": const Color(0xFF10B981),
        "url": "https://magic.wizards.com/en/mtgarena"
      },
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgColor,
      drawer: _buildDrawer(context, bgColor, textColor, isLight, isPt),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(context, cardColor, textColor, isPt),
                const SizedBox(height: 10),
                
                _buildVersusLogo(textColor),
                
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyDecksScreen())),
                        child: _buildMenuCard(context, cardColor, textColor, icon: Icons.layers, title: isPt ? "MEUS DECKS" : "MY DECKS", glowColor: Colors.blue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CardSearchScreen())),
                        child: _buildMenuCard(context, cardColor, textColor, icon: Icons.search, title: isPt ? "BUSCAR CARTAS" : "SEARCH CARDS", glowColor: Colors.purple),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                _buildLifeCounterCard(context, cardColor, textColor, isPt),
                
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(child: _buildMenuCard(context, cardColor, textColor, icon: Icons.auto_awesome, title: isPt ? "MISSÕES ARENA" : "ARENA DAILIES", glowColor: Colors.green)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMenuCard(context, cardColor, textColor, icon: Icons.monetization_on, title: isPt ? "PREÇOS DE HOJE" : "TODAY'S PRICES", glowColor: Colors.amber)),
                  ],
                ),
                
                const SizedBox(height: 30),

                _buildNewsCarousel(newsList),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Color cardColor, Color textColor, bool isPt) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          child: const CircleAvatar(radius: 22, backgroundColor: Color(0xFF7B4BFF)),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isPt ? "Nív. 47" : "Lvl. 47", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          const Row(children: [Icon(Icons.shield, color: Colors.blue, size: 14), SizedBox(width: 4), Icon(Icons.flash_on, color: Colors.red, size: 14)]),
        ]),
        const Spacer(),
        Container(
          width: 130, height: 40,
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
          child: Icon(Icons.search, color: textColor.withValues(alpha: 0.5)),
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
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index % newsList.length;
              });
            },
            itemBuilder: (context, index) {
              final item = newsList[index % newsList.length];
              return GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => NewsWebScreen(url: item["url"], title: item["tag"])));
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: AssetImage(item["image"]), 
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.darken),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end, 
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: item["tagColor"], borderRadius: BorderRadius.circular(4)),
                          child: Text(item["tag"], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
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
          children: List.generate(newsList.length, (index) {
            return Container(
              width: 8, height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(shape: BoxShape.circle, color: _currentIndex == index ? Colors.blue : Colors.grey.withValues(alpha: 0.5)),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildMenuCard(BuildContext context, Color cardColor, Color textColor, {required IconData icon, required String title, required Color glowColor}) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: glowColor.withValues(alpha: 0.15), blurRadius: 10)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 30),
            Text(title, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildLifeCounterCard(BuildContext context, Color cardColor, Color textColor, bool isPt) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LifeCounterScreen())),
        child: Container(
          height: 80,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: cardColor, 
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.redAccent.withValues(alpha: 0.1), blurRadius: 8)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite, color: Colors.redAccent),
              const SizedBox(width: 12),
              Text(isPt ? "CONTADOR DE VIDA" : "LIFE COUNTER", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, Color bgColor, Color textColor, bool isLight, bool isPt) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Drawer(
      backgroundColor: bgColor,
      child: ListView(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.black26),
            accountName: Text(themeProvider.playerName, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            accountEmail: Text(isPt ? "Nível 47" : "Level 47", style: TextStyle(color: textColor.withValues(alpha: 0.6))),
            currentAccountPicture: const CircleAvatar(backgroundColor: Color(0xFF7B4BFF)),
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