import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/providers/game_provider.dart';
import '../../../data/services/lifelink_cards.dart';
import '../../../data/services/scryfall_service.dart';
import '../../../data/services/sound_service.dart';
import '../../widgets/dice_table.dart';
import '../../theme/app_theme.dart';

final Map<String, List<Map<String, dynamic>>> _pools = {};

/// Todas as cartas de um tipo (planos, fenômenos, esquemas) no banco do
/// LifeLink, guardadas enquanto o app está aberto.
Future<List<Map<String, dynamic>>> _pool(List<String> types) async {
  final key = types.join(',');
  if (_pools[key] != null) return _pools[key]!;
  final out = <Map<String, dynamic>>[];
  for (final type in types) {
    for (var page = 0; page < 12; page++) {
      final r = await LifeLinkCards.instance.search(types: [type], order: 'name', page: page, lang: 'en');
      // "plane" também acha "planeswalker": fica só o tipo certo.
      out.addAll(r.cards.where((c) => RegExp('^$type( |\$)').hasMatch('${c['type_line']}')));
      if (!r.hasMore) break;
    }
  }
  return _pools[key] = out;
}

/// Uma carta sorteada (plano, fenômeno ou esquema), no formato guardado na
/// partida: nome, imagem e texto. Do banco do LifeLink; sem ele, da Scryfall.
Future<Map<String, dynamic>> randomCard(String query) async {
  try {
    final pool = await _pool(query.contains('scheme') ? ['Scheme'] : ['Plane', 'Phenomenon']);
    if (pool.isNotEmpty) {
      final pick = pool[Random().nextInt(pool.length)];
      final full = await LifeLinkCards.instance.appCard('${pick['id']}', lang: 'pt') ?? pick;
      return {'id': full['id'], 'name': full['name'] ?? '', 'type': full['type_line'] ?? '', 'image': full['imageUrl'] ?? '', 'text': full['oracle_text'] ?? ''};
    }
  } catch (_) {}
  final data = await ScryfallService.instance.getJson(
    'https://api.scryfall.com/cards/random?q=${Uri.encodeQueryComponent(query)}',
    useCache: false,
  );
  return {
    'id': data['id'],
    'name': data['printed_name'] ?? data['name'] ?? '',
    'type': data['type_line'] ?? '',
    'image': CardImages.normalOf(data) ?? '',
    'text': data['oracle_text'] ?? '',
  };
}

/// A carta virada (tocar gira de lado: os planos são cartas deitadas).
class _TableCard extends StatefulWidget {
  final Map<String, dynamic> card;
  final bool sideways;
  const _TableCard(this.card, {super.key, this.sideways = false});

  @override
  State<_TableCard> createState() => _TableCardState();
}

class _TableCardState extends State<_TableCard> {
  CounterLook get look => CounterLook.of(context);
  late bool _turned = widget.sideways;

  @override
  Widget build(BuildContext context) {
    final image = widget.card['image'] as String? ?? '';
    return GestureDetector(
      onTap: () => setState(() => _turned = !_turned),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 260,
          child: Center(
            child: AnimatedRotation(
              turns: _turned ? 0.25 : 0,
              duration: const Duration(milliseconds: 300),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: image.isEmpty
                    ? SizedBox(width: 180, height: 250, child: Icon(Icons.image_not_supported, color: look.muted(0.38)))
                    : CachedNetworkImage(
                        imageUrl: image,
                        httpHeaders: CardImages.headers,
                        height: _turned ? 186 : 250,
                        fit: BoxFit.contain,
                        placeholder: (_, _) => const SizedBox(width: 180, height: 250, child: Center(child: CircularProgressIndicator())),
                        errorWidget: (_, _, _) => SizedBox(
                          width: 220,
                          child: Text(widget.card['text'] as String? ?? '', style: TextStyle(color: look.muted(0.70))),
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(widget.card['name'] as String? ?? '', textAlign: TextAlign.center, style: TextStyle(color: look.text, fontSize: 18, fontWeight: FontWeight.w900)),
        Text(widget.card['type'] as String? ?? '', textAlign: TextAlign.center, style: TextStyle(color: look.muted(0.54), fontSize: 12)),
        Text('Toque na carta para girar', style: TextStyle(color: look.muted(0.24), fontSize: 11)),
      ]),
    );
  }
}

/// Planechase: o plano em jogo e o dado planar 3D. Cada rolagem na mesma vez
/// custa 1 de mana a mais; na viagem (o símbolo do planeswalker) vira um plano
/// novo, no caos vale a habilidade de caos do plano.
class PlanechaseDialog extends StatefulWidget {
  final GameProvider game;
  const PlanechaseDialog({super.key, required this.game});

  @override
  State<PlanechaseDialog> createState() => _PlanechaseDialogState();
}

class _PlanechaseDialogState extends State<PlanechaseDialog> {
  CounterLook get look => CounterLook.of(context);
  final _table = GlobalKey<DiceTableState>();
  bool _rolling = false;
  bool _loading = false;
  String _result = '';
  String? _error;

  GameProvider get game => widget.game;

  @override
  void initState() {
    super.initState();
    if (game.plane == null) _newPlane();
  }

  Future<void> _newPlane() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Planos e fenômenos, como no deck planar.
      game.setPlane(await randomCard('t:plane or t:phenomenon'));
    } on ScryfallException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Não deu para virar um plano agora.';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _roll() {
    if (_rolling) return;
    HapticFeedback.lightImpact();
    _table.currentState?.roll();
  }

