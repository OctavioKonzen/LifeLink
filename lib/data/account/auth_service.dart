// Login com Firebase — a MESMA conta do site: e-mail e senha ou Google.
// As regras são as mesmas do site (web-site/src/lib/auth.js):
//   users/{uid}          → { name, email, createdAt, data }
//   users/{uid}/decks/*  → um documento por deck

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum AuthStatus { disabled, loading, signedOut, signedIn }

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

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  bool get enabled => status != AuthStatus.disabled;

  /// Chamado depois de ligar o Firebase (sem ele, o login fica desligado).
  void start() {
    status = AuthStatus.loading;
    notifyListeners();
    _auth.authStateChanges().listen((u) {
      if (u == null) {
        _set(AuthStatus.signedOut);
      } else {
        _set(AuthStatus.signedIn, AccountUser(uid: u.uid, email: u.email, name: u.displayName, photo: u.photoURL));
        _saveProfile(u);
      }
    });
  }

  void _set(AuthStatus s, [AccountUser? u]) {
    status = s;
    user = u;
    notifyListeners();
  }

  Future<void> _saveProfile(User u, [String? name]) async {
    try {
      await _db.collection('users').doc(u.uid).set({
        'name': name ?? u.displayName ?? u.email?.split('@').first ?? 'Jogador',
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
        if (name.trim().length < 2) throw AuthException('Escolha um nome com pelo menos 2 letras.');
        final u = (await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password)).user!;
        await u.updateDisplayName(name.trim());
        await _saveProfile(u, name.trim());
        _set(AuthStatus.signedIn, AccountUser(uid: u.uid, email: u.email, name: name.trim()));
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
        final decks = await userRef.collection('decks').get();
        for (final d in decks.docs) {
          await d.reference.delete();
        }
        await userRef.delete();
        await u.delete();
        if (!kIsWeb && _googleReady) await GoogleSignIn.instance.signOut().catchError((_) {});
      });
}
