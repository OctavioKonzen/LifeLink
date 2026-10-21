import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/providers/deck_provider.dart';
import '../../../data/providers/xp_provider.dart';
import '../../../data/services/scryfall_service.dart';
import '../../widgets/neon.dart';

class ArenaMissionsScreen extends StatefulWidget {
  const ArenaMissionsScreen({super.key});

  @override
  State<ArenaMissionsScreen> createState() => _ArenaMissionsScreenState();
}

class _ArenaMissionsScreenState extends State<ArenaMissionsScreen> {

  Map<String, dynamic> _getTierReward(int tier) {
    final List<String> topCards = [
      "Sol Ring", "Black Lotus", "Jace, the Mind Sculptor", "Liliana of the Veil",
      "Elesh Norn, Grand Cenobite", "Atraxa, Praetors' Voice", "Nicol Bolas, the Ravager",
      "Chandra, Torch of Defiance", "Teferi, Hero of Dominaria", "Ulamog, the Ceaseless Hunger",
      "Karn Liberated", "Muldrotha, the Gravetide", "Yuriko, the Tiger's Shadow",
      "Edgar Markov", "Rhystic Study", "Smothering Tithe", "Cyclonic Rift",
      "Doubling Season", "Ghalta, Primal Hunger", "Avacyn, Angel of Hope"
    ];

    bool isTitleTier = (tier % 10 == 0);
    bool isBorderTier = !isTitleTier && (tier % 2 == 0);

    if (isTitleTier) {
      int titleIndex = (tier ~/ 10) - 1;
      if (titleIndex < XpProvider.allTitles.length) {
        String title = XpProvider.allTitles[titleIndex];
        return {'type': 'title', 'value': title, 'name': title};
      }
    } else if (isBorderTier) {
      int borderCount = (tier ~/ 2) - (tier ~/ 10);
      if (borderCount < XpProvider.allBorders.length) {
        final borderData = XpProvider.allBorders[borderCount];
        return {'type': 'border', 'value': borderData['id'], 'name': borderData['name'], 'colors': borderData['colors']};
      }
    }

    int avatarIndex = (tier - 1) % topCards.length;
    String cardName = topCards[avatarIndex];
    String imageUrl = CardImages.artCropByName(cardName);
    
    return {'type': 'avatar', 'value': imageUrl, 'name': cardName, 'imageUrl': imageUrl};
  }

