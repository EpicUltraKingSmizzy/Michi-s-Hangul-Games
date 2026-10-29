import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/app_state.dart';
import 'screens/home_screen.dart';
import 'widgets/common.dart';

final AppState appState = AppState();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Draw behind transparent system bars with dark icons from the first frame;
  // AppBarTheme and FunBackground's AnnotatedRegion keep it that way per screen.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(lightBackgroundOverlay);
  await appState.load();
  runApp(const HangulHoorayApp());
}

class HangulHoorayApp extends StatelessWidget {
  const HangulHoorayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF5C8A),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Michi’s Hangul Games',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: lightBackgroundOverlay,
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Color(0xFF3A1D5C),
          ),
          foregroundColor: Color(0xFF3A1D5C),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
