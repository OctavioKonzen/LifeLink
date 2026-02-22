import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Importação dos Providers
import 'data/providers/theme_provider.dart';
import 'data/providers/game_provider.dart';
import 'data/providers/deck_provider.dart';

// Importação dos Ecrãs (Screens)
import 'presentation/screens/home/home_screen.dart'; 
import 'presentation/screens/home/life_counter_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => DeckProvider()),
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
      title: 'MTG Life Counter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: themeProvider.backgroundColor.computeLuminance() > 0.5 
            ? Brightness.light 
            : Brightness.dark,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: themeProvider.backgroundColor,
      ),
      // Adicionado 'const' para resolver o aviso de performance
      home: const HomeScreen(), 
      routes: {
        '/home': (context) => const HomeScreen(),
        '/life_counter': (context) => const LifeCounterScreen(),
      },
    );
  }
}