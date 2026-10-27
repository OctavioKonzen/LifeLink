import 'dart:convert';
import 'dart:io';

/// O link para compartilhar um deck (o mesmo do site, web-site/src/lib/shareDeck.js):
/// o deck vai dentro do link, sem servidor. { n: nome, t: tipo, l: a lista no
/// formato do Moxfield } → JSON → deflate (raw) → base64 de URL.
/// Ex.: `https://octaviokonzen.github.io/LifeLink/#/d/<código>`
class DeckShare {
  static const site = 'https://octaviokonzen.github.io/LifeLink/';

  /// O deck → o código do link.
  static String encode({required String name, required String type, required String list}) {
    final json = utf8.encode(jsonEncode({'n': name, 't': type, 'l': list}));
    return base64Url.encode(ZLibCodec(raw: true, level: 9).encode(json)).replaceAll('=', '');
  }

  /// O código do link → o deck (ou null, se não for um código válido).
  static ({String name, String type, String list})? decode(String code) {
    try {
      final padded = code + '=' * ((4 - code.length % 4) % 4);
      final d = jsonDecode(utf8.decode(ZLibCodec(raw: true).decode(base64Url.decode(padded)))) as Map<String, dynamic>;
      return (name: '${d['n'] ?? 'Deck compartilhado'}', type: '${d['t'] ?? 'Commander'}', list: '${d['l'] ?? ''}');
    } catch (_) {
      return null;
    }
  }

  static String link(String code) => '$site#/d/$code';

  /// O código de um link de deck colado (ou null).
  static String? codeFromLink(String text) => RegExp(r'#/d/([A-Za-z0-9_-]+)').firstMatch(text)?.group(1);
}
