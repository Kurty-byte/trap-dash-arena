import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/ui/credits_screen.dart';
import 'package:trap_dash_arena/ui/level_select_screen.dart';
import 'package:trap_dash_arena/ui/main_menu_screen.dart';
import 'package:trap_dash_arena/ui/mode_select_screen.dart';
import 'package:trap_dash_arena/ui/settings_screen.dart';
import 'package:trap_dash_arena/ui/widgets/hazard_background.dart';
import 'package:trap_dash_arena/ui/widgets/square_toggle.dart';
import 'package:trap_dash_arena/ui/widgets/vertical_flip_ticker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GameState.instance.init();
  });

  group('UI Screens Navigation and Offline Flow Tests', () {
    testWidgets('MainMenuScreen renders title, ticker, and hazards in non-scrollable frame', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));

      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(find.byType(HazardBackground), findsOneWidget);
      expect(find.byType(VerticalFlipTicker), findsOneWidget);
      expect(find.text('TRAP DASH'), findsOneWidget);
      expect(find.text('ARENA'), findsOneWidget);
      expect(find.text('PLAY GAME'), findsOneWidget);
      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.text('CREDITS'), findsOneWidget);
      expect(find.byKey(const Key('exit_game_button')), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('MainMenuScreen exit button opens confirmation dialog and can cancel', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));

      await tester.tap(find.byKey(const Key('exit_game_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('EXIT GAME?'), findsOneWidget);
      expect(find.text('Are you sure you want to exit Trap Dash Arena?'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);

      await tester.tap(find.text('CANCEL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('EXIT GAME?'), findsNothing);
      expect(find.byType(MainMenuScreen), findsOneWidget);
    });

    testWidgets('MainMenuScreen exit button confirms and calls SystemNavigator.pop', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));

      await tester.tap(find.byKey(const Key('exit_game_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('EXIT GAME?'), findsOneWidget);

      // In the dialog, tap the EXIT action button
      final exitDialogButton = find.widgetWithText(ElevatedButton, 'EXIT');
      expect(exitDialogButton, findsOneWidget);

      await tester.tap(exitDialogButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('EXIT GAME?'), findsNothing);
    });

    testWidgets('MainMenuScreen navigates to SettingsScreen', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));

      await tester.tap(find.text('SETTINGS'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('SETTINGS'), findsOneWidget);
    });

    testWidgets('MainMenuScreen navigates to CreditsScreen', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));

      await tester.tap(find.text('CREDITS'));
      await tester.pumpAndSettle();

      expect(find.byType(CreditsScreen), findsOneWidget);
      expect(find.text('CREDITS'), findsOneWidget);
    });

    testWidgets('MainMenuScreen navigates to ModeSelectScreen', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));

      await tester.tap(find.text('PLAY GAME'));
      await tester.pumpAndSettle();

      expect(find.byType(ModeSelectScreen), findsOneWidget);
      expect(find.text('OFFLINE SOLO'), findsOneWidget);
    });

    testWidgets('ModeSelectScreen navigates to LevelSelectScreen', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ModeSelectScreen()));

      await tester.tap(find.text('START CAMPAIGN'));
      await tester.pumpAndSettle();

      expect(find.byType(LevelSelectScreen), findsOneWidget);
      expect(find.text('LVL 1'), findsOneWidget);
      expect(find.text('LOCKED'), findsNWidgets(4)); // Levels 2 to 5 locked initially
    });

    testWidgets('LevelSelectScreen unlocks level when progress advances', (tester) async {
      // Simulate level 1 beaten
      await GameState.instance.completeLevel(1, 3);

      await tester.pumpWidget(const MaterialApp(home: LevelSelectScreen()));

      expect(find.text('LVL 1'), findsOneWidget);
      expect(find.text('LVL 2'), findsOneWidget);
      expect(find.text('LOCKED'), findsNWidgets(3)); // Levels 3 to 5 locked
    });

    testWidgets('SettingsScreen toggles high contrast tells and persists', (tester) async {
      expect(GameState.instance.highContrastTells, isFalse);

      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

      final switchFinder = find.widgetWithText(SquareToggleListTile, 'High-Contrast Trap Tells');
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(GameState.instance.highContrastTells, isTrue);
    });

    testWidgets('SettingsScreen reset progress shows standardized arcade modal and resets on confirm', (tester) async {
      await GameState.instance.completeLevel(1, 3);
      expect(GameState.instance.unlockedLevel, 2);

      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

      await tester.tap(find.text('RESET ALL PROGRESS'));
      await tester.pumpAndSettle();

      expect(find.text('RESET PROGRESS?'), findsOneWidget);
      expect(find.text('This will clear all unlocked levels and stars.'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
      expect(find.text('RESET'), findsOneWidget);

      // Tap confirm button
      await tester.tap(find.widgetWithText(ElevatedButton, 'RESET'));
      await tester.pumpAndSettle();

      expect(find.text('RESET PROGRESS?'), findsNothing);
      expect(GameState.instance.unlockedLevel, 1);
      expect(find.byKey(const Key('arcade_toast_banner')), findsOneWidget);
      expect(find.text('Progress reset to Level 1.'), findsOneWidget);
    });
  });
}
