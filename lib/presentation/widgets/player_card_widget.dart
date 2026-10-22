import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/providers/game_provider.dart';
import '../../../data/services/sound_service.dart';

/// O quadro de um jogador no contador de vida, como nos apps do gênero:
///   • toque na metade esquerda tira 1 de vida, na direita soma 1;
///   • segurando, vai de 1 em 1, cada vez mais rápido, enquanto segura;
///   • o quanto mudou (ex.: −7) aparece em cima da vida por 2 segundos;
///   • os contadores (veneno, energia, experiência, imposto e dano de
///     comandante) ficam embaixo; tocar abre todos eles;
///   • tocar no nome (embaixo, com os contadores) troca o nome e a cor;
///   • arrastar o quadro para a direita mostra o veneno e para a esquerda o
///     dano de comandante recebido, ali mesmo na mesa (arrastar de volta, ou
///     esperar uns segundos, volta para a vida).
class PlayerCardWidget extends StatefulWidget {
  final int index;
  final int quarterTurns;
  final GameProvider game;
  final VoidCallback onCounters;
  final VoidCallback onSettings;
  final VoidCallback? onHistory;

  const PlayerCardWidget({
    super.key,
    required this.index,
    required this.quarterTurns,
    required this.game,
    required this.onCounters,
    required this.onSettings,
    this.onHistory,
  });

  @override
  State<PlayerCardWidget> createState() => _PlayerCardWidgetState();
}

class _PlayerCardWidgetState extends State<PlayerCardWidget> {
  int _lifeDelta = 0;
  Timer? _deltaTimer;
  Timer? _holdTimer;
  Timer? _clock; // atualiza o tempo da vez enquanto é a vez deste jogador

  // A "página" do quadro: 0 = vida, -1 = veneno, 1 = dano de comandante.
  int _page = 0;
  int _cmdSel = -1; // o comandante escolhido na página do comandante
  Timer? _pageTimer;

  /// Arrastou para o lado: direita vai para o veneno, esquerda para o
  /// comandante (e o contrário volta para a vida).
  // Quanto o dedo andou para o lado neste arraste (vale arrastar devagar).
  double _dragDx = 0;

