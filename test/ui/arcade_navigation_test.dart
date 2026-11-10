import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/ui/game_screen.dart';
import 'package:trap_dash_arena/ui/main_menu_screen.dart';
import 'package:trap_dash_arena/ui/widgets/arcade_dialog.dart';
import 'package:trap_dash_arena/ui/widgets/arcade_page_route.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GameState.instance.init();
  });

  group('Arcade Navigation & Transition Tests', () {
    test('ArcadePageRoute duration defaults to zero (instantaneous cut)', () {
      final route = ArcadePageRoute(page: const SizedBox());
      expect(route.transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);
    });

    testWidgets('ArcadePageRoute transitions instantaneously without delay', (tester) async {
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

      // Screen is mounted immediately without waiting for animation frames
      expect(find.text('TARGET SCREEN'), findsOneWidget);
    });

    testWidgets('showArcadeConfirmDialog renders dialog content instantaneously', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showArcadeConfirmDialog(
                    context: context,
                    title: 'RESET PROGRESS?',
                    message: 'This will clear all unlocked levels and stars.',
                  );
                },
                child: const Text('OPEN DIALOG'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('RESET PROGRESS?'), findsNothing);

      await tester.tap(find.text('OPEN DIALOG'));
      await tester.pump();

      // Dialog is visible immediately
      expect(find.text('RESET PROGRESS?'), findsOneWidget);
      expect(find.text('This will clear all unlocked levels and stars.'), findsOneWidget);
      expect(find.text('CONFIRM'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);

      await tester.tap(find.text('CANCEL'));
      await tester.pump();

      // Dialog dismissed immediately
      expect(find.text('RESET PROGRESS?'), findsNothing);
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
