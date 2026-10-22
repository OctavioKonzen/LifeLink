import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'scryfall_service.dart';

/// Separa os objetos de uma lista JSON grande ("[{...},{...}]") que chega em
/// pedaços, sem guardar tudo na memória: devolve cada objeto completo.
class JsonObjectSplitter {
  final _buffer = StringBuffer();
  int _depth = 0;
  bool _inString = false;
  bool _escape = false;

  /// Junta um pedaço de texto; volta os objetos que ficaram completos.
  List<String> add(String chunk) {
    final out = <String>[];
    var from = _depth > 0 ? 0 : -1; // onde começa o objeto neste pedaço
    for (var i = 0; i < chunk.length; i++) {
      final ch = chunk.codeUnitAt(i);
      if (_inString) {
        if (_escape) {
          _escape = false;
        } else if (ch == 0x5C) {
          _escape = true; // \
        } else if (ch == 0x22) {
          _inString = false; // "
        }
        continue;
      }
      if (ch == 0x22) {
        _inString = _depth > 0;
      } else if (ch == 0x7B) {
        if (_depth == 0) from = i; // {
        _depth++;
      } else if (ch == 0x7D && _depth > 0) {
        _depth--; // }
        if (_depth == 0) {
          _buffer.write(chunk.substring(from, i + 1));
          out.add(_buffer.toString());
          _buffer.clear();
          from = -1;
        }
      }
    }
    if (_depth > 0 && from >= 0) _buffer.write(chunk.substring(from));
    return out;
  }
}

/// Busca de cartas sem internet: baixa uma vez a lista de todas as cartas da
/// Scryfall (uma versão de cada, em inglês) e guarda só o que a busca e a
/// ficha da carta usam, num arquivo no celular.
class OfflineCards {
  OfflineCards._();
  static final OfflineCards instance = OfflineCards._();

  List<Map<String, dynamic>>? _cards;

  Future<File> _file() async => File('${(await getApplicationSupportDirectory()).path}/cards_offline.jsonl');

  /// Quando baixou (null = nunca) e quantas cartas.
  Future<({DateTime? at, int count})> info() async {
    final prefs = await SharedPreferences.getInstance();
    final at = prefs.getInt('offlineCardsAt');
    return (at: at == null ? null : DateTime.fromMillisecondsSinceEpoch(at), count: prefs.getInt('offlineCardsCount') ?? 0);
  }

  Future<bool> get available async => (await info()).at != null && await (await _file()).exists();

  /// O que fica salvo de cada carta (o mesmo formato das cartas do app).
  static Map<String, dynamic>? slim(Map<String, dynamic> c) {
    final img = CardImages.normalOf(c);
    if (img == null) return null;
    return {
      'id': c['id'],
      'name': c['name'],
      'imageUrl': img,
      'backImageUrl': c['card_faces']?[1]?['image_uris']?['normal'],
      'rarity': c['rarity'],
      'color_identity': (c['color_identity'] as List?)?.join('') ?? 'C',
      'mana_cost': c['mana_cost'] ?? c['card_faces']?[0]?['mana_cost'] ?? '',
      'type_line': c['type_line'] ?? '',
      'oracle_text': c['oracle_text'] ?? c['card_faces']?[0]?['oracle_text'] ?? '',
      'oracle_id': c['oracle_id'],
      'setName': c['set_name'],
      'cmc': c['cmc'],
      'power': c['power']?.toString(),
      'toughness': c['toughness']?.toString(),
      'collectorNumber': c['collector_number'],
      'usdPrice': c['prices']?['usd'] ?? '0.00',
      'eurPrice': c['prices']?['eur'],
    };
  }

  /// Baixa (ou atualiza) as cartas. [progress] vai de 0 a 1.
  Future<int> download({void Function(double progress)? progress}) async {
    final meta = await ScryfallService.instance.getJson('https://api.scryfall.com/bulk-data/oracle-cards', useCache: false);
    final uri = meta['download_uri'] as String?;
    if (uri == null) throw const ScryfallException('A Scryfall não mandou o arquivo das cartas.');
    final total = (meta['size'] as num?)?.toInt() ?? 0;

    final client = http.Client();
    final file = await _file();
    final temp = File('${file.path}.part');
    final sink = temp.openWrite();
    var count = 0;
    try {
      final response = await client.send(http.Request('GET', Uri.parse(uri))..headers.addAll(ScryfallService.headers));
      if (response.statusCode != 200) throw ScryfallException('Erro ${response.statusCode} ao baixar as cartas.');
      final splitter = JsonObjectSplitter();
      var received = 0;
      await for (final text in response.stream.map((bytes) {
        received += bytes.length;
        if (total > 0) progress?.call((received / total).clamp(0, 1).toDouble());
        return bytes;
      }).transform(utf8.decoder)) {
        for (final raw in splitter.add(text)) {
          final card = slim(jsonDecode(raw) as Map<String, dynamic>);
          if (card == null) continue;
          sink.writeln(jsonEncode(card));
          count++;
        }
      }
      await sink.close();
      await temp.rename(file.path);
    } on SocketException {
      await sink.close();
      throw const ScryfallException('Sem conexão com a internet.');
    } finally {
      client.close();
      if (await temp.exists()) await temp.delete();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('offlineCardsAt', DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt('offlineCardsCount', count);
    _cards = null;
    return count;
  }

  Future<void> delete() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('offlineCardsAt');
    await prefs.remove('offlineCardsCount');
    _cards = null;
  }

  /// Busca pelo nome (ou pelo tipo e texto, se o nome não achar nada).
  Future<List<Map<String, dynamic>>> search(String text, {int limit = 120}) async {
    _cards ??= await _load();
    return searchIn(_cards!, text, limit: limit);
  }

  static List<Map<String, dynamic>> searchIn(List<Map<String, dynamic>> cards, String text, {int limit = 120}) {
    final words = text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return cards.take(limit).toList();
    bool all(String hay) => words.every(hay.contains);
    final byName = [for (final c in cards) if (all('${c['name']}'.toLowerCase())) c];
    if (byName.isNotEmpty) {
      // Quem começa com o que foi digitado vem primeiro.
      byName.sort((a, b) {
        final sa = '${a['name']}'.toLowerCase().startsWith(words.first) ? 0 : 1;
        final sb = '${b['name']}'.toLowerCase().startsWith(words.first) ? 0 : 1;
        return sa != sb ? sa - sb : '${a['name']}'.compareTo('${b['name']}');
      });
      return byName.take(limit).toList();
    }
    return [for (final c in cards) if (all('${c['type_line']} ${c['oracle_text']}'.toLowerCase())) c].take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final file = await _file();
    if (!await file.exists()) return [];
    final out = <Map<String, dynamic>>[];
    await for (final line in file.openRead().transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isNotEmpty) out.add(jsonDecode(line) as Map<String, dynamic>);
    }
    return out;
  }
}
