import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Importação dos Providers
import 'data/providers/theme_provider.dart';
import 'data/providers/game_provider.dart';
import 'data/providers/deck_provider.dart';
import 'data/providers/xp_provider.dart';

// Conta (a mesma do site) e atualização do app
import 'data/account/account_sync.dart';
import 'data/account/auth_service.dart';
import 'data/account/firebase_setup.dart';
import 'data/services/update_service.dart';

// Importação dos Ecrãs (Screens)
import 'presentation/screens/home/home_screen.dart'; 
import 'presentation/screens/home/account_screen.dart';
import 'presentation/screens/home/life_counter_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Os providers carregam o que está salvo no aparelho antes de a conta
  // começar a sincronizar (senão o carregamento apagaria o que veio dela).
  final theme = ThemeProvider();
  final game = GameProvider();
  final decks = DeckProvider();
  final xp = XpProvider();
  await Future.wait([theme.ready, game.ready, decks.ready, xp.ready]);

  // Sem google-services.json, o app funciona normalmente, só que sem login.
  if (await initFirebase()) {
    AuthService.instance.start();
    AccountSync.instance.start();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider.value(value: game),
        ChangeNotifierProvider.value(value: decks),
        ChangeNotifierProvider.value(value: xp),
        ChangeNotifierProvider.value(value: AuthService.instance),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'LifeLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: themeProvider.backgroundColor.computeLuminance() > 0.5 
            ? Brightness.light 
            : Brightness.dark,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: themeProvider.backgroundColor,
      ),
      // Sem estar logado, a primeira tela é sempre a de login (a mesma conta
      // do site). Sem Firebase configurado, o login fica desligado e o app
      // abre direto. Confere uma vez se saiu versão nova (GitHub Releases).
      home: Builder(builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) => UpdateService.checkOnStart(context));
        final status = context.watch<AuthService>().status;
        switch (status) {
          case AuthStatus.loading:
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          case AuthStatus.signedOut:
            return const AccountScreen(start: true);
          case AuthStatus.signedIn:
          case AuthStatus.disabled:
            return const HomeScreen();
        }
      }), 
      routes: {
        '/home': (context) => const HomeScreen(),
        '/life_counter': (context) => const LifeCounterScreen(),
      },
    );
  }
}