  void _onSwipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final dx = _dragDx;
    _dragDx = 0;
    // Vale um arraste rápido ou um de pelo menos 40 pontos, mesmo devagar.
    final direction = dx.abs() >= 40 ? dx.sign : (v.abs() >= 250 ? v.sign : 0);
    if (direction == 0) return;
    _goTo((_page + (direction > 0 ? -1 : 1)).clamp(-1, 1));
  }

  void _goTo(int page) {
    if (page == _page) return;
    HapticFeedback.selectionClick();
    _stopHold();
    setState(() => _page = page);
    _touchPage();
  }

  /// "↩ Vida": volta para a vida com um toque (nas páginas de veneno e comandante).
  Widget _backToLife() => Align(
        alignment: Alignment.topLeft,
        child: GestureDetector(
          onTap: () => _goTo(0),
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.undo, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text('Vida', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ]),
          ),
        ),
      );

  /// Sem mexer por uns segundos, o quadro volta para a vida.
  void _touchPage() {
    _pageTimer?.cancel();
    if (_page == 0) return;
    _pageTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _page = 0);
    });
  }

  void _changePoison(int amount) {
    widget.game.updateCounter(Counter.poison, widget.index, amount);
    HapticFeedback.selectionClick();
    _touchPage();
  }

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.game.turnPlayer == widget.index) setState(() {});
    });
  }

  static String clock(Duration d) {
    final m = d.inMinutes, s = d.inSeconds % 60;
    return m >= 60 ? '${m ~/ 60}h${(m % 60).toString().padLeft(2, '0')}' : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _change(int amount) {
    final wasDead = widget.game.isDead(widget.index);
    widget.game.updateLife(widget.index, amount);
    HapticFeedback.selectionClick();
    setState(() => _lifeDelta += amount);
    _deltaTimer?.cancel();
    _deltaTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _lifeDelta = 0);
    });
    if (!wasDead && widget.game.isDead(widget.index)) HapticFeedback.heavyImpact();
  }

  // Segurar: de 1 em 1 enquanto segura, começando devagar e acelerando
  // (dá para parar no número certo).
  void _startHold(int sign, [void Function(int)? action]) {
    HapticFeedback.mediumImpact();
    SoundService.instance.beginHold(); // o som toca uma vez, ao soltar
    _holdTimer?.cancel();
    var steps = 0;
    void tick() {
      (action ?? _change)(sign);
      steps++;
      final wait = max(45, 260 - steps * 18);
      _holdTimer = Timer(Duration(milliseconds: wait), tick);
    }

    tick();
  }

  void _stopHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    SoundService.instance.endHold();
  }

  @override
  void dispose() {
    _deltaTimer?.cancel();
    _holdTimer?.cancel();
    _clock?.cancel();
    _pageTimer?.cancel();
    super.dispose();
  }

  Widget _zone(int sign, [void Function(int)? action]) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => (action ?? _change)(sign),
        onLongPressStart: (_) => _startHold(sign, action),
        onLongPressEnd: (_) => _stopHold(),
        onLongPressCancel: _stopHold,
        child: Align(
          alignment: sign < 0 ? const Alignment(-0.75, 0) : const Alignment(0.75, 0),
          child: Icon(sign < 0 ? Icons.remove : Icons.add, color: Colors.white.withValues(alpha: 0.35), size: 34),
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String text, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
      ]),
    );
  }

  /// A vida: toque na metade esquerda −, na direita +.
  Widget _lifePage(int life, bool dead) {
    return Stack(children: [
      Row(children: [_zone(-1), _zone(1)]),
      IgnorePointer(
        child: LayoutBuilder(builder: (context, box) {
          final size = (box.maxHeight * 0.42).clamp(40.0, 200.0);
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedOpacity(
                opacity: _lifeDelta == 0 ? 0 : 1,
                duration: const Duration(milliseconds: 150),
                child: Text(
                  _lifeDelta > 0 ? '+$_lifeDelta' : '$_lifeDelta',
                  style: TextStyle(
                    fontSize: size * 0.28,
                    fontWeight: FontWeight.w900,
                    color: _lifeDelta >= 0 ? const Color(0xFFB9F6CA) : const Color(0xFFFFCDD2),
                    shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                ),
              ),
              FittedBox(
                child: Text(
                  '$life',
                  style: TextStyle(
                    color: dead ? Colors.white38 : Colors.white,
                    fontSize: size,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    shadows: [Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                ),
              ),
            ]),
          );
        }),
      ),
    ]);
  }

  /// O veneno grande no lugar da vida (10 derrota): − e + como na vida.
  Widget _poisonPage(GameProvider game, int i) {
    final poison = game.counter(Counter.poison, i);
    return Stack(children: [
      Container(color: const Color(0xFF4A148C).withValues(alpha: 0.35)),
      Row(children: [_zone(-1, _changePoison), _zone(1, _changePoison)]),
      IgnorePointer(
        child: LayoutBuilder(builder: (context, box) {
          final size = (box.maxHeight * 0.36).clamp(36.0, 170.0);
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.science, color: const Color(0xFFE1BEE7), size: size * 0.22),
                const SizedBox(width: 6),
                Text('VENENO', style: TextStyle(color: const Color(0xFFE1BEE7), fontWeight: FontWeight.w900, fontSize: size * 0.17, letterSpacing: 1)),
              ]),
              FittedBox(
                child: Text('$poison', style: TextStyle(color: Colors.white, fontSize: size, fontWeight: FontWeight.w900, height: 1.0)),
              ),
              Text('de 10', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: size * 0.15)),
            ]),
          );
        }),
      ),
      _backToLife(),
    ]);
  }

  /// O dano de comandante recebido, no mesmo jeito do veneno: o número grande
  /// e as metades − e +, de um comandante por vez. Em cima, um botão para
  /// cada comandante da mesa (e o 2º, do parceiro): cada um conta à parte e
  /// só 21 de um mesmo comandante derrota.
  Widget _commanderPage(GameProvider game, int i) {
    final cmds = [
      for (int a = 0; a < game.playerCount; a++)
        if (a != i) ...[a, if (game.hasPartner(a)) a + GameProvider.maxPlayers],
    ];
    if (!cmds.contains(_cmdSel)) _cmdSel = cmds.first;
    final sel = _cmdSel;
    const tint = Color(0xFFBF360C);
    void change(int d) {
      game.updateCommanderDamage(i, sel, d);
      HapticFeedback.selectionClick();
      _touchPage();
    }

    Widget chip(int c, double size) {
      final on = c == sel;
      final value = game.cmdDamage(i, c);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _cmdSel = c);
          HapticFeedback.selectionClick();
          _touchPage();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: EdgeInsets.symmetric(horizontal: size * 0.1, vertical: size * 0.05),
          decoration: BoxDecoration(
            color: on ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(size),
            border: Border.all(color: on ? Colors.white : Colors.white24, width: 2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: size * 0.12,
              height: size * 0.12,
              decoration: BoxDecoration(color: game.colorOf(c % GameProvider.maxPlayers), shape: BoxShape.circle, border: Border.all(color: Colors.white70, width: 1.5)),
            ),
            SizedBox(width: size * 0.05),
            Flexible(child: Text(game.commanderName(c), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.13))),
            SizedBox(width: size * 0.06),
            Text('$value', style: TextStyle(color: value >= 21 ? Colors.redAccent : Colors.white, fontWeight: FontWeight.w900, fontSize: size * 0.15)),
          ]),
        ),
      );
    }

    final value = game.cmdDamage(i, sel);
    return Stack(children: [
      Positioned.fill(child: Container(color: tint.withValues(alpha: 0.3))),
      Positioned.fill(child: Row(children: [_zone(-1, change), _zone(1, change)])),
      Positioned.fill(
        child: LayoutBuilder(builder: (context, box) {
          final size = (box.maxHeight * (cmds.length > 1 ? 0.3 : 0.36)).clamp(36.0, 170.0);
          // Os botões dos comandantes num tamanho que dá para ler e tocar.
          final chipSize = size.clamp(90.0, 120.0);
          // Tudo cabe no quadro (diminui se precisar); os botões quebram linha.
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 44, 8, 58),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: box.maxWidth - 16,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
              IgnorePointer(
                child: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shield, color: const Color(0xFFFFE0B2), size: size * 0.22),
                  const SizedBox(width: 6),
                  Text('COMANDANTE', style: TextStyle(color: const Color(0xFFFFE0B2), fontWeight: FontWeight.w900, fontSize: size * 0.17, letterSpacing: 1)),
                ])),
              ),
              if (cmds.length > 1)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: size * 0.06),
                  child: Wrap(alignment: WrapAlignment.center, runSpacing: 6, children: [for (final c in cmds) chip(c, chipSize)]),
                ),
              IgnorePointer(
                child: FittedBox(
                  child: Text('$value', style: TextStyle(color: value >= 21 ? Colors.redAccent : Colors.white, fontSize: size, fontWeight: FontWeight.w900, height: 1.0)),
                ),
              ),
              IgnorePointer(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('de ${game.commanderName(sel)} · 21 derrota', maxLines: 1, style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: size * 0.15)),
                ),
              ),
                  ]),
                ),
              ),
            ),
          );
        }),
      ),
      _backToLife(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final i = widget.index;
    final life = game.lives[i];
    final dead = game.isDead(i);
    final color = game.colorOf(i);
    // O maior dano de um mesmo comandante (não a soma: só 21 de um derrota).
    final cmdTop = game.maxCmdDamage(i);
    final commander = game.startingLife >= 30;

    final badges = <Widget>[
      if (game.counter(Counter.poison, i) > 0) _badge(Icons.science, '${game.counter(Counter.poison, i)}', const Color(0xFFE1BEE7)),
      if (commander || cmdTop > 0) _badge(Icons.shield, '$cmdTop', const Color(0xFFFFE0B2)),
      if (game.counter(Counter.energy, i) > 0) _badge(Icons.bolt, '${game.counter(Counter.energy, i)}', const Color(0xFFFFF59D)),
      if (game.counter(Counter.experience, i) > 0) _badge(Icons.auto_awesome, '${game.counter(Counter.experience, i)}', Colors.white),
      if (game.counter(Counter.tax, i) > 0) _badge(Icons.account_balance, '+${game.counter(Counter.tax, i)}', const Color(0xFFB2DFDB)),
      if (game.counter(Counter.treasure, i) > 0) _badge(Icons.paid, '${game.counter(Counter.treasure, i)}', const Color(0xFFFFD54F)),
      if (game.counter(Counter.storm, i) > 0) _badge(Icons.thunderstorm, '${game.counter(Counter.storm, i)}', const Color(0xFF90CAF9)),
      if (game.counter(Counter.blessing, i) > 0) _badge(Icons.location_city, '', const Color(0xFFFFF8E1)),
    ];
    final myTurn = game.turnPlayer == i;

    return RotatedBox(
      quarterTurns: widget.quarterTurns,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          // A vez deste jogador: borda clara em volta.
          border: myTurn ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: myTurn ? [BoxShadow(color: Colors.white.withValues(alpha: 0.45), blurRadius: 14)] : null,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // Com segunda cor, degradê de uma para a outra (deck de duas cores).
            colors: dead
                ? [Colors.grey.shade800, Colors.grey.shade900]
                : game.secondColorOf(i) != null
                    ? [Color.lerp(color, Colors.white, 0.05)!, Color.lerp(game.secondColorOf(i)!, Colors.black, 0.1)!]
                    : [Color.lerp(color, Colors.white, 0.08)!, Color.lerp(color, Colors.black, 0.25)!],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          // Arrastar para o lado troca a página (vida, veneno, comandante).
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (_) => _dragDx = 0,
              onHorizontalDragUpdate: (d) => _dragDx += d.delta.dx,
              onHorizontalDragEnd: _onSwipe,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
                child: KeyedSubtree(
                  key: ValueKey(_page),
                  child: _page == -1
                      ? _poisonPage(game, i)
                      : _page == 1
                          ? _commanderPage(game, i)
                          : _lifePage(life, dead),
                ),
              ),
            ),
          ),

          // Em qual página está (as bolinhas) — vida no meio.
          IgnorePointer(
            child: Align(
              // Embaixo (acima do nome), longe dos números de cada página.
              alignment: const Alignment(0, 0.74),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final p in const [-1, 0, 1])
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _page == p ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: _page == p ? 0.9 : 0.35), borderRadius: BorderRadius.circular(3)),
                  ),
              ]),
            ),
          ),

          // Derrotado: caveira por cima (ainda dá para mexer, se foi engano).
          if (dead)
            IgnorePointer(
              child: Center(
                child: Opacity(opacity: 0.85, child: Text('💀', style: TextStyle(fontSize: 64, shadows: [Shadow(color: Colors.red.shade900, blurRadius: 20)]))),
              ),
            ),

          // Em cima (o lado do meio da mesa): monarca, iniciativa e a vez.
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (game.monarch == i) _badge(Icons.workspace_premium, 'Monarca', const Color(0xFFFFD54F)),
                  if (game.initiative == i) _badge(Icons.fort, 'Iniciativa', const Color(0xFFFFAB91)),
                  if (myTurn)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        game.nextTurn();
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('Rodada ${game.turnRound} · ${clock(game.turnElapsed)}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
                          const SizedBox(width: 6),
                          const Text('Passar', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w800, fontSize: 13)),
                          const Icon(Icons.skip_next, size: 18, color: Colors.black87),
                        ]),
                      ),
                    ),
                ]),
              ),
            ),
          ),

          // Embaixo (o lado de quem joga, longe do botão do meio): o nome,
          // que troca nome e cor, e os contadores em uso, que abrem todos.
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 8, right: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    onTap: widget.onSettings,
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          game.playerNames[i],
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, decoration: dead ? TextDecoration.lineThrough : null),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.edit, size: 14, color: Colors.white70),
                      ]),
                    ),
                  ),
                  // Histórico da vida deste jogador.
                  if (widget.onHistory != null)
                    GestureDetector(onTap: widget.onHistory, child: _badge(Icons.timeline, '', Colors.white70)),
                  GestureDetector(
                    onTap: widget.onCounters,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      ...badges,
                      _badge(Icons.add_circle_outline, badges.isEmpty ? 'Contadores' : '', Colors.white70),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
