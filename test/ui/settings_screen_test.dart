import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/net_manager.dart';
import 'package:trap_dash_arena/ui/lobby_screen.dart';
import 'package:trap_dash_arena/ui/settings_screen.dart';
import 'package:trap_dash_arena/ui/widgets/square_back_button.dart';
import 'package:trap_dash_arena/ui/widgets/square_toggle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GameState.instance.init();
    await NetManager.instance.disconnect();
  });

  tearDown(() async {
    await NetManager.instance.disconnect();
  });

  group('SettingsScreen One-Frame Layout & Retro Arcade Toast Tests', () {
    testWidgets('SettingsScreen is non-scrollable and fits all 5 controls in one frame', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pumpAndSettle();

      // No SingleChildScrollView
      expect(find.byType(SingleChildScrollView), findsNothing);

      // Verify all 5 controls are present and visible simultaneously
      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.text('Player Name'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.widgetWithText(SquareToggleListTile, 'Sound & Music'), findsOneWidget);
      expect(find.widgetWithText(SquareToggleListTile, 'High-Contrast Trap Tells'), findsOneWidget);
      expect(find.widgetWithText(SquareToggleListTile, 'Offline Pace-Bot Rival'), findsOneWidget);
      expect(find.text('RESET ALL PROGRESS'), findsOneWidget);
    });

    testWidgets('SettingsScreen fits various mobile landscape viewports without overflow or back button collision', (tester) async {
      final landscapeSizes = [
        const Size(720, 360),
        const Size(800, 360),
        const Size(915, 412),
        const Size(1280, 720),
      ];

      for (final size in landscapeSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Layout overflowed on $size');

        // Verify SquareBackButton does not overlap the settings frame
        final backBtnFinder = find.byType(SquareBackButton);
        expect(backBtnFinder, findsOneWidget);
        final backRect = tester.getRect(backBtnFinder);

        // Find the outer settings card
        final frameFinder = find.byWidgetPredicate(
          (widget) => widget is Container && widget.constraints?.maxWidth == 720,
        );
        expect(frameFinder, findsOneWidget);
        final frameRect = tester.getRect(frameFinder);

        expect(
          backRect.overlaps(frameRect),
          isFalse,
          reason: 'Back button overlaps settings frame at $size (back: $backRect, frame: $frameRect)',
        );
      }
    });

    testWidgets('SettingsScreen does not overflow when soft keyboard opens (resizeToAvoidBottomInset: false)', (tester) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetViewInsets());

      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pumpAndSettle();

      // Tap on player name to focus
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Simulate soft keyboard taking up 200dp
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Reset progress synchronizes on-screen toggles, text controller, and prevents dispose overwrite', (tester) async {
      // Set initial state
      await GameState.instance.setPlayerNickname('Ace');
      await GameState.instance.setHighContrastTells(true);
      await GameState.instance.setAiBotEnabled(true);
      await GameState.instance.completeLevel(1, 3);
      await GameState.instance.completeLevel(2, 3);

      expect(GameState.instance.unlockedLevel, 3);
      expect(GameState.instance.playerNickname, 'Ace');
      expect(GameState.instance.highContrastTells, isTrue);
      expect(GameState.instance.aiBotEnabled, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              child: const Text('OPEN SETTINGS'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN SETTINGS'));
      await tester.pumpAndSettle();

      // Confirm settings screen opened with custom values
      expect(find.text('Ace'), findsOneWidget);

      // Trigger Reset All Progress
      await tester.tap(find.text('RESET ALL PROGRESS'));
      await tester.pumpAndSettle();

      // Confirm Reset
      await tester.tap(find.widgetWithText(ElevatedButton, 'RESET'));
      await tester.pumpAndSettle();

      // Verify ArcadeToastBanner appears
      expect(find.byKey(const Key('arcade_toast_banner')), findsOneWidget);
      expect(find.text('Progress reset to Level 1.'), findsOneWidget);

      // Verify on-screen text controller updated to 'Runner'
      expect(find.text('Runner'), findsOneWidget);
      expect(GameState.instance.unlockedLevel, 1);
      expect(GameState.instance.highContrastTells, isFalse);
      expect(GameState.instance.aiBotEnabled, isFalse);

      // Tap back button to exit settings screen (triggers dispose)
      await tester.tap(find.byType(SquareBackButton));
      await tester.pumpAndSettle();

      // Verify dispose did NOT overwrite playerNickname back to 'Ace'
      expect(GameState.instance.playerNickname, 'Runner');
    });

    testWidgets('LobbyScreen copy IP shows ArcadeToastBanner instead of generic SnackBar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LobbyScreen()));
      await tester.pumpAndSettle();

      // Tap Copy IP button
      final copyBtn = find.byTooltip('Copy IP');
      expect(copyBtn, findsOneWidget);
      await tester.tap(copyBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('arcade_toast_banner')), findsOneWidget);
      expect(find.text('Host IP copied to clipboard!'), findsOneWidget);

      await tester.pumpAndSettle();
    });
  });
}
