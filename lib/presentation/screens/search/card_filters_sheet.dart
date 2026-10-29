import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Os filtros da busca de cartas e como viram a busca do Scryfall.
class CardFilters {
  /// Cores da identidade (W, U, B, R, G e C para incolor).
  final Set<String> colors;

  /// Tipos principais (Creature, Instant...): a carta tem um deles.
  final Set<String> types;

  /// Raça de criatura (Elf, Dragon...) e outro subtipo (Equipment, Aura...).
  final String? race;
  final String? subtype;

  /// Código da coleção (ex.: "tle") e o nome dela, para mostrar.
  final String? setCode;
  final String? setName;

  const CardFilters({
    this.colors = const {},
    this.types = const {},
    this.race,
    this.subtype,
    this.setCode,
    this.setName,
  });

  int get count => colors.length + types.length + (race != null ? 1 : 0) + (subtype != null ? 1 : 0) + (setCode != null ? 1 : 0);
  bool get isEmpty => count == 0;

  /// O pedaço da busca do Scryfall: um dos tipos marcados E a raça E o
  /// subtipo E as cores E a coleção.
  String toQuery() {
    final parts = <String>[
      if (types.isNotEmpty) types.length == 1 ? 't:"${types.first}"' : '(${types.map((t) => 't:"$t"').join(' or ')})',
      if (race != null) 't:"$race"',
      if (subtype != null) 't:"$subtype"',
      if (colors.isNotEmpty) 'id<=${_colorOrder.where(colors.contains).join()}',
      if (setCode != null) 'set:$setCode',
    ];
    return parts.join(' ');
  }

  static const _colorOrder = ['W', 'U', 'B', 'R', 'G', 'C'];
}

/// Uma opção dos filtros com nome e cor (botões coloridos da grade).
class _Option {
  final String value;
  final String label;
  final Color color;
  final Color text;
  const _Option(this.value, this.label, this.color, [this.text = Colors.white]);
}

const _colorOptions = [
  _Option('W', 'Branco', Color(0xFFF3E9C6), Color(0xFF4A3F1F)),
  _Option('U', 'Azul', Color(0xFF2F7FD0)),
  _Option('B', 'Preto', Color(0xFF4A4045)),
  _Option('R', 'Vermelho', Color(0xFFD9412E)),
  _Option('G', 'Verde', Color(0xFF2E8B57)),
  _Option('C', 'Incolor', Color(0xFFA9A7A2), Color(0xFF2B2B2B)),
];

const _typeOptions = [
  _Option('Creature', 'Criatura', Color(0xFF7AC74C)),
  _Option('Instant', 'Instantânea', Color(0xFF6390F0)),
  _Option('Sorcery', 'Feitiço', Color(0xFFEE8130)),
  _Option('Enchantment', 'Encantamento', Color(0xFFA98FF3)),
  _Option('Artifact', 'Artefato', Color(0xFF8E9AAF)),
  _Option('Land', 'Terreno', Color(0xFFC9A55A)),
  _Option('Planeswalker', 'Planeswalker', Color(0xFFF95587)),
  _Option('Battle', 'Batalha', Color(0xFFC22E28)),
  _Option('Legendary', 'Lendária', Color(0xFFB6A136)),
];

/// O painel de filtros, no estilo do Pocketdex: tudo numa página que rola,
/// com listas (coleção, raça, subtipo) em botões arredondados, cores e tipos
/// em grades coloridas e o botão "Ver cartas" fixo embaixo.
/// Devolve os filtros escolhidos (ou null se fechar sem aplicar).
Future<CardFilters?> showCardFilters(
  BuildContext context, {
  required CardFilters current,
  required List<Map<String, String>> sets,
  required List<String> races,
  required List<String> subtypes,
  required Color background,
  required Color textColor,
}) {
  return showModalBottomSheet<CardFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: background,
    builder: (context) => _FiltersSheet(
      initial: current,
      sets: sets,
      races: races,
      subtypes: subtypes,
      textColor: textColor,
    ),
  );
}

class _FiltersSheet extends StatefulWidget {
  final CardFilters initial;
  final List<Map<String, String>> sets;
  final List<String> races;
  final List<String> subtypes;
  final Color textColor;

  const _FiltersSheet({required this.initial, required this.sets, required this.races, required this.subtypes, required this.textColor});

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late Set<String> _colors = {...widget.initial.colors};
  late Set<String> _types = {...widget.initial.types};
  late String? _race = widget.initial.race;
  late String? _subtype = widget.initial.subtype;
  late String? _setCode = widget.initial.setCode;
  late String? _setName = widget.initial.setName;

  CardFilters get _filters =>
      CardFilters(colors: _colors, types: _types, race: _race, subtype: _subtype, setCode: _setCode, setName: _setName);

  void _clear() => setState(() {
        _colors = {};
        _types = {};
        _race = _subtype = _setCode = _setName = null;
      });

