import 'dart:async'; // Necessário para o Timer (Debounce)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/services/scryfall_service.dart';
import '../../../data/repositories/card_repository.dart';
import '../../../data/models/card_model.dart';
import '../../widgets/custom_back_button.dart';
import 'card_detail_screen.dart';
import '../../widgets/neon.dart';

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

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Função que carrega os dados, aceitando query opcional
  Future<void> _loadPrices({String? query}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final result = await _repository.fetchTrendingPrices(query: query);
      if (mounted) {
        setState(() {
          _cards = List<CardModel>.from(result['cards']);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cards = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
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
    final isPt = theme.cardLanguage == 'pt';

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            automaticallyImplyLeading: false, // Mantém o CustomBackButton
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
                  hintText: isPt ? "Pesquisar carta por preço..." : "Search card by price...",
                  hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
                  prefixIcon: Icon(Icons.search, color: textColor.withValues(alpha: 0.4), size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
              : _cards.isEmpty 
                  ? Center(child: Text(isPt ? "Nenhuma carta encontrada." : "No cards found.", style: TextStyle(color: textColor.withValues(alpha: 0.5))))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _cards.length,
                      itemBuilder: (context, index) => _buildCardTile(_cards[index], index, textColor, isLight),
                    ),
        ),
        const CustomBackButton(),
      ],
    );
  }

  Widget _buildCardTile(CardModel card, int index, Color textColor, bool isLight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: neonDecoration(AreaColors.prices, neonSurface(context, context.read<ThemeProvider>().backgroundColor), radius: 16, glow: 0.12),
      child: ListTile(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => CardDetailScreen(card: {
              'id': card.id,
              'name': card.name,
              'imageUrl': card.imageUrl,
              'rarity': card.rarity,
              'mana_cost': card.manaCost,
              'type_line': card.typeLine,
              'oracle_text': card.oracleText,
              'setName': card.setName,
              'color_identity': card.colorIdentity,
              'usdPrice': card.price,
            })
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
        subtitle: Text(card.setName, style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 11)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("\$ ${card.price}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15)),
            if (_searchController.text.isEmpty) Text("#${index + 1}", style: TextStyle(color: textColor.withValues(alpha: 0.2), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}