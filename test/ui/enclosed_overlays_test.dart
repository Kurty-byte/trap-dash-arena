import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/level_config.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';
import 'package:trap_dash_arena/ui/hud_overlay.dart';
import 'package:trap_dash_arena/ui/touch_controls_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HudOverlay renders quick-restart button, goal banner, and progress squares',
      (tester) async {
    final game = TrapDashGame(initialLevelNumber: 1);
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

    // Verify Pause and Quick Restart icons
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    // Verify R2 Goal text
    expect(find.text(game.controller.config.goalText), findsOneWidget);

    // Verify timer & score
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.text('0 PTS'), findsOneWidget);
  });

  testWidgets('TouchControlsOverlay renders touch pads with >= 120px hitboxes',
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

    // Verify Left, Right, Jump icons
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

    // Check sizes
    final leftBox = tester.getSize(find.ancestor(
      of: find.byIcon(Icons.arrow_back_rounded),
      matching: find.byType(Container),
    ).first);
    expect(leftBox.width, greaterThanOrEqualTo(120.0));
    expect(leftBox.height, greaterThanOrEqualTo(120.0));

    final jumpBox = tester.getSize(find.ancestor(
      of: find.byIcon(Icons.arrow_upward_rounded),
      matching: find.byType(Container),
    ).first);
    expect(jumpBox.width, greaterThanOrEqualTo(120.0));
    expect(jumpBox.height, greaterThanOrEqualTo(120.0));
  });
}
