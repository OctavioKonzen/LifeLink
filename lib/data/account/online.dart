// Mesa online e amigos (o mesmo do site, web-site/src/lib/online.js).
//
// Mesa online: tables/{código} = { owner, ownerNick, g: {...}, p0..p5: {...} }.
// A partida fica dividida por jogador (p0 = vida, veneno, nome... do
// jogador 1) e cada mudança grava só os campos que mudaram ("p1.lives"):
// dois celulares mexendo em jogadores diferentes ao mesmo tempo não se
// atrapalham.
//
// Amigos: users/{eu}/friends/{amigo} = { uid, nick }; o pedido vai em
// users/{amigo}/requests/{eu}; convites para a mesa em users/{amigo}/invites/{código}.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../providers/game_provider.dart';
import 'auth_service.dart';

/// Os campos da partida que são uma lista com um valor por jogador.
const perPlayerKeys = [
  'lives', 'poison', 'energy', 'experience', 'tax', 'treasure', 'storm', 'blessing', //
  'colors', 'colors2', 'playerNames', 'playerDecks', 'turnTotals', 'cmdRows',
];

/// A partida (formato da conta) → campos da mesa ("g.playerCount", "p0.lives").
Map<String, dynamic> flattenGame(Map<String, dynamic> sync) {
  final out = <String, dynamic>{};
  for (final e in sync.entries) {
    if (perPlayerKeys.contains(e.key) && e.value is List) {
      final list = e.value as List;
      for (var i = 0; i < GameProvider.maxPlayers; i++) {
        out['p$i.${e.key}'] = i < list.length ? list[i] : null;
      }
    } else {
      out['g.${e.key}'] = e.value;
    }
  }
  return out;
}

/// O documento da mesa → a partida no formato da conta.
Map<String, dynamic> unflattenGame(Map<String, dynamic> doc) {
  final out = <String, dynamic>{...?(doc['g'] as Map?)?.cast<String, dynamic>()};
  for (final key in perPlayerKeys) {
    final list = [for (var i = 0; i < GameProvider.maxPlayers; i++) (doc['p$i'] as Map?)?[key]];
    if (list.any((v) => v != null)) out[key] = list;
  }
  return out;
}

/// Os campos que mudaram de [before] para [after].
Map<String, dynamic> changedFields(Map<String, dynamic> before, Map<String, dynamic> after) => {
      for (final e in after.entries)
        if (jsonEncode(before[e.key]) != jsonEncode(e.value)) e.key: e.value,
    };

/// Os campos achatados → o documento (mapas g, p0..p5).
Map<String, dynamic> nestFields(Map<String, dynamic> flat) {
  final out = <String, Map<String, dynamic>>{};
  for (final e in flat.entries) {
    final dot = e.key.indexOf('.');
    out.putIfAbsent(e.key.substring(0, dot), () => {})[e.key.substring(dot + 1)] = e.value;
  }
  return out;
}

/// Sem internet, o Firestore espera para sempre: aqui desiste em 15 s com
/// uma mensagem (senão "Criar mesa" e "Adicionar" ficavam carregando).
Future<T> _net<T>(Future<T> call) => call.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Sem conexão com a internet. Tente de novo.'),
    );

/// Código da mesa: 6 letras e números fáceis de ler (sem 0/O, 1/I).
String newTableCode([Random? rng]) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = rng ?? Random.secure();
  return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
}

/// A mesa online em que este aparelho está (uma de cada vez).
class OnlineTable extends ChangeNotifier {
  OnlineTable._();
  static final OnlineTable instance = OnlineTable._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? code;
  bool isOwner = false;
  String? error; // ex.: a mesa foi fechada pelo dono
  GameProvider? _game;
  StreamSubscription? _sub;
  Map<String, dynamic> _last = {};
  Timer? _push;
  bool _applying = false;

  bool get active => code != null;

  /// Aplicando agora uma mudança que veio de outro celular da mesa.
  bool get applying => _applying;

