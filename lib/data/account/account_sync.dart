// Sincroniza os dados com a conta (users/{uid} no Firestore) em tempo real e
// nos dois sentidos — a mesma lógica do site (web-site/src/lib/sync.js):
//   • mudanças da conta (site / outro aparelho) chegam na hora;
//   • mudanças feitas aqui gravam só a parte alterada (e só o deck alterado),
//     para o app e o site não sobrescreverem um ao outro;
//   • ao entrar numa conta, os decks feitos sem conta entram nela, e o perfil
//     que tiver mais XP fica;
//   • ao sair, os dados da conta saem do aparelho.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'user_data.dart';

class AccountSync {
  AccountSync._();
  static final AccountSync instance = AccountSync._();

  final _data = UserData.instance;
  final _auth = AuthService.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? _uid;
  StreamSubscription? _remote;
  StreamSubscription? _remoteDecks;
  Timer? _timer;
  final Set<String> _dirty = {};
  final Set<String> _dirtyDecks = {};
  final Set<String> _deletedDecks = {};
  bool _ready = false;
  bool _decksReady = false;

  void start() {
    _data.onLocalChange = _onLocalChange;
    _data.onDeckChange = _onDeckChange;
    _auth.addListener(_onAuth);
    _onAuth();
  }

  DocumentReference<Map<String, dynamic>> _userRef(String uid) => _db.collection('users').doc(uid);

  void _onAuth() {
    final uid = _auth.status == AuthStatus.signedIn ? _auth.user?.uid : null;
    if (uid == _uid) return;
    final wasSignedIn = _uid != null;
    _stop();
    _uid = uid;
    if (uid != null) {
      _listen(uid);
    } else if (wasSignedIn) {
      _data.clearAll();
    }
  }

  void _stop() {
    _remote?.cancel();
    _remoteDecks?.cancel();
    _remote = _remoteDecks = null;
    _timer?.cancel();
    _timer = null;
    _dirty.clear();
    _dirtyDecks.clear();
    _deletedDecks.clear();
    _ready = _decksReady = false;
  }

  void _listen(String uid) {
    _remote = _userRef(uid).snapshots().listen((snap) async {
      // Ignora o "eco" das gravações feitas por este aparelho.
      if (snap.metadata.hasPendingWrites || _uid != uid) return;
      if (snap.metadata.isFromCache && !snap.exists) return;
      final remote = snap.data()?['data'];
      if (remote is Map) {
        final data = Map<String, dynamic>.from(remote);
        if (!_ready) _keepBestProfile(data);
        // O que foi mudado aqui e ainda não foi gravado tem preferência.
        await _data.applyRemote(data, except: _dirty);
        // Parte que a conta ainda não tem: vai a deste aparelho.
        for (final k in UserData.sectionKeys) {
          if (!data.containsKey(k)) _dirty.add(k);
        }
      } else {
        // Conta nova: o que já estava no aparelho vai para ela.
        _dirty.addAll(UserData.sectionKeys);
      }
      _ready = true;
      if (_dirty.isNotEmpty) _scheduleSave();
    }, onError: (_) {});

    _remoteDecks = _userRef(uid).collection('decks').snapshots().listen((snap) async {
      if (snap.metadata.hasPendingWrites || _uid != uid) return;
      final remote = {
        for (final d in snap.docs) d.id: Map<String, dynamic>.from(d.data()),
      };
      if (!_decksReady) {
        // Primeira vez: decks deste aparelho que a conta não tem entram nela.
        final local = _data.decks?.readDecks() ?? {};
        for (final id in local.keys) {
          if (!remote.containsKey(id)) _dirtyDecks.add(id);
        }
        _decksReady = true;
      }
      await _data.applyRemoteDecks(remote, keep: {..._dirtyDecks, ..._deletedDecks});
      if (_dirtyDecks.isNotEmpty || _deletedDecks.isNotEmpty) _scheduleSave();
    }, onError: (_) {});
  }

  /// No primeiro contato com a conta, fica o perfil com mais XP (assim quem
  /// jogou sem conta não perde o nível ao entrar).
  void _keepBestProfile(Map<String, dynamic> remote) {
    final local = _data.snapshot(['profile'])['profile'];
    final remoteProfile = remote['profile'];
    if (local == null) return;
    final localXp = (local['xp'] as num?) ?? 0;
    final remoteXp = remoteProfile is Map ? (remoteProfile['xp'] as num?) ?? 0 : -1;
    if (localXp > remoteXp) _dirty.add('profile');
  }

  void _onLocalChange(String key) {
    if (_uid == null) return;
    _dirty.add(key);
    if (_ready) _scheduleSave();
  }

  void _onDeckChange(String id, {bool deleted = false}) {
    if (_uid == null) return;
    if (deleted) {
      _dirtyDecks.remove(id);
      _deletedDecks.add(id);
    } else {
      _deletedDecks.remove(id);
      _dirtyDecks.add(id);
    }
    if (_decksReady) _scheduleSave();
  }

  void _scheduleSave() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 600), flush);
  }

  /// Grava na hora o que estiver esperando (ex.: antes de sair da conta).
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final uid = _uid;
    if (uid == null) return;
    final ref = _userRef(uid);

    if (_ready && _dirty.isNotEmpty) {
      final changes = _data.snapshot(_dirty.toList());
      _dirty.clear();
      try {
        await ref.set({'data': changes, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      } catch (_) {
        _dirty.addAll(changes.keys); // tenta de novo na próxima mudança
      }
    }

    if (_decksReady && (_dirtyDecks.isNotEmpty || _deletedDecks.isNotEmpty)) {
      final local = _data.decks?.readDecks() ?? {};
      final saving = _dirtyDecks.toList();
      final deleting = _deletedDecks.toList();
      _dirtyDecks.clear();
      _deletedDecks.clear();
      final batch = _db.batch();
      for (final id in saving) {
        final deck = local[id];
        if (deck != null) batch.set(ref.collection('decks').doc(id), deck);
      }
      for (final id in deleting) {
        batch.delete(ref.collection('decks').doc(id));
      }
      try {
        await batch.commit();
      } catch (_) {
        _dirtyDecks.addAll(saving);
        _deletedDecks.addAll(deleting);
      }
    }
  }

  /// Sai da conta, salvando antes o que faltava.
  Future<void> logout() async {
    await flush();
    await _auth.signOut();
  }

  /// Exclui a conta e os dados dela (no aparelho e no Firestore).
  Future<void> deleteAccount() async {
    final uid = _uid;
    _stop(); // para não gravar de volta enquanto apaga
    try {
      await _auth.deleteAccount();
    } catch (e) {
      _uid = null;
      _onAuth(); // não excluiu: volta a sincronizar
      rethrow;
    }
    if (uid != null) await _data.clearAll();
  }
}
