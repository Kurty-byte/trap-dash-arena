import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/ui/game_screen.dart';
import 'package:trap_dash_arena/ui/main_menu_screen.dart';
import 'package:trap_dash_arena/ui/widgets/arcade_page_route.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GameState.instance.init();
  });

  group('Arcade Navigation & Transition Tests', () {
    test('ArcadePageRoute duration defaults to 100 milliseconds', () {
      final route = ArcadePageRoute(page: const SizedBox());
      expect(route.transitionDuration, const Duration(milliseconds: 100));
      expect(route.reverseTransitionDuration, const Duration(milliseconds: 100));
    });

    testWidgets('ArcadePageRoute performs dip-to-black transition', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    ArcadePageRoute(
                      page: const Scaffold(
                        body: Center(child: Text('TARGET SCREEN')),
                      ),
                    ),
                  );
                },
                child: const Text('GO'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('GO'), findsOneWidget);
      expect(find.text('TARGET SCREEN'), findsNothing);

      // Trigger transition
      await tester.tap(find.text('GO'));
      await tester.pump();

      // At midpoint (50ms), both screens are in flight behind curtain
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('TARGET SCREEN'), findsOneWidget);

      // Complete transition (remaining 50ms)
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('TARGET SCREEN'), findsOneWidget);
    });

    testWidgets('MainMenuScreen renders CONTINUE LVL 1 and updates dynamically', (tester) async {
      GameState.instance.unlockedLevel = 1;
      await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));

      expect(find.text('CONTINUE LVL 1'), findsOneWidget);
      expect(find.text('PLAY GAME'), findsOneWidget);

      // Advance unlocked level to 3
      GameState.instance.unlockedLevel = 3;
      await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));

      expect(find.text('CONTINUE LVL 3'), findsOneWidget);
    });

    testWidgets('GameScreen registers loading indicator and LoadingOverlay', (tester) async {
      GameState.instance.setMode('offline');

      await tester.pumpWidget(
        const MaterialApp(
          home: GameScreen(levelNumber: 1),
        ),
      );

      // Initial loading builder renders LOADING... and LEVEL 1
      expect(find.text('LOADING...'), findsOneWidget);
      expect(find.text('LEVEL 1'), findsOneWidget);
    });
  });
}