  String _norm(String c) => c.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// Cria uma mesa com a partida atual deste aparelho.
  Future<String> create(GameProvider game) async {
    final user = AuthService.instance.user;
    if (user == null) throw Exception('Entre na conta para usar a mesa online.');
    await leave();
    String c;
    DocumentReference<Map<String, dynamic>> ref;
    // Código livre (a chance de repetir é mínima, mas confere).
    do {
      c = newTableCode();
      ref = _db.collection('tables').doc(c);
    } while ((await _net(ref.get())).exists);
    final flat = flattenGame(game.toSync());
    await _net(ref.set({
      'owner': user.uid,
      'ownerNick': user.name ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      ...nestFields(flat),
    }));
    isOwner = true;
    _attach(game, c, flat);
    return c;
  }

  /// Entra numa mesa pelo código: a partida daqui vira a da mesa.
  Future<void> join(GameProvider game, String rawCode) async {
    final user = AuthService.instance.user;
    if (user == null) throw Exception('Entre na conta para usar a mesa online.');
    final c = _norm(rawCode);
    if (c.length != 6) throw Exception('O código tem 6 letras e números.');
    await leave();
    final snap = await _net(_db.collection('tables').doc(c).get());
    if (!snap.exists) throw Exception('Não achei a mesa $c. Confira o código.');
    isOwner = snap.data()?['owner'] == user.uid;
    _attach(game, c, {});
  }

  void _attach(GameProvider game, String c, Map<String, dynamic> last) {
    code = c;
    error = null;
    _game = game;
    _last = last;
    game.onLocalChange = _schedulePush;
    _sub = _db.collection('tables').doc(c).snapshots().listen((snap) async {
      if (snap.metadata.hasPendingWrites) return;
      if (!snap.exists) {
        await leave(reason: 'A mesa $c foi fechada.');
        return;
      }
      final sync = unflattenGame(snap.data()!);
      _last = flattenGame(sync);
      _applying = true;
      try {
        await game.applySync(sync, keepHistory: true);
      } finally {
        _applying = false;
      }
    }, onError: (_) => leave(reason: 'Sem acesso à mesa (as regras do banco estão publicadas?).'));
    notifyListeners();
  }

  void _schedulePush() {
    if (_applying || code == null) return;
    _push?.cancel();
    _push = Timer(const Duration(milliseconds: 150), _flush);
  }

