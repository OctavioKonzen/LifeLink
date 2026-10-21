// Login com Firebase — a MESMA conta do site: e-mail e senha ou Google.
// As regras são as mesmas do site (web-site/src/lib/auth.js):
//   users/{uid}          → { nick, name, email, createdAt, data }
//   nicks/{nick em minúsculas} → { uid, nick }  (o dono de cada nick)
// Toda conta tem um nick (o nome que aparece no app e no site), que é de uma
// pessoa só e não muda depois de escolhido (as regras do firestore.rules
// garantem isso). Quem entra com Google pela primeira vez escolhe o nick
// antes de entrar (needsNick).
//   users/{uid}/decks/*  → um documento por deck

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum AuthStatus { disabled, loading, signedOut, needsNick, signedIn }

class AccountUser {
  final String uid;
  final String? email;
  final String? name;
  final String? photo;
  const AccountUser({required this.uid, this.email, this.name, this.photo});
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  AuthStatus status = AuthStatus.disabled;
  AccountUser? user;
  bool _googleReady = false;
  String? _creatingNick; // nick de quem está criando a conta agora

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  bool get enabled => status != AuthStatus.disabled;

  /// Chamado depois de ligar o Firebase (sem ele, o login fica desligado).
  void start() {
    status = AuthStatus.loading;
    notifyListeners();
    _auth.authStateChanges().listen((u) async {
      if (u == null) {
        _set(AuthStatus.signedOut);
        return;
      }
      // Conta criada agora com e-mail: o nick veio do formulário.
      final nick = _creatingNick ?? await _nickOf(u);
      if (_auth.currentUser?.uid != u.uid) return; // saiu enquanto lia
      if (nick == null) {
        _set(AuthStatus.needsNick, AccountUser(uid: u.uid, email: u.email, name: u.displayName, photo: u.photoURL));
      } else {
        _set(AuthStatus.signedIn, AccountUser(uid: u.uid, email: u.email, name: nick, photo: u.photoURL));
        _saveProfile(u, nick);
      }
    });
  }

  /// O nick salvo na conta; null se ainda não escolheu. Sem internet (e sem
  /// nada guardado), entra com o nome do Google em vez de travar.
  Future<String?> _nickOf(User u) async {
    try {
      final doc = await _db.collection('users').doc(u.uid).get().timeout(const Duration(seconds: 8));
      final nick = doc.data()?['nick'];
      return nick is String && nick.trim().isNotEmpty ? nick : null;
    } catch (_) {
      return u.displayName ?? u.email?.split('@').first ?? 'Jogador';
    }
  }

  /// Valida o nick: de 3 a 20 letras, números, espaço, _ ou -.
  static String? nickError(String nick) {
    final n = nick.trim();
    if (n.length < 3) return 'O nick precisa ter pelo menos 3 letras.';
    if (n.length > 20) return 'O nick pode ter no máximo 20 letras.';
    if (!RegExp(r'^[\p{L}\p{N} _-]+$', unicode: true).hasMatch(n)) return 'Use só letras, números, espaço, _ ou -.';
    return null;
  }

  static String nickKey(String nick) => nick.trim().toLowerCase();

  static const _nickTaken = 'Esse nick já é de outra pessoa. Escolha outro.';

  /// O nick está livre? (Sem diferença de maiúscula e minúscula.)
  Future<bool> isNickFree(String nick) async => !(await _db.collection('nicks').doc(nickKey(nick)).get()).exists;

  /// Registra o nick em nome desta pessoa e no perfil, juntos (transação):
  /// se outra pessoa pegar o mesmo nick ao mesmo tempo, só uma consegue.
  Future<void> _claimNick(User u, String nick) async {
    final nickRef = _db.collection('nicks').doc(nickKey(nick));
    final userRef = _db.collection('users').doc(u.uid);
    try {
      await _db.runTransaction((tx) async {
        final owner = await tx.get(nickRef);
        if (owner.exists && owner.data()?['uid'] != u.uid) throw AuthException(_nickTaken);
        if (!owner.exists) tx.set(nickRef, {'uid': u.uid, 'nick': nick});
        tx.set(userRef, {'nick': nick, 'name': nick}, SetOptions(merge: true));
      });
    } on FirebaseException catch (e) {
      // As regras recusam quem tenta pegar um nick que já tem dono.
      if (e.code == 'permission-denied') throw AuthException(_nickTaken);
      rethrow;
    }
    await u.updateDisplayName(nick);
  }

  /// Salva o nick (depois de entrar com Google) e entra no app.
  Future<void> setNick(String nick) => _guard(() async {
        final error = nickError(nick);
        if (error != null) throw AuthException(error);
        final u = _auth.currentUser;
        if (u == null) return;
        await _claimNick(u, nick.trim());
        _set(AuthStatus.signedIn, AccountUser(uid: u.uid, email: u.email, name: nick.trim(), photo: u.photoURL));
      });

