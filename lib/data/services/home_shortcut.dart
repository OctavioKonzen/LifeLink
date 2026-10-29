import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Pôr um atalho do app (o contador de vida) direto na tela inicial do
/// celular (MainActivity.kt). O Android pergunta antes de pôr.
class HomeShortcut {
  static const _channel = MethodChannel('lifelink/shortcuts');

  /// Volta false quando o celular não deixa (Android antes do 8 ou o
  /// launcher não aceita).
  static Future<bool> pinCounter() async {
    if (kIsWeb) return false;
    try {
      return await _channel.invokeMethod<bool>('pin', {'id': 'counter', 'label': 'Contador de vida', 'icon': 'ic_shortcut_counter'}) ?? false;
    } catch (_) {
      return false;
    }
  }
}