  Future<void> _flush() async {
    final game = _game;
    final c = code;
    if (game == null || c == null) return;
    final flat = flattenGame(game.toSync());
    final changes = changedFields(_last, flat);
    if (changes.isEmpty) return;
    _last = flat;
    try {
      await _db.collection('tables').doc(c).update({...changes, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (_) {
      // Sem internet: o Firestore guarda e manda quando voltar.
    }
  }

  /// Sai da mesa (o dono fecha a mesa para todos).
  Future<void> leave({String? reason}) async {
    final c = code;
    _push?.cancel();
    await _sub?.cancel();
    _sub = null;
    if (_game?.onLocalChange == _schedulePush) _game?.onLocalChange = null;
    _game = null;
    if (c != null && isOwner && reason == null) {
      try {
        await _db.collection('tables').doc(c).delete();
      } catch (_) {}
    }
    code = null;
    isOwner = false;
    error = reason;
    notifyListeners();
  }
}

/// Um amigo (ou pedido): uid e nick. [accepted]: o outro também me tem na lista.
class Friend {
  final String uid;
  final String nick;
  final bool accepted;
  const Friend(this.uid, this.nick, {this.accepted = false});
}

/// Amigos pelo nick: pedir, aceitar, tirar, ver os decks e convidar para a mesa.
class Friends {
  Friends._();
  static final Friends instance = Friends._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get _me => AuthService.instance.user?.uid;
  String get _myNick => AuthService.instance.user?.name ?? '';

  CollectionReference<Map<String, dynamic>> _col(String uid, String name) => _db.collection('users').doc(uid).collection(name);

  /// Pede amizade pelo nick. Se a pessoa já tinha pedido, vira amizade.
  Future<String> add(String nick) async {
    final me = _me;
    if (me == null) throw Exception('Entre na conta para adicionar amigos.');
    final key = AuthService.nickKey(nick);
    if (key.isEmpty) throw Exception('Digite o nick do amigo.');
    final owner = await _net(_db.collection('nicks').doc(key).get());
    final uid = owner.data()?['uid'] as String?;
    if (uid == null) throw Exception('Ninguém tem o nick "$nick".');
    if (uid == me) throw Exception('Esse é o seu nick.');
    final realNick = owner.data()?['nick'] as String? ?? nick;
    await _net(_col(me, 'friends').doc(uid).set({'uid': uid, 'nick': realNick, 'at': FieldValue.serverTimestamp()}));
    // Ele já tinha pedido? Então já são amigos; senão, vai o pedido.
    final theirRequest = await _net(_col(me, 'requests').doc(uid).get());
    if (theirRequest.exists) {
      await _net(theirRequest.reference.delete());
      return 'Agora você e $realNick são amigos!';
    }
    await _net(_col(uid, 'requests').doc(me).set({'uid': me, 'nick': _myNick, 'at': FieldValue.serverTimestamp()}));
    return 'Pedido enviado para $realNick.';
  }

  Future<void> accept(Friend request) async {
    final me = _me;
    if (me == null) return;
    await _net(_col(me, 'friends').doc(request.uid).set({'uid': request.uid, 'nick': request.nick, 'at': FieldValue.serverTimestamp()}));
    await _net(_col(me, 'requests').doc(request.uid).delete());
  }

  Future<void> decline(Friend request) async {
    final me = _me;
    if (me != null) await _net(_col(me, 'requests').doc(request.uid).delete());
  }

  Future<void> remove(Friend friend) async {
    final me = _me;
    if (me != null) await _net(_col(me, 'friends').doc(friend.uid).delete());
  }

  Stream<List<Friend>> requests() {
    final me = _me;
    if (me == null) return Stream.value(const []);
    return _col(me, 'requests').snapshots().map((s) => [for (final d in s.docs) Friend(d.id, '${d.data()['nick'] ?? ''}')]);
  }

  /// Os amigos, com se o outro já aceitou (ele me tem na lista dele).
  Stream<List<Friend>> friends() {
    final me = _me;
    if (me == null) return Stream.value(const []);
    return _col(me, 'friends').snapshots().asyncMap((s) async {
      final list = <Friend>[];
      for (final d in s.docs) {
        var accepted = false;
        try {
          accepted = (await _net(_col(d.id, 'friends').doc(me).get())).exists;
        } catch (_) {}
        list.add(Friend(d.id, '${d.data()['nick'] ?? ''}', accepted: accepted));
      }
      list.sort((a, b) => a.nick.toLowerCase().compareTo(b.nick.toLowerCase()));
      return list;
    });
  }

  /// Os decks do amigo (só depois que ele aceitar).
  Future<List<Map<String, dynamic>>> decksOf(Friend friend) async {
    final s = await _net(_col(friend.uid, 'decks').get());
    return [for (final d in s.docs) {...d.data(), 'id': d.id}]..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
  }

  Future<void> invite(Friend friend, String code) async {
    final me = _me;
    if (me == null) return;
    await _net(_col(friend.uid, 'invites').doc(code).set({'fromUid': me, 'fromNick': _myNick, 'code': code, 'at': FieldValue.serverTimestamp()}));
  }

  Stream<List<({String code, String from})>> invites() {
    final me = _me;
    if (me == null) return Stream.value(const []);
    return _col(me, 'invites').snapshots().map((s) => [for (final d in s.docs) (code: d.id, from: '${d.data()['fromNick'] ?? ''}')]);
  }

  Future<void> dismissInvite(String code) async {
    final me = _me;
    if (me != null) await _net(_col(me, 'invites').doc(code).delete());
  }
}