  void _onResult(DiceResult r) {
    HapticFeedback.heavyImpact();
    final face = r.values.isEmpty ? 0 : r.values.first;
    setState(() {
      _rolling = false;
      _result = switch (face) {
        1 => 'CAOS! Vale a habilidade de caos do plano.',
        6 => 'VIAGEM! Indo para um plano novo...',
        _ => 'Nada acontece.',
      };
    });
    if (face == 1) SoundService.instance.play(GameSound.comandante);
    if (face == 6) {
      SoundService.instance.play(GameSound.cura);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) _newPlane();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (context, _) {
        final plane = game.plane;
        final cost = game.planarRollsThisTurn;
        return Dialog(
          backgroundColor: look.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Planechase', style: TextStyle(color: look.text, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              if (_loading)
                const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                SizedBox(height: 120, child: Center(child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFF8A80)))))
              else if (plane != null)
                _TableCard(plane, key: ValueKey(plane['id']), sideways: true),
              const SizedBox(height: 10),
              SizedBox(
                height: 170,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: DiceTable(
                    key: _table,
                    kind: 'planar',
                    onRolling: () {
                      // Tocar no dado também rola: conta aqui, para o custo valer nos dois.
                      game.countPlanarRoll();
                      setState(() {
                        _rolling = true;
                        _result = '';
                      });
                    },
                    onResult: _onResult,
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: Center(
                  child: Text(
                    _result.isEmpty ? (_rolling ? '' : 'Toque no dado para rolar') : _result,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _result.isEmpty ? look.muted(0.38) : const Color(0xFFFFD54F), fontWeight: FontWeight.w900, fontSize: _result.isEmpty ? 13 : 16),
                  ),
                ),
              ),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _newPlane,
                    icon: const Icon(Icons.travel_explore),
                    label: const Text('Outro plano'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF546E7A), foregroundColor: Colors.white),
                    onPressed: _rolling ? null : _roll,
                    icon: const Icon(Icons.casino),
                    label: Text(cost == 0 ? 'Rolar (grátis)' : 'Rolar ($cost de mana)'),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text('A primeira rolagem de cada vez é grátis; cada outra na mesma vez custa 1 a mais.',
                  textAlign: TextAlign.center, style: TextStyle(color: look.muted(0.38), fontSize: 11)),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
            ]),
          ),
        );
      },
    );
  }
}

/// Archenemy: o arqui-inimigo revela um esquema por vez (sorteado da Scryfall).
class ArchenemyDialog extends StatefulWidget {
  final GameProvider game;
  const ArchenemyDialog({super.key, required this.game});

  @override
  State<ArchenemyDialog> createState() => _ArchenemyDialogState();
}

class _ArchenemyDialogState extends State<ArchenemyDialog> {
  CounterLook get look => CounterLook.of(context);
  bool _loading = false;
  String? _error;

  GameProvider get game => widget.game;

  Future<void> _reveal() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      game.setScheme(await randomCard('t:scheme'));
      HapticFeedback.heavyImpact();
      SoundService.instance.play(GameSound.comandante);
    } on ScryfallException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Não deu para revelar um esquema agora.';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (context, _) {
        final scheme = game.scheme;
        return Dialog(
          backgroundColor: look.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Archenemy', style: TextStyle(color: look.text, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('No começo de cada vez dele, o arqui-inimigo revela um esquema.', textAlign: TextAlign.center, style: TextStyle(color: look.muted(0.54), fontSize: 12)),
              const SizedBox(height: 12),
              if (_loading)
                const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                SizedBox(height: 120, child: Center(child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFF8A80)))))
              else if (scheme != null)
                _TableCard(scheme, key: ValueKey(scheme['id']))
              else
                const SizedBox(height: 120, child: Center(child: Icon(Icons.local_fire_department, size: 72, color: Color(0xFFFF7043)))),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE64A19), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
                onPressed: _loading ? null : _reveal,
                icon: const Icon(Icons.auto_fix_high),
                label: Text(scheme == null ? 'Revelar esquema' : 'Revelar o próximo'),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
            ]),
          ),
        );
      },
    );
  }
}