  Color get _text => widget.textColor;

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(text, style: TextStyle(color: _text.withValues(alpha: 0.6), fontSize: 15, fontWeight: FontWeight.w600)),
      );

  /// Botão em pílula com degradê que abre uma lista (como "Geração" no Pocketdex).
  Widget _pickerPill({
    required String label,
    required String? value,
    required List<Color> colors,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final idle = Theme.of(context).brightness == Brightness.light ? LL.tint : LL.card;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(22, 12, 12, 12),
            decoration: BoxDecoration(
              // Sem nada escolhido, na cor do tema; escolhido, com o degradê da lista.
              gradient: LinearGradient(colors: value == null ? [idle, Color.lerp(idle, LL.gold, 0.12)!] : colors),
              borderRadius: BorderRadius.circular(30),
              boxShadow: value == null ? null : const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                child: Text(value ?? label,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: value == null ? LL.ink : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              if (value != null)
                GestureDetector(onTap: onClear, child: const Icon(Icons.close, color: Colors.white, size: 22))
              else
                Icon(Icons.arrow_drop_down, color: LL.ink, size: 28),
            ]),
          ),
        ),
      ),
    );
  }

  /// Grade de 3 colunas com botões coloridos (como "Tipos" no Pocketdex).
  Widget _grid(List<_Option> options, Set<String> selected, void Function(String) toggle) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.6,
      children: [
        for (final o in options)
          () {
            final on = selected.contains(o.value);
            // Sem nada marcado, todos aparecem com a cor cheia; marcando, os
            // outros ficam apagados e o marcado ganha a borda.
            final dim = selected.isNotEmpty && !on;
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: dim ? 0.35 : 1,
              child: Material(
                color: o.color,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => toggle(o.value)),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: on ? Border.all(color: Colors.white, width: 2.5) : null,
                    ),
                    child: FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(o.label, style: TextStyle(color: o.text, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }(),
      ],
    );
  }

  /// Lista com busca para escolher uma opção (coleção, raça ou subtipo).
  Future<T?> _pick<T>(String title, List<T> items, String Function(T) labelOf) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
      builder: (context) => _SearchList<T>(title: title, items: items, labelOf: labelOf, textColor: _text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _filters.count;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 12, 0),
          child: Row(children: [
            Expanded(child: Text("Filtros", style: TextStyle(color: _text, fontSize: 30, fontWeight: FontWeight.bold))),
            if (count > 0) TextButton(onPressed: _clear, child: const Text("Limpar")),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            children: [
              _label("Coleção"),
              _pickerPill(
                label: "Todas as coleções",
                value: _setName,
                colors: const [Color(0xFF26A69A), Color(0xFF42A5F5)],
                onTap: () async {
                  final set = await _pick<Map<String, String>>("Coleção", widget.sets, (s) => s['name'] ?? '');
                  if (set != null) {
                    setState(() {
                      _setCode = set['code'];
                      _setName = set['name'];
                    });
                  }
                },
                onClear: () => setState(() => _setCode = _setName = null),
              ),
              _label("Cores"),
              _grid(_colorOptions, _colors, (c) => _colors.contains(c) ? _colors.remove(c) : _colors.add(c)),
              _label("Tipo"),
              _grid(_typeOptions, _types, (t) => _types.contains(t) ? _types.remove(t) : _types.add(t)),
              _label("Raça (criaturas)"),
              _pickerPill(
                label: "Todas as raças",
                value: _race,
                colors: const [Color(0xFF66BB6A), Color(0xFF26A69A)],
                onTap: () async {
                  final race = await _pick<String>("Raça", widget.races, (r) => r);
                  if (race != null) setState(() => _race = race);
                },
                onClear: () => setState(() => _race = null),
              ),
              _label("Subtipo (equipamentos, auras...)"),
              _pickerPill(
                label: "Todos os subtipos",
                value: _subtype,
                colors: const [Color(0xFFAB47BC), Color(0xFF7E57C2)],
                onTap: () async {
                  final subtype = await _pick<String>("Subtipo", widget.subtypes, (s) => s);
                  if (subtype != null) setState(() => _subtype = subtype);
                },
                onClear: () => setState(() => _subtype = null),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: LL.gold, foregroundColor: LL.onGold, minimumSize: const Size(double.infinity, 56)),
              onPressed: () => Navigator.pop(context, _filters),
              child: Text(count == 0 ? "Ver todas as cartas" : "Ver cartas ($count ${count == 1 ? 'filtro' : 'filtros'})",
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _SearchList<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) labelOf;
  final Color textColor;
  const _SearchList({required this.title, required this.items, required this.labelOf, required this.textColor});

  @override
  State<_SearchList<T>> createState() => _SearchListState<T>();
}

class _SearchListState<T> extends State<_SearchList<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final items = q.isEmpty ? widget.items : widget.items.where((i) => widget.labelOf(i).toLowerCase().contains(q)).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 12),
          child: TextField(
            autofocus: false,
            onChanged: (v) => setState(() => _query = v),
            style: TextStyle(color: widget.textColor),
            decoration: InputDecoration(hintText: "Procurar ${widget.title.toLowerCase()}", prefixIcon: const Icon(Icons.search)),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text("Nada encontrado.", style: TextStyle(color: widget.textColor.withValues(alpha: 0.5))))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) => ListTile(
                    title: Text(widget.labelOf(items[i]), style: TextStyle(color: widget.textColor)),
                    onTap: () => Navigator.pop(context, items[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}
