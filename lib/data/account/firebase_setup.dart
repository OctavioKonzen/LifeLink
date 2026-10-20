// Liga o Firebase (login e dados da conta — o mesmo projeto do site).
//   • Android: usa android/app/google-services.json (baixado do Console do
//     Firebase, app com.octaviokonzen.lifelink).
//   • Web (só para testes): configuração passada com --dart-define=FIREBASE_*.
// Sem configuração, o app funciona normalmente, só que sem login.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future<bool> initFirebase() async {
  try {
    if (kIsWeb) {
      const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
      if (apiKey.isEmpty) return false;
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: apiKey,
          appId: String.fromEnvironment('FIREBASE_APP_ID'),
          messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
          projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
          authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    return true;
  } catch (e) {
    debugPrint('Firebase não configurado: $e');
    return false;
  }
}
