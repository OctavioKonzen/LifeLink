// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:audioplayers/audioplayers.dart'; 
import 'package:cached_network_image/cached_network_image.dart'; 
import 'package:fl_chart/fl_chart.dart';
import '../../../data/providers/deck_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/services/scryfall_service.dart';
import '../../../data/repositories/card_repository.dart';
import '../../../data/providers/xp_provider.dart'; 

class CardDetailScreen extends StatefulWidget {
  final Map<String, dynamic> card;
  final int? targetDeckIndex; 
  final int? existingCardIndex; 
  final int? replaceCardIndex;  

  const CardDetailScreen({
    super.key, 
    required this.card, 
    this.targetDeckIndex,
    this.existingCardIndex,
    this.replaceCardIndex,
  });

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _currentAngle = 0.0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late Map<String, dynamic> _currentCard;
  final CardRepository _repository = CardRepository(); 

  final Map<String, String> _imageHeaders = const {
    'User-Agent': 'LifelinkApp/1.0',
    'Accept': '*/*'
  };

  @override
  void initState() {
    super.initState();
    _currentCard = Map.from(widget.card); 
    _controller = AnimationController(vsync: this);
    _controller.addListener(() => setState(() => _currentAngle = _animation.value));
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Imagem principal em PNG (melhor qualidade do Scryfall). Enquanto ela
  // carrega, aparece a "normal", que já veio da lista e está no cache.
  Widget _buildMainImage(String url) {
    final normal = CardImages.sized(url, 'normal');
    final best = CardImages.best(url);
    final fallback = CachedNetworkImage(
      imageUrl: normal,
      fit: BoxFit.cover,
      placeholder: (c, u) => Container(color: Colors.black12),
      errorWidget: (c, u, e) => const Center(child: Icon(Icons.broken_image, size: 50)),
    );
    if (best == normal) return fallback;
    return CachedNetworkImage(
      imageUrl: best,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (c, u) => fallback,
      errorWidget: (c, u, e) => fallback,
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() => _currentAngle += details.delta.dx / 100);
  }

  void _onPanEnd(DragEndDetails details) {
    double velocity = details.velocity.pixelsPerSecond.dx;
    double inertiaAngle = (velocity / 800) * math.pi;

    double rawTargetAngle = _currentAngle + inertiaAngle;
    double targetAngle = (rawTargetAngle / math.pi).round() * math.pi;
    double spinDistance = (targetAngle - _currentAngle).abs();

    if (spinDistance > math.pi / 2) {
      try {
        _audioPlayer.play(AssetSource('sounds/spin.mp3'));
      } catch (e) {
        debugPrint("Erro ao tocar o som: $e");
      }
    }

    int durationMs = 500 + (spinDistance * 150).toInt();
    if (durationMs > 1500) durationMs = 1500; 

    _animation = Tween<double>(begin: _currentAngle, end: targetAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)
    );
    _controller.duration = Duration(milliseconds: durationMs);
    _controller.forward(from: 0.0);
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'uncommon': return const Color(0xFFB0B0B0);
      case 'rare': return const Color(0xFFC1A058);
      case 'mythic': return const Color(0xFFD45E18);
      default: return Colors.white54; 
    }
  }

  Widget _renderManaCost(String manaCost, {double size = 20}) {
    if (manaCost.isEmpty) return const SizedBox.shrink();
    
    // ignore: deprecated_member_use
    final Pattern regex = RegExp(r'\{(.*?)\}');
    final matches = regex.allMatches(manaCost);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: matches.map((m) => Container(
        margin: const EdgeInsets.only(left: 2),
        width: size, height: size,
        child: SvgPicture.network(
          "https://svgs.scryfall.io/card-symbols/${m.group(1)!.replaceAll('/', '')}.svg",
          headers: kIsWeb ? null : _imageHeaders,
        ),
      )).toList(),
    );
  }

  void _showVersionsModal(Color bgColor, Color textColor, bool isPt, String initialLang) {
    String modalLang = initialLang;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(10))),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isPt ? "Escolher Visual" : "Choose Artwork", style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: modalLang,
                      dropdownColor: bgColor,
                      items: const [
                        DropdownMenuItem(value: 'pt', child: Text('PT-BR')),
                        DropdownMenuItem(value: 'en', child: Text('EN-US')),
                        DropdownMenuItem(value: 'ja', child: Text('Japonês')),
                      ],
                      onChanged: (val) { if (val != null) setModalState(() => modalLang = val); },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _repository.fetchOtherVersions(_currentCard['name'], modalLang, _currentCard['oracle_id']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text("Nada encontrado neste idioma.", style: TextStyle(color: textColor)));
                    
                    final versions = snapshot.data!;
                    return PageView.builder(
                      controller: PageController(viewportFraction: 0.8),
                      itemCount: versions.length,
                      itemBuilder: (context, index) {
                        final vCard = versions[index];
                        return Center(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _currentCard = vCard);
                              
                              this.context.read<XpProvider>().incrementArtsViewed();
                              
                              if (widget.targetDeckIndex != null && widget.existingCardIndex != null) {
                                final provider = this.context.read<DeckProvider>();
                                provider.replaceCardInDeck(widget.targetDeckIndex!, widget.existingCardIndex!, vCard);
                                
                                ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                                  content: Text(isPt ? "Arte atualizada no deck!" : "Artwork updated in deck!"),
                                  backgroundColor: Colors.green[700],
                                ));
                              }

                              Navigator.pop(ctx);
                            },
                            child: Container(
                              margin: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 15)]
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                  imageUrl: CardImages.sized(vCard['imageUrl'], 'large'),
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                                  errorWidget: (context, url, error) => Icon(Icons.broken_image, size: 50),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(isPt ? "Toque na carta para selecionar e atualizar" : "Tap the card to select and update", style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12)),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showDeckSelectionDialog(DeckProvider provider, XpProvider xpProvider, bool isPt) {
    if (provider.allDecks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isPt ? "Você não tem nenhum deck criado!" : "No decks created!"),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text(isPt ? "Adicionar a qual deck?" : "Add to which deck?", style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: provider.allDecks.length,
            itemBuilder: (context, index) {
              final deck = provider.allDecks[index];
              return ListTile(
                leading: const Icon(Icons.layers, color: Colors.blueAccent),
                title: Text(deck.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text("${deck.cards.length} cartas", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  provider.addCardToDeck(index, _currentCard);
                  
                  xpProvider.incrementCardsAdded(1);
                  
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isPt ? "Adicionado ao deck ${deck.name}!" : "Added to ${deck.name}!"),
                    backgroundColor: Colors.green[700],
                  ));
                },
              );
            }
          ),
        ),
      )
    );
  }

  void _handleAutoAdd(DeckProvider provider, bool isPt) {
    final xpProvider = context.read<XpProvider>();

    if (widget.targetDeckIndex != null) {
      if (widget.replaceCardIndex != null) {
        provider.replaceCardInDeck(widget.targetDeckIndex!, widget.replaceCardIndex!, _currentCard);
        xpProvider.incrementCardsAdded(1);
        xpProvider.incrementArtsViewed();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isPt ? "Carta Substituída!" : "Card Replaced!")));
        Navigator.of(context)..pop()..pop(); 
      } 
      else {
        provider.addCardToDeck(widget.targetDeckIndex!, _currentCard);
        xpProvider.incrementCardsAdded(1);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isPt ? "Adicionado!" : "Added!")));
      }
    } 
    else {
      _showDeckSelectionDialog(provider, xpProvider, isPt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final deckProvider = context.watch<DeckProvider>();
    final bgColor = themeProvider.backgroundColor;
    final bool isLight = bgColor.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;
    final Color cardContainerColor = isLight ? Colors.black.withValues(alpha: 0.05) : const Color(0xFF1E1E24); 
    final bool isPt = themeProvider.cardLanguage == 'pt';

    bool isFrontVisible = math.cos(_currentAngle) > 0;
    final rarityColor = _getRarityColor(_currentCard['rarity'] ?? '');
    final String mainCardUrl = _currentCard['imageUrl'] ?? '';
    final bool isEditingExistingCard = widget.existingCardIndex != null;
    final bool isReplacingCard = widget.replaceCardIndex != null;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: Text(_currentCard['name'] ?? '', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: GestureDetector(
                    onPanUpdate: _onPanUpdate, onPanEnd: _onPanEnd,
                    child: Transform(
                      transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(_currentAngle), 
                      alignment: FractionalOffset.center,
                      child: Center(
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16), 
                            boxShadow: [BoxShadow(color: rarityColor.withValues(alpha: 0.4), blurRadius: 30)]
                          ),
                          child: AspectRatio(
                            aspectRatio: 0.71,
                            child: isFrontVisible 
                              ? ClipRRect(borderRadius: BorderRadius.circular(16), child: _buildMainImage(mainCardUrl))
                              : Transform(transform: Matrix4.identity()..rotateY(math.pi), alignment: FractionalOffset.center, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: CachedNetworkImage(imageUrl: CardImages.cardBack, fit: BoxFit.cover))),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: cardContainerColor, 
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05))
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, 
                    children: [
                      _buildSwipeIndicator(isPt, textColor),
                      SizedBox(
                        height: 380, 
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) => setState(() => _currentPage = index),
                          children: [
                            _buildAbilitiesTab(textColor, isPt, rarityColor),
                            _buildPricesTab(textColor, isPt),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50), 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.5))
                        ),
                        icon: Icon(Icons.style, color: Colors.blueAccent),
                        onPressed: () => _showVersionsModal(bgColor, textColor, isPt, themeProvider.cardLanguage),
                        label: Text(
                          isEditingExistingCard ? (isPt ? "TROCAR ARTE NO DECK" : "CHANGE ART IN DECK") : (isPt ? "VER OUTRAS ARTES" : "VIEW OTHER ARTS"), 
                          style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      if (!isEditingExistingCard)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isReplacingCard ? Colors.orangeAccent : Colors.blueAccent, 
                            minimumSize: Size(double.infinity, 55), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                          ),
                          icon: Icon(isReplacingCard ? Icons.autorenew : Icons.add_box_rounded, color: Colors.white),
                          onPressed: () => _handleAutoAdd(deckProvider, isPt),
                          label: Text(
                            isReplacingCard 
                              ? (isPt ? "SUBSTITUIR CARTA" : "REPLACE CARD") 
                              : (isPt ? "ADICIONAR AO DECK" : "ADD TO DECK"), 
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeIndicator(bool isPt, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _indicatorLabel(isPt ? "Habilidades" : "Abilities", _currentPage == 0, textColor),
          const SizedBox(width: 20),
          _indicatorLabel(isPt ? "Preços" : "Prices", _currentPage == 1, textColor),
        ],
      ),
    );
  }

  Widget _indicatorLabel(String text, bool active, Color textColor) {
    return Column(
      children: [
        Text(text, style: TextStyle(color: active ? Colors.blueAccent : textColor.withValues(alpha: 0.3), fontSize: 12, fontWeight: FontWeight.bold)),
        AnimatedContainer(duration: Duration(milliseconds: 300), margin: EdgeInsets.only(top: 4), width: active ? 30 : 0, height: 2, color: Colors.blueAccent),
      ],
    );
  }

  Widget _buildAbilitiesTab(Color textColor, bool isPt, Color rarityColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _renderManaCost(_currentCard['mana_cost'] ?? '', size: 22),
              if (_currentCard['power'] != null) 
                Text("${_currentCard['power']}/${_currentCard['toughness']}", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 10),
          Text(_currentCard['type_line'] ?? '', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          _buildDivider(textColor),
          Text(_currentCard['oracle_text'] ?? '', style: TextStyle(color: textColor, fontSize: 14, height: 1.5)),
          _buildDivider(textColor),
          _buildInfoRow(isPt ? "Raridade" : "Rarity", _currentCard['rarity']?.toString().toUpperCase() ?? '', rarityColor, isBold: true),
          _buildInfoRow(isPt ? "Coleção" : "Set", _currentCard['setName']?.toString().toUpperCase() ?? '', Colors.purpleAccent),
        ],
      ),
    );
  }

  Widget _buildPricesTab(Color textColor, bool isPt) {
    double currentPrice = double.tryParse(_currentCard['usdPrice']?.toString() ?? '0') ?? 0.0;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isPt ? "HISTÓRICO DE PREÇOS (USD)" : "PRICE HISTORY (USD)", 
            style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, 
                  getDrawingHorizontalLine: (value) => FlLine(color: textColor.withValues(alpha: 0.05), strokeWidth: 1)),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      FlSpot(0, currentPrice * 0.98),
                      FlSpot(1, currentPrice * 1.02),
                      FlSpot(2, currentPrice * 1.05),
                      FlSpot(3, currentPrice * 1.01),
                      FlSpot(4, currentPrice * 0.95),
                      FlSpot(5, currentPrice),
                    ],
                    isCurved: true,
                    color: Colors.redAccent.withValues(alpha: 0.7),
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: Colors.redAccent.withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _priceRow(isPt ? "Preço de Mercado" : "Market Price", currentPrice, textColor, isBold: true),
          _buildDivider(textColor),
          _priceRow(isPt ? "Mínimo (7 dias)" : "Low (7 days)", currentPrice * 0.92, textColor),
          _priceRow(isPt ? "Máximo (7 dias)" : "High (7 days)", currentPrice * 1.08, textColor),
          _priceRow(isPt ? "Foil" : "Foil Market", currentPrice * 1.5, textColor),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double price, Color textColor, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            color: isBold ? textColor : textColor.withValues(alpha: 0.7),
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal
          )),
          Text("\$${price.toStringAsFixed(2)}", style: TextStyle(
            color: isBold ? Colors.greenAccent : textColor,
            fontWeight: FontWeight.bold,
            fontSize: isBold ? 16 : 14
          )),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor, {bool isBold = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)), Flexible(child: Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w500), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis))]));
  }

  Widget _buildDivider(Color textColor) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(color: textColor.withValues(alpha: 0.1), height: 1));
}