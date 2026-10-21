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

  const DiceTable({super.key, required this.kind, required this.onResult, this.onRolling});

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
        _controller.runJavaScript('LifeLinkDice.show(${jsonEncode(widget.kind)})');
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
    if (oldWidget.kind != widget.kind && _ready) {
      _controller.runJavaScript('LifeLinkDice.show(${jsonEncode(widget.kind)})');
    }
  }

  /// Joga os dados do tipo escolhido.
  void roll() {
    if (_ready) _controller.runJavaScript('LifeLinkDice.roll(${jsonEncode(widget.kind)})');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      WebViewWidget(controller: _controller),
      if (!_ready) const Center(child: CircularProgressIndicator()),
    ]);
  }
}
