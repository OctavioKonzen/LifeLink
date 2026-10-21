import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// O resultado de uma rolagem: o valor de cada dado e o total (no D100, as
/// dezenas e as unidades; 00 + 0 vale 100).
class DiceResult {
  final String kind;
  final List<int> values;
  final int total;
  const DiceResult(this.kind, this.values, this.total);
}

/// A mesa de dados 3D: o mesmo motor do site (three.js + física cannon-es),
/// em assets/dice, aberto numa WebView. Tocar na mesa também rola.
class DiceTable extends StatefulWidget {
  final String kind;
  final ValueChanged<DiceResult> onResult;
  final VoidCallback? onRolling;

  /// A mesa cobre a tela toda ("Quem começa"): dados menores, vistos de cima,
  /// jogados com [DiceTableState.rollAt]. Chamado quando a mesa fica pronta.
  final bool fullScreen;
  final VoidCallback? onReady;

  const DiceTable({super.key, this.kind = 'd20', required this.onResult, this.onRolling, this.fullScreen = false, this.onReady});

  @override
  State<DiceTable> createState() => DiceTableState();
}

class DiceTableState extends State<DiceTable> {
  late final WebViewController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel('DiceChannel', onMessageReceived: _onMessage)
      ..loadFlutterAsset('assets/dice/index.html');
    // O som das batidas toca sem precisar tocar dentro da mesa.
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) platform.setMediaPlaybackRequiresUserGesture(false);
  }

  void _onMessage(JavaScriptMessage message) {
    final data = jsonDecode(message.message) as Map<String, dynamic>;
    switch (data['type']) {
      case 'ready':
        setState(() => _ready = true);
        _controller.runJavaScript('LifeLinkDice.init(${widget.fullScreen})').then((_) {
          if (!widget.fullScreen) _controller.runJavaScript('LifeLinkDice.show(${jsonEncode(widget.kind)})');
          widget.onReady?.call();
        });
      case 'rolling':
        widget.onRolling?.call();
      case 'result':
        widget.onResult(DiceResult(
          data['kind'] as String,
          [for (final v in data['values'] as List) (v as num).toInt()],
          (data['total'] as num).toInt(),
        ));
    }
  }

  @override
  void didUpdateWidget(DiceTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind && _ready && !widget.fullScreen) {
      _controller.runJavaScript('LifeLinkDice.show(${jsonEncode(widget.kind)})');
    }
  }

  /// Joga os dados do tipo escolhido.
  void roll() {
    if (_ready) _controller.runJavaScript('LifeLinkDice.roll(${jsonEncode(widget.kind)})');
  }

  /// Joga um dado em cima de cada ponto da tela (x e y de 0 a 1): o
  /// resultado vem com os valores na mesma ordem.
  void rollAt(List<({double x, double y, String color, String kind})> items) {
    if (!_ready) return;
    final list = [for (final i in items) {'x': i.x, 'y': i.y, 'color': i.color, 'kind': i.kind}];
    _controller.runJavaScript('LifeLinkDice.rollAt(${jsonEncode(list)})');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      WebViewWidget(controller: _controller),
      if (!_ready && !widget.fullScreen) const Center(child: CircularProgressIndicator()),
    ]);
  }
}
