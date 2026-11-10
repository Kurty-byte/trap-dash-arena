import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trap_dash_arena/autoload/audio_manager.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/ui/title_screen.dart';
import 'package:trap_dash_arena/ui/widgets/arcade_page_route.dart';

/// Development trigger: when true, lives are infinite and all levels are unlocked.
const bool kDevMode = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock fixed landscape orientation for Android/iOS (R9 requirement)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Immersive sticky fullscreen mode for mobile arcade gameplay
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Initialize persistence singleton and apply development trigger
  await GameState.instance.init();
  GameState.instance.setDevMode(kDevMode);

  // Mount UI immediately so TitleScreen renders without waiting on native audio drivers
  runApp(const TrapDashApp());

  // Initialize audio asynchronously in background
  unawaited(AudioManager.instance.init());
}

class TrapDashApp extends StatelessWidget {
  const TrapDashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trap Dash Arena',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF10121A),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ArcadePageTransitionsBuilder(),
            TargetPlatform.iOS: ArcadePageTransitionsBuilder(),
            TargetPlatform.windows: ArcadePageTransitionsBuilder(),
            TargetPlatform.macOS: ArcadePageTransitionsBuilder(),
            TargetPlatform.linux: ArcadePageTransitionsBuilder(),
            TargetPlatform.fuchsia: ArcadePageTransitionsBuilder(),
          },
        ),
        fontFamily: 'AtkinsonHyperlegible',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 32,
            color: Color(0xFFFFD54F),
            letterSpacing: 2,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 20,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(
            fontSize: 28,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          bodyMedium: TextStyle(
            fontSize: 24,
            color: Color(0xFFD6D9E6),
          ),
        ),
      ),
      home: const TitleScreen(),
    );
  }
}