  void _set(AuthStatus s, [AccountUser? u]) {
    status = s;
    user = u;
    notifyListeners();
  }

  /// Atualiza o perfil a cada entrada (o nick em si só muda em [_claimNick]).
  Future<void> _saveProfile(User u, String nick) async {
    try {
      await _db.collection('users').doc(u.uid).set({
        'name': nick,
        'email': u.email ?? '',
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static const Map<String, String> _messages = {
    'invalid-email': 'E-mail inválido.',
    'user-disabled': 'Esta conta foi desativada.',
    'user-not-found': 'E-mail ou senha incorretos.',
    'wrong-password': 'E-mail ou senha incorretos.',
    'invalid-credential': 'E-mail ou senha incorretos.',
    'email-already-in-use': 'Já existe uma conta com este e-mail. Use "Entrar".',
    'weak-password': 'A senha precisa ter pelo menos 6 caracteres.',
    'too-many-requests': 'Muitas tentativas. Espere um pouco e tente de novo.',
    'network-request-failed': 'Sem conexão com a internet.',
    'requires-recent-login': 'Por segurança, saia e entre de novo na conta antes de excluir.',
    'account-exists-with-different-credential': 'Este e-mail já tem conta com outra forma de login (e-mail e senha ou Google).',
  };

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messages[e.code] ?? 'Não foi possível concluir (${e.code}).');
    } on FirebaseException catch (e) {
      throw AuthException(_messages[e.code] ?? 'Não foi possível concluir (${e.code}).');
    }
  }

  Future<void> signUp({required String name, required String email, required String password}) => _guard(() async {
        final error = nickError(name);
        if (error != null) throw AuthException(error);
        final nick = name.trim();
        // Confere antes de criar a conta, para não criar com um nick repetido.
        if (!await isNickFree(nick)) throw AuthException(_nickTaken);
        _creatingNick = nick;
        try {
          final u = (await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password)).user!;
          try {
            await _claimNick(u, nick);
          } catch (_) {
            // Alguém pegou o nick nesse meio tempo: a conta já existe, então
            // pede outro nick (como no login com Google).
            _creatingNick = null;
            _set(AuthStatus.needsNick, AccountUser(uid: u.uid, email: u.email, photo: u.photoURL));
            throw AuthException(_nickTaken);
          }
        } finally {
          _creatingNick = null;
        }
      });

  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  Future<void> signInWithGoogle() => _guard(() async {
        final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
        if (kIsWeb) {
          await _auth.signInWithPopup(provider);
          return;
        }
        // No celular: janela nativa do Google para escolher a conta.
        final google = GoogleSignIn.instance;
        try {
          if (!_googleReady) {
            await google.initialize(); // usa o ID do google-services.json
            _googleReady = true;
          }
          final account = await google.authenticate();
          final idToken = account.authentication.idToken;
          if (idToken == null) throw AuthException('O Google não devolveu a conta. Tente de novo.');
          await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
        } on GoogleSignInException catch (e) {
          if (e.code == GoogleSignInExceptionCode.canceled) {
            throw AuthException('O login com Google foi cancelado.');
          }
          if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
              e.code == GoogleSignInExceptionCode.providerConfigurationError) {
            // Sem a configuração do login nativo: usa o login pelo navegador.
            await _auth.signInWithProvider(provider);
            return;
          }
          throw AuthException('Não foi possível entrar com Google (${e.code.name}). Tente de novo.');
        }
      });

  Future<void> resetPassword(String email) => _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  Future<void> signOut() async {
    // Também sai da conta Google, para poder escolher outra na próxima vez.
    if (!kIsWeb && _googleReady) await GoogleSignIn.instance.signOut().catchError((_) {});
    await _auth.signOut();
  }

  /// Apaga os decks, o perfil e a conta.
  Future<void> deleteAccount() => _guard(() async {
        final u = _auth.currentUser;
        if (u == null) return;
        // O Firebase só exclui a conta logo depois de entrar: confere antes de
        // apagar os dados, para não ficar com a conta sem dados.
        final last = u.metadata.lastSignInTime;
        if (last == null || DateTime.now().difference(last) > const Duration(minutes: 4)) {
          throw AuthException(_messages['requires-recent-login']!);
        }
        final userRef = _db.collection('users').doc(u.uid);
        // O nick fica livre para outra pessoa.
        final nick = (await userRef.get()).data()?['nick'];
        if (nick is String) await _db.collection('nicks').doc(nickKey(nick)).delete();
        final decks = await userRef.collection('decks').get();
        for (final d in decks.docs) {
          await d.reference.delete();
        }
        await userRef.delete();
        await u.delete();
        if (!kIsWeb && _googleReady) await GoogleSignIn.instance.signOut().catchError((_) {});
      });
}
