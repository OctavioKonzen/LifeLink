import 'dart:async'; // Necessário para o Timer (Debounce)
import 'package:flutter/material.dart';
import '../../../data/services/deck_tools.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/services/scryfall_service.dart';
import '../../../data/repositories/card_repository.dart';
import '../../../data/models/card_model.dart';
import 'card_detail_screen.dart';
import '../../widgets/neon.dart';
import '../../theme/app_theme.dart';

class TodayPricesScreen extends StatefulWidget {
  const TodayPricesScreen({super.key});

  @override
  State<TodayPricesScreen> createState() => _TodayPricesScreenState();
}

class _TodayPricesScreenState extends State<TodayPricesScreen> {
  final CardRepository _repository = CardRepository();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = true;
  List<CardModel> _cards = [];
  List<Map<String, dynamic>> _raw = []; // as cartas como vieram da Scryfall (para abrir completas)
  String? _nextPage;
  bool _loadingMore = false;
  double? _brl; // dólar em reais hoje

  @override
  void initState() {
    super.initState();
    _loadPrices();
    DeckTools.dollarInReais().then((v) {
      if (mounted) setState(() => _brl = v);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  int _requestId = 0; // só a busca mais nova aparece

  /// Carrega as cartas mais caras (com a busca, se tiver).
  Future<void> _loadPrices({String? query}) async {
    if (!mounted) return;
    final id = ++_requestId;
    setState(() => _isLoading = true);

    try {
      final result = await _repository.fetchTrendingPrices(query: query);
      if (mounted && id == _requestId) {
        setState(() {
          _cards = List<CardModel>.from(result['cards']);
          _raw = [for (final c in result['raw'] as List) Map<String, dynamic>.from(c as Map)];
          _nextPage = result['nextPage'] as String?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && id == _requestId) {
        setState(() {
          _cards = [];
          _isLoading = false;
        });
        final message = e is ScryfallException ? e.message : 'Não deu para carregar os preços agora. Verifique a internet.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  /// A próxima página do ranking (mais 175 cartas).
  Future<void> _loadMore() async {
    final next = _nextPage;
    if (next == null || _loadingMore) return;
    final id = _requestId;
    setState(() => _loadingMore = true);
    try {
      final result = await _repository.fetchTrendingPrices(nextPage: next);
      if (!mounted || id != _requestId) return;
      setState(() {
        _cards.addAll(List<CardModel>.from(result['cards']));
        _raw.addAll([for (final c in result['raw'] as List) Map<String, dynamic>.from(c as Map)]);
        _nextPage = result['nextPage'] as String?;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não deu para carregar mais agora.')));
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  // Lógica de pesquisa inteligente
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _loadPrices(query: query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isLight = theme.backgroundColor.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Container(
              height: 45,
              decoration: BoxDecoration(
                color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Pesquisar carta por preço...",
                  hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
                  prefixIcon: Icon(Icons.search, color: textColor.withValues(alpha: 0.4), size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: LL.gold))
              : _cards.isEmpty 
                  ? Center(child: Text("Nenhuma carta encontrada.", style: TextStyle(color: textColor.withValues(alpha: 0.5))))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _cards.length + (_nextPage != null ? 1 : 0),
                      itemBuilder: (context, index) => index == _cards.length
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: _loadingMore
                                    ? const CircularProgressIndicator()
                                    : OutlinedButton.icon(onPressed: _loadMore, icon: const Icon(Icons.expand_more), label: const Text('Carregar mais')),
                              ),
                            )
                          : _buildCardTile(_cards[index], index, textColor, isLight),
                    ),
        ),
      ],
    );
  }

  Widget _buildCardTile(CardModel card, int index, Color textColor, bool isLight) {
    // Versões que só saem em foil (serializadas, sem moldura...): o preço é o do foil.
    final prices = (index < _raw.length ? _raw[index]['prices'] : null) as Map?;
    final foilOnly = prices != null && prices['usd'] == null && (prices['usd_foil'] ?? prices['usd_etched']) != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: neonDecoration(AreaColors.prices, neonSurface(context, context.read<ThemeProvider>().backgroundColor), radius: 16, glow: 0.12),
      child: ListTile(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => CardDetailScreen(card: () {
              final raw = index < _raw.length ? _raw[index] : const <String, dynamic>{};
              return <String, dynamic>{
                'id': card.id,
                'name': raw['printed_name'] ?? card.name,
                'imageUrl': card.imageUrl,
                'backImageUrl': raw['card_faces']?[1]?['image_uris']?['normal'],
                'rarity': card.rarity,
                'mana_cost': card.manaCost,
                'type_line': raw['printed_type_line'] ?? card.typeLine,
                'oracle_text': raw['printed_text'] ?? card.oracleText,
                'oracle_id': raw['oracle_id'],
                'setName': card.setName,
                'collectorNumber': raw['collector_number'],
                'color_identity': card.colorIdentity,
                'cmc': raw['cmc'],
                'power': raw['power']?.toString(),
                'toughness': raw['toughness']?.toString(),
                'usdPrice': card.price,
                'usdFoil': raw['prices']?['usd_foil'],
                'eurPrice': raw['prices']?['eur'],
                'tixPrice': raw['prices']?['tix'],
              };
            }())
          ));
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CachedNetworkImage(
            imageUrl: CardImages.thumb(card.imageUrl), 
            width: 50, 
            height: 70,
            fit: BoxFit.cover,
            placeholder: (c,u) => Container(color: Colors.black12),
          ),
        ),
        title: Text(card.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            card.setName,
            // O idioma da impressão (as mais caras costumam ser japonesas, etc.).
            if (index < _raw.length && _raw[index]['lang'] != null && _raw[index]['lang'] != 'en') '${_raw[index]['lang']}'.toUpperCase(),
          ].join(' · '),
          style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 11),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("US\$ ${card.price}${foilOnly ? ' foil' : ''}", style: TextStyle(color: isLight ? Colors.green.shade800 : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15)),
            if (_brl != null && double.tryParse('${card.price}') != null)
              Text("≈ R\$ ${(double.parse('${card.price}') * _brl!).toStringAsFixed(2)}", style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 11)),
            if (_searchController.text.isEmpty) Text("#${index + 1}", style: TextStyle(color: textColor.withValues(alpha: 0.2), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}