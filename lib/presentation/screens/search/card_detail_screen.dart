// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../data/services/deck_tools.dart';
import '../../../data/services/lifelink_cards.dart';
import 'package:flutter/foundation.dart'; 
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:audioplayers/audioplayers.dart'; 
import 'package:cached_network_image/cached_network_image.dart'; 
import '../../../data/providers/deck_provider.dart';
import '../../../data/providers/collection_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/services/scryfall_service.dart';
import '../../../data/repositories/card_repository.dart';
import '../../../data/providers/xp_provider.dart'; 

/// Raridade em português (a Scryfall manda em inglês).
String rarityPt(String? rarity) => switch (rarity?.toLowerCase()) {
      'common' => 'Comum',
      'uncommon' => 'Incomum',
      'rare' => 'Rara',
      'mythic' => 'Mítica',
      'special' => 'Especial',
      'bonus' => 'Bônus',
      null || '' => '',
      _ => rarity!,
    };

class CardDetailScreen extends StatefulWidget {
  final Map<String, dynamic> card;
  final String? targetDeckId;
  final int? existingCardIndex; 
  final int? replaceCardIndex;  

  const CardDetailScreen({
    super.key, 
    required this.card, 
    this.targetDeckId,
    this.existingCardIndex,
    this.replaceCardIndex,
  });

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> with SingleTickerProviderStateMixin {
  /// A posição atual do deck de destino (pelo id), ou null.
  int? get _targetDeckIndex {
    final id = widget.targetDeckId;
    if (id == null) return null;
    final i = context.read<DeckProvider>().indexOfId(id);
    return i < 0 ? null : i;
  }

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

  // A carta completa da Scryfall (legalidade, ambientação, artista) e o dólar em reais.
  Map<String, dynamic>? _full;
  double? _brl;

  Future<void> _loadFull() async {
    final id = DeckTools.scryfallIdOf(_currentCard);
    if (id == null) return;
    // A carta do banco do LifeLink (R2): detalhes, preços de hoje e o que
    // faltar na carta (a busca traz só o resumo).
    final lang = context.read<ThemeProvider>().cardLanguage;
    try {
      final found = await LifeLinkCards.instance.byPrint(id);
      if (found != null) {
        final sets = await LifeLinkCards.instance.sets().catchError((_) => <String, String>{});
        final app = LifeLinkCards.toApp({...found.card, '_sets': sets}, found.variation, lang: lang);
        if (mounted && DeckTools.scryfallIdOf(_currentCard) == id) {
          setState(() {
            _full = LifeLinkCards.details(found.card, found.variation);
            _currentCard = {
              ..._currentCard,
              for (final e in app.entries)
                if (_currentCard[e.key] == null || '${_currentCard[e.key]}'.isEmpty || const {'usdPrice', 'usdFoil', 'eurPrice', 'tixPrice', 'setName'}.contains(e.key)) e.key: e.value,
            };
          });
        }
        await _loadRulings(id);
        return;
      }
    } catch (_) {}
    try {
      final data = await ScryfallService.instance.getJson('https://api.scryfall.com/cards/$id');
      if (mounted && DeckTools.scryfallIdOf(_currentCard) == id) setState(() => _full = data);
      // As regras oficiais sobre a carta (rulings), da Wizards e da Scryfall.
      final uri = data['rulings_uri'];
      if (uri is String) {
        final r = await ScryfallService.instance.getJson(uri);
        final list = [for (final x in (r['data'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
        if (mounted && DeckTools.scryfallIdOf(_currentCard) == id) setState(() => _rulings = list);
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>>? _rulings;

  /// As regras oficiais da carta (rulings). Elas não estão no banco do
  /// LifeLink: vêm da Scryfall, só o texto.
  Future<void> _loadRulings(String id) async {
    try {
      final r = await ScryfallService.instance.getJson('https://api.scryfall.com/cards/$id/rulings');
      final list = [for (final x in (r['data'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
      if (mounted && DeckTools.scryfallIdOf(_currentCard) == id) setState(() => _rulings = list);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _currentCard = Map.from(widget.card);
    _loadFull();
    DeckTools.dollarInReais().then((v) {
      if (mounted) setState(() => _brl = v);
    });
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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Escolher Visual", style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
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
                              // Ver outra arte vale XP (a mesma carta de novo, não).
                              if (vCard['imageUrl'] != _currentCard['imageUrl']) this.context.read<XpProvider>().incrementArtsViewed();
                              setState(() {
                                _currentCard = vCard;
                                _full = null;
                              });
                              _loadFull();
                              
                              if (_targetDeckIndex != null && widget.existingCardIndex != null) {
                                final provider = this.context.read<DeckProvider>();
                                provider.replaceCardInDeck(_targetDeckIndex!, widget.existingCardIndex!, vCard);
                                
                                ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                                  content: Text("Arte atualizada no deck!"),
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
                child: Text("Toque na carta para selecionar e atualizar", style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12)),
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
        content: Text("Você não tem nenhum deck criado!"),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text("Adicionar a qual deck?", style: TextStyle(color: Colors.white)),
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
                    content: Text("Adicionado ao deck ${deck.name}!"),
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

    if (_targetDeckIndex != null) {
      if (widget.replaceCardIndex != null) {
        provider.replaceCardInDeck(_targetDeckIndex!, widget.replaceCardIndex!, _currentCard);
        xpProvider.incrementCardsAdded(1);
        xpProvider.incrementArtsViewed();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Carta Substituída!")));
        Navigator.of(context)..pop()..pop(); 
      } 
      else {
        provider.addCardToDeck(_targetDeckIndex!, _currentCard);
        xpProvider.incrementCardsAdded(1);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Adicionado!")));
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
    final bool isPt = themeProvider.cardLanguage == 'pt';

    bool isFrontVisible = math.cos(_currentAngle) > 0;
    final rarityColor = _getRarityColor(_currentCard['rarity'] ?? '');
    final String mainCardUrl = _currentCard['imageUrl'] ?? '';
    final bool isEditingExistingCard = widget.existingCardIndex != null;
    final bool isReplacingCard = widget.replaceCardIndex != null;

    final media = MediaQuery.of(context);
    // Como no Pocketdex: a carta fica parada em cima (arrastar para o lado a
    // vira) e o painel de baixo tem altura fixa; as abas trocam arrastando
    // para o lado e só o conteúdo de cada aba rola.
    final panelHeight = media.size.height * 0.5;
    final panelColor = isLight ? Colors.white : const Color(0xFF16161B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: textColor, actions: [
        // Coleção (+1 cópia; segurar tira uma) e lista de desejos (coração).
        Builder(builder: (context) {
          final collection = context.watch<CollectionProvider>();
          final id = DeckTools.scryfallIdOf(_currentCard) ?? '${_currentCard['id']}';
          final qty = collection.qtyOf(id);
          return Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onLongPress: qty == 0 ? null : () => collection.setQty(id, qty - 1),
              child: IconButton(
                tooltip: 'Guardar na coleção (segure para tirar uma)',
                onPressed: () {
                  final n = collection.add(_currentCard);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 2), content: Text(n == 0 ? 'A coleção está cheia.' : 'Na coleção: $n')));
                },
                icon: Badge(
                  isLabelVisible: qty > 0,
                  label: Text('$qty'),
                  child: Icon(qty > 0 ? Icons.inventory_2 : Icons.inventory_2_outlined),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Lista de desejos',
              onPressed: () => collection.toggleWish(_currentCard),
              icon: Icon(collection.wished(id) ? Icons.favorite : Icons.favorite_border, color: collection.wished(id) ? Colors.pinkAccent : null),
            ),
          ]);
        }),
      ]),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              // A carta do maior tamanho que couber no espaço de cima.
              final width = math.min(box.maxWidth * 0.78, (box.maxHeight - 16) * 0.71);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Center(
                  child: Transform(
                    transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(_currentAngle),
                    alignment: FractionalOffset.center,
                    child: Container(
                      width: width,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: rarityColor.withValues(alpha: 0.4), blurRadius: 30)],
                      ),
                      child: AspectRatio(
                        aspectRatio: 0.71,
                        child: isFrontVisible
                            ? ClipRRect(borderRadius: BorderRadius.circular(16), child: _buildMainImage(mainCardUrl))
                            : Transform(
                                transform: Matrix4.identity()..rotateY(math.pi),
                                alignment: FractionalOffset.center,
                                // Carta de duas faces: o outro lado; senão, o verso padrão.
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: CachedNetworkImage(
                                    imageUrl: '${_currentCard['backImageUrl'] ?? ''}'.isNotEmpty ? '${_currentCard['backImageUrl']}' : CardImages.cardBack,
                                    httpHeaders: CardImages.headers,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) => CachedNetworkImage(imageUrl: CardImages.cardBack, fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          Container(
            height: panelHeight,
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))],
            ),
            padding: EdgeInsets.only(top: 18, bottom: media.padding.bottom + 12),
            child: Column(
              children: [
                _buildSwipeIndicator(isPt, textColor),
                const SizedBox(height: 8),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    children: [
                      _buildAbilitiesTab(textColor, isPt, rarityColor),
                      _buildPricesTab(textColor, isPt),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.5)),
                        ),
                        icon: const Icon(Icons.style, color: Colors.blueAccent, size: 20),
                        onPressed: () => _showVersionsModal(bgColor, textColor, isPt, themeProvider.cardLanguage),
                        label: FittedBox(
                          child: Text(
                            isEditingExistingCard ? "TROCAR ARTE" : "OUTRAS ARTES",
                            style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    if (!isEditingExistingCard) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isReplacingCard ? Colors.orangeAccent : Colors.blueAccent,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: Icon(isReplacingCard ? Icons.autorenew : Icons.add_box_rounded, color: Colors.white, size: 20),
                          onPressed: () => _handleAutoAdd(deckProvider, isPt),
                          label: FittedBox(
                            child: Text(
                              isReplacingCard ? "SUBSTITUIR" : "AO DECK",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeIndicator(bool isPt, Color textColor) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _indicatorLabel("Habilidades", _currentPage == 0, textColor, 0),
          const SizedBox(width: 28),
          _indicatorLabel("Preços", _currentPage == 1, textColor, 1),
        ],
      ),
    );
  }

  Widget _indicatorLabel(String text, bool active, Color textColor, int page) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _pageController.animateToPage(page, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
      child: Column(
        children: [
          Text(text,
              style: TextStyle(
                color: active ? textColor : textColor.withValues(alpha: 0.4),
                fontSize: 16,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              )),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(top: 4),
            width: active ? 24 : 0,
            height: 3,
            decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(2)),
          ),
        ],
      ),
    );
  }

  Widget _buildAbilitiesTab(Color textColor, bool isPt, Color rarityColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
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
          if ((_full?['flavor_text'] ?? _full?['card_faces']?[0]?['flavor_text']) != null) ...[
            Text('${_full?['flavor_text'] ?? _full?['card_faces']?[0]?['flavor_text']}',
                style: TextStyle(color: textColor.withValues(alpha: 0.65), fontSize: 13, fontStyle: FontStyle.italic, height: 1.4)),
            _buildDivider(textColor),
          ],
          _buildInfoRow("Raridade", rarityPt(_currentCard['rarity']?.toString()), rarityColor, isBold: true),
          _buildInfoRow("Coleção", _currentCard['setName']?.toString() ?? '', Colors.purpleAccent),
          if (_full?['artist'] != null) _buildInfoRow("Artista", '${_full!['artist']}', textColor),
          if (_full?['legalities'] is Map) ...[
            _buildDivider(textColor),
            Text('Legalidade', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final f in DeckTools.formats.entries)
                () {
                  final status = '${(_full!['legalities'] as Map)[f.key] ?? 'not_legal'}';
                  final (label, color) = switch (status) {
                    'legal' => ('Legal', Colors.green),
                    'restricted' => ('Restrita', Colors.orange),
                    'banned' => ('Banida', Colors.red),
                    _ => ('Não', Colors.grey),
                  };
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.5))),
                    child: Text('${f.value}: $label', style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
                  );
                }(),
            ]),
          ],
          if (_rulings?.isNotEmpty ?? false) ...[
            _buildDivider(textColor),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                iconColor: textColor,
                collapsedIconColor: textColor,
                title: Text('Regras da carta (${_rulings!.length})', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
                subtitle: Text('Esclarecimentos oficiais, em inglês', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                children: [
                  for (final r in _rulings!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_rulingDate('${r['published_at'] ?? ''}'), style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('${r['comment'] ?? ''}', style: TextStyle(color: textColor, fontSize: 13, height: 1.4)),
                      ]),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// "2024-02-02" → "02/02/2024".
  static String _rulingDate(String iso) {
    final p = iso.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
  }

  /// Os preços que o Scryfall informa para esta versão da carta (TCGplayer,
  /// Cardmarket e MTGO, atualizados uma vez por dia).
  Widget _buildPricesTab(Color textColor, bool isPt) {
    double? price(String key) {
      final v = double.tryParse(_currentCard[key]?.toString() ?? '');
      return v != null && v > 0 ? v : null;
    }

    final rows = [
      ("Normal (EUA)", price('usdPrice'), '\$'),
      ("Foil (EUA)", price('usdFoil'), '\$'),
      ("Europa", price('eurPrice'), '€'),
      ("MTGO", price('tixPrice'), 'tix '),
    ].where((r) => r.$2 != null).toList();
    // Em real, pelo dólar de hoje.
    final usd = price('usdPrice') ?? price('usdFoil');
    if (usd != null && _brl != null) rows.insert(1, ("Em real (aprox.)", usd * _brl!, 'R\$ '));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rows.isEmpty)
            Text(
              "Sem preço para esta versão. Tente a versão em inglês em OUTRAS ARTES.",
              style: TextStyle(color: textColor.withValues(alpha: 0.6)),
            )
          else
            for (final (i, r) in rows.indexed) ...[
              if (i > 0) _buildDivider(textColor),
              _priceRow(r.$1, r.$2!, textColor, prefix: r.$3, isBold: i == 0),
            ],
          const SizedBox(height: 12),
          Text(
            "Valores do Scryfall, atualizados uma vez por dia.",
            style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double price, Color textColor, {String prefix = '\$', bool isBold = false}) {
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
          Text("$prefix${price.toStringAsFixed(2)}", style: TextStyle(
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