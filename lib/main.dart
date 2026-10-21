import 'dart:async';

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

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Erro ao desenhar uma tela: mostra a mensagem em vez de uma área cinza,
  // para dar para mandar um print do que aconteceu.
  ErrorWidget.builder = (details) => Material(
    color: const Color(0xFF1E1E24),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text('Erro: ${details.exceptionAsString()}', style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
    ),
  );

  // Abre na hora (com a tela de carregamento) e carrega o resto depois: antes,
  // qualquer coisa que travasse aqui deixava o app todo preto.
  runApp(const StartupApp());
}

/// Carrega o que está salvo no aparelho e liga a conta, mostrando o progresso
/// e, se algo der errado, a mensagem de erro na tela (com "Tentar de novo").
class StartupApp extends StatefulWidget {
  const StartupApp({super.key});

  @override
  State<StartupApp> createState() => _StartupAppState();
}

class _StartupAppState extends State<StartupApp> {
  ThemeProvider? _theme;
  GameProvider? _game;
  DeckProvider? _decks;
  XpProvider? _xp;
  String? _error;
  String _step = 'Abrindo...';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _step = 'Abrindo...';
    });
    try {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]).catchError((_) {});

      // Os providers carregam o que está salvo no aparelho antes de a conta
      // começar a sincronizar (senão o carregamento apagaria o que veio dela).
      setState(() => _step = 'Carregando seus dados...');
      final theme = _theme ?? ThemeProvider();
      final game = _game ?? GameProvider();
      final decks = _decks ?? DeckProvider();
      final xp = _xp ?? XpProvider();
      _theme = theme;
      _game = game;
      _decks = decks;
      _xp = xp;
      await Future.wait([theme.ready, game.ready, decks.ready, xp.ready]).timeout(const Duration(seconds: 10));

      // Sem google-services.json, o app funciona normalmente, só que sem login.
      // Se o Firebase demorar demais, abre sem login em vez de travar.
      setState(() => _step = 'Conectando à conta...');
      final firebase = await initFirebase().timeout(const Duration(seconds: 10), onTimeout: () => false);
      if (firebase && !AuthService.instance.enabled) {
        AuthService.instance.start();
        AccountSync.instance.start();
      }
      if (mounted) setState(() => _step = '');
    } catch (e, stack) {
      debugPrint('Erro ao abrir: $e\n$stack');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step.isEmpty && _error == null) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _theme!),
          ChangeNotifierProvider.value(value: _game!),
          ChangeNotifierProvider.value(value: _decks!),
          ChangeNotifierProvider.value(value: _xp!),
          ChangeNotifierProvider.value(value: AuthService.instance),
        ],
        child: const MyApp(),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1E1E24),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/logo/lifelink.png', width: 110, height: 110),
                  const SizedBox(height: 24),
                  if (_error == null) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_step, style: const TextStyle(color: Colors.white70)),
                  ] else ...[
                    const Text(
                      'Não foi possível abrir o app.',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Se uma versão nova já resolveu isso, atualize por aqui.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    // Mesmo sem abrir, dá para atualizar o app (o erro pode já
                    // estar corrigido na versão nova).
                    if (UpdateService.supported)
                      Builder(
                        builder: (context) => ElevatedButton.icon(
                          onPressed: () => UpdateService.checkNow(context),
                          icon: const Icon(Icons.system_update),
                          label: const Text('Procurar atualização'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _start, child: const Text('Tentar de novo')),
                    const SizedBox(height: 16),
                    // Os detalhes do erro, menores (para mandar se precisar).
                    Text(
                      _error!,
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
        brightness: themeProvider.backgroundColor.computeLuminance() > 0.5 ? Brightness.light : Brightness.dark,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: themeProvider.backgroundColor,
        // Títulos grandes e em negrito nas telas, e campos e botões
        // arredondados (estilo do Pocketdex, com as cores do LifeLink).
        appBarTheme: AppBarTheme(
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: themeProvider.backgroundColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        ),
      ),
      // Sem estar logado, a primeira tela é sempre a de login (a mesma conta
      // do site). Sem Firebase configurado, o login fica desligado e o app
      // abre direto. Confere uma vez se saiu versão nova (GitHub Releases).
      home: Builder(
        builder: (context) {
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
        },
      ),
      routes: {'/home': (context) => const HomeScreen(), '/life_counter': (context) => const LifeCounterScreen()},
    );
  }
}