  void _claimMissionXp(XpProvider xpProvider, int index, int xpAmount) {
    xpProvider.addXp(xpAmount);
    xpProvider.claimMission(index);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("+$xpAmount XP Resgatado!"), backgroundColor: Colors.green[700], behavior: SnackBarBehavior.floating));
  }

  void _claimSectionReward(XpProvider xpProvider, int currentTier) {
    final reward = _getTierReward(currentTier);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("SEÇÃO CONCLUÍDA!", style: TextStyle(color: Colors.amberAccent, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 20),
            if (reward['type'] == 'avatar')
              ClipOval(child: CachedNetworkImage(imageUrl: reward['imageUrl'], width: 100, height: 100, fit: BoxFit.cover))
            else if (reward['type'] == 'border')
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: reward['colors'])),
                child: const Center(child: Icon(Icons.shield, color: Colors.white, size: 40)),
              )
            else
              const Icon(Icons.military_tech, size: 80, color: Colors.purpleAccent),
            const SizedBox(height: 20),
            Text("Desbloqueado: ${reward['name']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () {
                xpProvider.unlockReward(reward['type'], reward['value']);
                xpProvider.advanceTier();
                Navigator.pop(ctx);
              },
              child: const Text("PRÓXIMO RANK"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final xpProvider = context.watch<XpProvider>(); 
    final deckProvider = context.watch<DeckProvider>();
    
    final isLight = theme.backgroundColor.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black87 : Colors.white;

    int tier = xpProvider.currentTier;
    // CÁLCULO: Aumenta 1% por nível (1.0 + 0.01 * tier)
    double diffMult = 1.0 + (0.01 * (tier - 1));
    
    String getTitle(List<String> titles) {
      if (tier <= titles.length) return titles[tier - 1];
      return "${titles.last} $tier"; 
    }

    final List<Map<String, dynamic>> currentMissions = [
      {
        'title': getTitle(['Construtor Aprendiz', 'Mestre Forjador']), 
        'desc': 'Crie decks novos.', 
        'icon': Icons.handyman, 
        'target': (5 * diffMult).ceil(), 
        'current': xpProvider.statDecksCreated, // VOLTOU AO NORMAL
        'xp': 100 * tier, 
        'color': Colors.amberAccent
      },
      {
        'title': getTitle(['O Colecionador', 'Acumulador']), 
        'desc': 'Adicione cartas.', 
        'icon': Icons.library_books, 
        'target': (100 * diffMult).ceil(), 
        'current': xpProvider.statCardsAdded, // VOLTOU AO NORMAL
        'xp': 150 * tier, 
        'color': Colors.purpleAccent
      },
      {
        'title': getTitle(['Arquimago', 'Lenda']), 
        'desc': 'Decks na biblioteca.', 
        'icon': Icons.auto_awesome, 
        'target': (5 * diffMult).ceil(), 
        'current': deckProvider.allDecks.length, // VOLTOU AO NORMAL
        'xp': 200 * tier, 
        'color': Colors.blueAccent
      },
      {
        'title': getTitle(['Explorador', 'Viajante']), 
        'desc': 'Pesquise cartas.', 
        'icon': Icons.travel_explore, 
        'target': (50 * diffMult).ceil(), 
        'current': xpProvider.statSearches, // VOLTOU AO NORMAL
        'xp': 100 * tier, 
        'color': Colors.greenAccent
      },
      {
        'title': getTitle(['Estrategista', 'Erudito']), 
        'desc': 'Veja outras artes.', 
        'icon': Icons.psychology, 
        'target': (20 * diffMult).ceil(), 
        'current': xpProvider.statArtsViewed, // VOLTOU AO NORMAL
        'xp': 150 * tier, 
        'color': Colors.redAccent
      },
    ];

    final List<String> claimedList = xpProvider.claimedMissions;
    final int claimedCount = claimedList.where((c) => c == "1").length;
    final double sectionProgress = claimedCount / currentMissions.length;
    final bool isSectionComplete = claimedCount == currentMissions.length;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent, elevation: 0,
            title: Text("Missões · Rank $tier", style: TextStyle(color: textColor)),
          ),
          body: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
                decoration: neonDecoration(AreaColors.missions, neonSurface(context, theme.backgroundColor)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Progresso da Seção", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                        Text("$claimedCount / ${currentMissions.length}", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: sectionProgress, minHeight: 12, backgroundColor: isLight ? Colors.grey[300] : Colors.grey[800], valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent))),
                    const SizedBox(height: 15),
                    if (isSectionComplete)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black87, minimumSize: const Size(double.infinity, 50)),
                        onPressed: () => _claimSectionReward(xpProvider, xpProvider.currentTier),
                        child: const Text("RESGATAR RECOMPENSA MÍTICA!", style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: currentMissions.length,
                  itemBuilder: (context, index) {
                    final ach = currentMissions[index];
                    final bool isGoalMet = ach['current'] >= ach['target'];
                    final bool isClaimed = claimedList[index] == "1"; 
                    final double progress = (ach['current'] / ach['target']).clamp(0.0, 1.0);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(16),
                      decoration: neonDecoration(isGoalMet ? ach['color'] as Color : AreaColors.missions, neonSurface(context, theme.backgroundColor), radius: 16, glow: isGoalMet ? 0.3 : 0.1),
                      child: Row(
                        children: [
                          Icon(ach['icon'], size: 30, color: isGoalMet ? ach['color'] : Colors.grey),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ach['title'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                Text(ach['desc'], style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12)),
                                const SizedBox(height: 10),
                                if (!isClaimed) ...[
                                  LinearProgressIndicator(value: progress, backgroundColor: Colors.black12, valueColor: AlwaysStoppedAnimation(ach['color'])),
                                  const SizedBox(height: 5),
                                  Text("${ach['current']} / ${ach['target']}", style: const TextStyle(fontSize: 10)),
                                ],
                                if (isGoalMet && !isClaimed)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: ElevatedButton(
                                      onPressed: () => _claimMissionXp(xpProvider, index, ach['xp']),
                                      child: Text("RESGATAR ${ach['xp']} XP"),
                                    ),
                                  )
                                else if (isClaimed)
                                  const Text("CONCLUÍDO", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}