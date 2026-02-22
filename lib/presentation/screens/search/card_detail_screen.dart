import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:audioplayers/audioplayers.dart'; 
import 'package:cached_network_image/cached_network_image.dart'; 
import '../../../data/providers/deck_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/repositories/card_repository.dart';

class CardDetailScreen extends StatefulWidget {
  final Map<String, dynamic> card;
  final int? targetDeckIndex; 

  const CardDetailScreen({super.key, required this.card, this.targetDeckIndex});

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _currentAngle = 0.0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  late Map<String, dynamic> _currentCard;
  final CardRepository _repository = CardRepository(); 

  final Map<String, String> _imageHeaders = {
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
    super.dispose();
  }

  // --- Função Mágica Anti-CORS (Inteligente) ---
  String _getSafeUrl(String url) {
    if (!kIsWeb || url.isEmpty || url.contains('wikimedia')) return url;
    
    // MÁGICA: Se a tela anterior (ex: Comunidade) já colocou um proxy,
    // nós NÃO colocamos outro proxy por cima, senão a imagem quebra (Erro 0)!
    if (url.contains('allorigins') || url.contains('wsrv') || url.contains('corsproxy')) {
      return url;
    }

    // Se for um link limpo da Scryfall, aplicamos o proxy padrão
    return 'https://wsrv.nl/?url=${Uri.encodeComponent(url)}';
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() => _currentAngle += details.delta.dx / 100);
  }

  void _onPanEnd(DragEndDetails details) {
    double velocity = details.velocity.pixelsPerSecond.dx; 
    if (velocity.abs() > 1500) _audioPlayer.play(AssetSource('sounds/spin.mp3'));

    double inertia = velocity / 300; 
    double predictedAngle = _currentAngle + inertia;
    double targetAngle = (predictedAngle / math.pi).round() * math.pi;
    
    int duration = (inertia.abs() * 200).toInt().clamp(300, 1200);

    _controller.duration = Duration(milliseconds: duration);
    _animation = Tween<double>(begin: _currentAngle, end: targetAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)
    );
    _controller.forward(from: 0.0);
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toString().toLowerCase()) {
      case 'uncommon': return const Color(0xFFB0B0B0);
      case 'rare': return const Color(0xFFC1A058);
      case 'mythic': return const Color(0xFFD45E18);
      default: return Colors.white54; 
    }
  }

  Widget _renderManaCost(String manaCost, {double size = 20}) {
    if (manaCost.isEmpty) return const SizedBox.shrink();
    
    final regex = RegExp(r'\{(.*?)\}');
    final matches = regex.allMatches(manaCost);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: matches.map((m) {
        final symbol = m.group(1)!.replaceAll('/', ''); 
        return Container(
          margin: const EdgeInsets.only(left: 2),
          width: size,
          height: size,
          child: SvgPicture.network(
            "https://svgs.scryfall.io/card-symbols/$symbol.svg",
            // Na web não enviamos headers para evitar que o navegador bloqueie o SVG
            headers: kIsWeb ? null : _imageHeaders,
            placeholderBuilder: (context) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      }).toList(),
    );
  }

  void _showVersionsModal(Color bgColor, Color textColor, bool isPt, String initialLang) {
    String modalLang = initialLang;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return FractionallySizedBox(
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
                      Text(isPt ? "Outras Versões" : "Other Versions", style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        value: modalLang,
                        dropdownColor: bgColor,
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.blueAccent),
                        items: const [
                          DropdownMenuItem(value: 'pt', child: Text('PT-BR')),
                          DropdownMenuItem(value: 'en', child: Text('EN-US')),
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
                      if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Nada encontrado."));
                      
                      final versions = snapshot.data!;
                      return PageView.builder(
                        controller: PageController(viewportFraction: 0.70), 
                        itemCount: versions.length,
                        itemBuilder: (context, index) {
                          final vCard = versions[index];
                          final String rawUrl = vCard['imageUrl'] ?? '';
                          final String safeUrl = _getSafeUrl(rawUrl);

                          return Center(
                            child: AspectRatio(
                              aspectRatio: 0.71,
                              child: GestureDetector(
                                onTap: () { setState(() => _currentCard = vCard); Navigator.pop(ctx); },
                                child: Container(
                                  margin: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16), 
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10)]
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16), 
                                    child: CachedNetworkImage(
                                      imageUrl: safeUrl, 
                                      httpHeaders: kIsWeb ? null : _imageHeaders,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                      errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                                    )
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  void _handleAutoAdd(DeckProvider provider, bool isPt) {
    final allDecks = provider.allDecks;
    if (widget.targetDeckIndex != null && widget.targetDeckIndex! < allDecks.length) { _confirmAndAdd(provider, widget.targetDeckIndex!, isPt); return; }
    if (allDecks.length == 1) { _confirmAndAdd(provider, 0, isPt); return; }
    _showDeckPicker(_currentCard, provider, isPt);
  }

  void _confirmAndAdd(DeckProvider provider, int index, bool isPt) {
    final deckName = provider.allDecks[index].name;
    provider.addCardToDeck(index, _currentCard); 
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isPt ? "${_currentCard['name']} adicionado ao deck $deckName!" : "${_currentCard['name']} added to $deckName!"), backgroundColor: Colors.green[700], behavior: SnackBarBehavior.floating));
  }

  void _showDeckPicker(Map<String, dynamic> card, DeckProvider provider, bool isPt) {
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF1E1E24), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isPt ? "Escolha um Deck" : "Choose a Deck", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Flexible(child: ListView.builder(shrinkWrap: true, itemCount: provider.allDecks.length, itemBuilder: (context, index) {
              return ListTile(
                leading: const Icon(Icons.style, color: Colors.blueAccent),
                title: Text(provider.allDecks[index].name, style: const TextStyle(color: Colors.white)),
                onTap: () { _confirmAndAdd(provider, index, isPt); Navigator.pop(ctx); },
              );
            })),
          ],
        ),
      ),
    );
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

    // Aplica o proxy seguro na imagem principal da carta
    final String mainCardSafeUrl = _getSafeUrl(_currentCard['imageUrl'] ?? '');

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: textColor),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(_currentCard['name'] ?? '', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            Text("#${_currentCard['collectorNumber'] ?? ''}", style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 14)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: GestureDetector(
                  onPanUpdate: _onPanUpdate, onPanEnd: _onPanEnd,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.75,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16), 
                      boxShadow: [BoxShadow(color: rarityColor.withValues(alpha: 0.6), blurRadius: 40, spreadRadius: 5)]
                    ),
                    child: AspectRatio(
                      aspectRatio: 0.71, 
                      child: Transform(
                        transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(_currentAngle), 
                        alignment: FractionalOffset.center,
                        child: isFrontVisible
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16), 
                                child: CachedNetworkImage(
                                  imageUrl: mainCardSafeUrl, 
                                  httpHeaders: kIsWeb ? null : _imageHeaders,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey, size: 50),
                                )
                              )
                            : Transform(
                                transform: Matrix4.identity()..rotateY(math.pi), 
                                alignment: FractionalOffset.center, 
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16), 
                                  child: Image.asset('assets/images/traseira_carta.jpg', fit: BoxFit.cover)
                                )
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Container(
              margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: cardContainerColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _renderManaCost(_currentCard['mana_cost'] ?? '', size: 22),
                      if (_currentCard['power'] != null) Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1), 
                          borderRadius: BorderRadius.circular(8)
                        ), 
                        child: Text(
                          "${_currentCard['power']}/${_currentCard['toughness']}", 
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)
                        )
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_currentCard['type_line'] ?? (isPt ? 'Tipo desconhecido' : 'Unknown type'), style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  _buildDivider(textColor),

                  if (_currentCard['oracle_text'] != null && _currentCard['oracle_text'].isNotEmpty) ...[
                    Text(isPt ? "HABILIDADES" : "ABILITIES", style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_currentCard['oracle_text'], style: TextStyle(color: textColor, fontSize: 14, height: 1.5)),
                    _buildDivider(textColor),
                  ],

                  _buildIconRow(isPt ? "Cores" : "Color Identity", _currentCard['color_identity'] ?? 'C'),
                  
                  _buildInfoRow(isPt ? "Raridade" : "Rarity", _currentCard['rarity']?.toString().toUpperCase() ?? 'COMMON', rarityColor, isBold: true),
                  _buildInfoRow(isPt ? "Coleção" : "Set", _currentCard['setName']?.toString().toUpperCase() ?? '', Colors.purpleAccent),
                  
                  const SizedBox(height: 16),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.style, color: Colors.blueAccent),
                    onPressed: () => _showVersionsModal(bgColor, textColor, isPt, themeProvider.cardLanguage),
                    label: Text(isPt ? "VER OUTRAS ARTES / VERSÕES" : "VIEW OTHER ARTS / VERSIONS", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                  ),

                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    icon: const Icon(Icons.add_box_rounded, color: Colors.white),
                    label: Text(isPt ? "ADICIONAR AO DECK" : "ADD TO DECK", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: () => _handleAutoAdd(deckProvider, isPt),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconRow(String label, String identity) {
    final List<String> symbols = identity.split('');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          Row(
            children: symbols.map((s) => Container(
              margin: const EdgeInsets.only(left: 4),
              width: 18,
              height: 18,
              child: SvgPicture.network(
                "https://svgs.scryfall.io/card-symbols/$s.svg",
                headers: kIsWeb ? null : _imageHeaders,
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          Flexible(child: Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w500), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildDivider(Color textColor) => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(color: textColor.withValues(alpha: 0.1), height: 1));
}