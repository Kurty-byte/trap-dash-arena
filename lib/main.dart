import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock fixed landscape orientation for Android/iOS (R9 requirement)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Immersive sticky fullscreen mode for mobile arcade gameplay
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const TrapDashApp());
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
      home: const Phase1ReadyScreen(),
    );
  }
}

class Phase1ReadyScreen extends StatelessWidget {
  const Phase1ReadyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TRAP DASH ARENA',
                style: textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Phase 1 Configured (Landscape 1280x720)',
                style: textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ready for Phase 2 Autoload Singletons',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
