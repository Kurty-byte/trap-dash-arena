import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/level_config.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';
import 'package:trap_dash_arena/ui/hud_overlay.dart';
import 'package:trap_dash_arena/ui/touch_controls_overlay.dart';
import 'package:trap_dash_arena/ui/widgets/hud_sprite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HudOverlay renders sprite pause/restart buttons, goal banner, and progress squares',
      (tester) async {
    final game = TrapDashGame(initialLevelNumber: 1);
    game.overlays.addEntry('PauseOverlay', (context, g) => const SizedBox());
    game.controller.startLevel(LevelConfig.get(1));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1280,
            height: 720,
            child: Stack(
              children: [
                HudOverlay(game: game),
              ],
            ),
          ),
        ),
      ),
    );

    // Verify Pause and Quick Restart sprite buttons exist
    expect(find.byKey(const Key('hud_pause_button')), findsOneWidget);
    expect(find.byKey(const Key('hud_restart_button')), findsOneWidget);
    expect(find.byType(HudSpriteButton), findsNWidgets(2));

    // Verify R2 Goal text
    expect(find.text(game.controller.config.goalText), findsOneWidget);

    // Verify timer & score
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.text('0 PTS'), findsOneWidget);

    // Verify RepaintBoundary isolates HUD overlay
    expect(
      find.descendant(
        of: find.byType(HudOverlay),
        matching: find.byType(RepaintBoundary),
      ),
      findsAtLeastNWidgets(1),
    );

    // Tapping pause button pauses game
    await tester.tap(find.byKey(const Key('hud_pause_button')));
    expect(game.paused, isTrue);
  });

  testWidgets('TouchControlsOverlay renders wireframe pads with >= 120px hitboxes and dispatches player actions',
      (tester) async {
    final game = TrapDashGame(initialLevelNumber: 1);
    game.player = Player(position: Vector2(148, 552));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1280,
            height: 720,
            child: Stack(
              children: [
                TouchControlsOverlay(game: game),
              ],
            ),
          ),
        ),
      ),
    );

    // Verify Left, Right, Jump wireframe pads exist
    final leftFinder = find.byKey(const Key('touch_left_button'));
    final rightFinder = find.byKey(const Key('touch_right_button'));
    final jumpFinder = find.byKey(const Key('touch_jump_button'));

    expect(leftFinder, findsOneWidget);
    expect(rightFinder, findsOneWidget);
    expect(jumpFinder, findsOneWidget);

    // Assert touch hitboxes satisfy AGENTS.md >= 120px specification
    final leftBox = tester.getSize(leftFinder);
    expect(leftBox.width, greaterThanOrEqualTo(120.0));
    expect(leftBox.height, greaterThanOrEqualTo(120.0));

    final rightBox = tester.getSize(rightFinder);
    expect(rightBox.width, greaterThanOrEqualTo(120.0));
    expect(rightBox.height, greaterThanOrEqualTo(120.0));

    final jumpBox = tester.getSize(jumpFinder);
    expect(jumpBox.width, greaterThanOrEqualTo(120.0));
    expect(jumpBox.height, greaterThanOrEqualTo(120.0));

    // Verify pointer interactions drive movement
    final gesture = await tester.startGesture(tester.getCenter(leftFinder));
    expect(game.player.horizontalDirection, -1);

    await gesture.up();
    expect(game.player.horizontalDirection, 0);

    final rightGesture = await tester.startGesture(tester.getCenter(rightFinder));
    expect(game.player.horizontalDirection, 1);

    await rightGesture.up();
    expect(game.player.horizontalDirection, 0);

    // Verify jump gesture triggers player jump
    final jumpGesture = await tester.startGesture(tester.getCenter(jumpFinder));
    expect(game.player.isJumpBuffered, isTrue);

    await jumpGesture.up();
  });
}
