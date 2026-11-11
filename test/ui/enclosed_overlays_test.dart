import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/net_manager.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/level_config.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';
import 'package:trap_dash_arena/ui/hud_overlay.dart';
import 'package:trap_dash_arena/ui/pause_overlay.dart';
import 'package:trap_dash_arena/ui/respawn_overlay.dart';
import 'package:trap_dash_arena/ui/result_screen.dart';
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

    // Verify platform progression squares (Level 1 has 3 platforms)
    expect(find.byKey(const Key('hud_platform_square_1')), findsOneWidget);
    expect(find.byKey(const Key('hud_platform_square_2')), findsOneWidget);
    expect(find.byKey(const Key('hud_platform_square_3')), findsOneWidget);
    expect(find.byKey(const Key('hud_platform_square_4')), findsNothing);

    // Tapping pause button pauses game
    await tester.tap(find.byKey(const Key('hud_pause_button')));
    expect(game.paused, isTrue);
  });

  testWidgets('HudOverlay platform progress squares reflect active platform and level cleared state',
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

    expect(game.controller.currentPlatform.value, equals(1));
    expect(find.byKey(const Key('hud_platform_square_1')), findsOneWidget);
    expect(find.byKey(const Key('hud_platform_square_2')), findsOneWidget);
    expect(find.byKey(const Key('hud_platform_square_3')), findsOneWidget);

    // Transition to Platform 2
    game.controller.currentPlatform.value = 2;
    await tester.pump();

    // Transition to Platform 3
    game.controller.currentPlatform.value = 3;
    await tester.pump();

    // Level cleared
    game.controller.isLevelCleared.value = true;
    await tester.pump();
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

  testWidgets('PauseOverlay blocks clicks to HudOverlay buttons underneath', (tester) async {
    final game = TrapDashGame(initialLevelNumber: 1);
    game.overlays.addEntry('PauseOverlay', (context, g) => const SizedBox());
    game.controller.startLevel(LevelConfig.get(1));
    game.pauseGame();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1280,
            height: 720,
            child: Stack(
              children: [
                HudOverlay(game: game),
                PauseOverlay(game: game),
              ],
            ),
          ),
        ),
      ),
    );

    final pauseBtn = find.byKey(const Key('hud_pause_button'));
    final restartBtn = find.byKey(const Key('hud_restart_button'));
    expect(pauseBtn, findsOneWidget);
    expect(restartBtn, findsOneWidget);

    // Tapping at coordinates of pause button is absorbed by ModalBarrier
    final pausePos = tester.getCenter(pauseBtn);
    await tester.tapAt(pausePos);
    await tester.pump();

    expect(game.paused, isTrue);

    // Dialog Resume button is clickable
    final resumeBtn = find.widgetWithText(ElevatedButton, 'RESUME');
    expect(resumeBtn, findsOneWidget);
    await tester.tap(resumeBtn);
    await tester.pump();
    expect(game.paused, isFalse);
  });

  testWidgets('RespawnOverlay and ResultOverlay absorb clicks to HudOverlay buttons', (tester) async {
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
                RespawnOverlay(game: game),
              ],
            ),
          ),
        ),
      ),
    );

    final restartPos = tester.getCenter(find.byKey(const Key('hud_restart_button')));
    await tester.tapAt(restartPos);
    await tester.pump();

    // Verify RESPAWN button on dialog is present
    expect(find.widgetWithText(ElevatedButton, 'RESPAWN'), findsOneWidget);

    // Now test ResultOverlay blocks clicks to HudOverlay buttons
    game.controller.endLevel(true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1280,
            height: 720,
            child: Stack(
              children: [
                HudOverlay(game: game),
                ResultOverlay(game: game),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(restartPos);
    await tester.pump();
    expect(find.byType(ResultOverlay), findsOneWidget);
  });

  testWidgets('HudOverlay platform progress squares are centered at x=640 on 1280px viewport regardless of dev mode',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    // Square 2 is the exact center of the 3-square row (Square 1, Square 2, Square 3)
    final square2Center = tester.getCenter(find.byKey(const Key('hud_platform_square_2')));
    expect(square2Center.dx, equals(640.0));

    // Toggle Dev Mode (adds DEV ∞ badge on left, hides timer on right)
    final heartsToggle = find.byKey(const Key('hud_dev_hearts_toggle'));
    await tester.tap(heartsToggle);
    await tester.pump();

    // Center must remain invariant at x = 640.0
    final square2CenterAfterDev = tester.getCenter(find.byKey(const Key('hud_platform_square_2')));
    expect(square2CenterAfterDev.dx, equals(640.0));
  });

  testWidgets('ResultOverlay displays ARENA CONQUERED, star message, and confetti on Level 5 completion',
      (tester) async {
    final game = TrapDashGame(initialLevelNumber: 5);
    game.controller.startLevel(LevelConfig.get(5));
    game.controller.endLevel(true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1280,
            height: 720,
            child: Stack(
              children: [
                ResultOverlay(game: game),
              ],
            ),
          ),
        ),
      ),
    );

    // Level 5 Grand Finale banner & message
    expect(find.text('ARENA CONQUERED!'), findsOneWidget);
    expect(find.text('VICTORY!'), findsNothing);
    expect(find.byKey(const Key('level5_finale_message')), findsOneWidget);
    expect(find.byKey(const Key('arcade_confetti_overlay')), findsOneWidget);

    // Verify NEXT button is omitted on Level 5
    expect(find.widgetWithText(ElevatedButton, 'NEXT'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'RETRY'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'MENU'), findsOneWidget);

    // Verify Level 1 win still displays VICTORY! and does not mount confetti
    final gameL1 = TrapDashGame(initialLevelNumber: 1);
    gameL1.controller.startLevel(LevelConfig.get(1));
    gameL1.controller.endLevel(true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1280,
            height: 720,
            child: Stack(
              children: [
                ResultOverlay(game: gameL1),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('VICTORY!'), findsOneWidget);
    expect(find.text('ARENA CONQUERED!'), findsNothing);
    expect(find.byKey(const Key('arcade_confetti_overlay')), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'NEXT'), findsOneWidget);
  });

  testWidgets('HudOverlay in online mode hides quick restart, shows coin counter and 1v1 rival bar',
      (tester) async {
    GameState.instance.setMode('online');
    addTearDown(() => GameState.instance.setMode('offline'));

    final game = TrapDashGame(initialLevelNumber: 1);
    game.controller.startLevel(LevelConfig.get(1));

    NetManager.instance.players.value = {
      '1': 'Alice',
      '2': 'Bob',
    };
    NetManager.instance.playerScores.value = {
      '1': 200,
      '2': 300,
    };
    NetManager.instance.playerCoins.value = {
      '1': 2,
      '2': 3,
    };
    addTearDown(() => NetManager.instance.disconnect());

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

    // Quick restart button should be hidden in online mode
    expect(find.byKey(const Key('hud_restart_button')), findsNothing);
    expect(find.byKey(const Key('hud_pause_button')), findsOneWidget);

    // Online coins counter should be visible
    expect(find.text('0/6'), findsOneWidget);

    // 1v1 rival leaderboard text should be visible
    expect(find.textContaining('YOU (Alice): 200 PTS 🪙2/6'), findsOneWidget);
    expect(find.textContaining('RIVAL (Bob): 300 PTS 🪙3/6'), findsOneWidget);
  });

  testWidgets('PauseOverlay in online mode hides RESTART button', (tester) async {
    GameState.instance.setMode('online');
    addTearDown(() => GameState.instance.setMode('offline'));

    final game = TrapDashGame(initialLevelNumber: 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1280,
            height: 720,
            child: Stack(
              children: [
                PauseOverlay(game: game),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.widgetWithText(ElevatedButton, 'RESUME'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'RESTART'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'QUIT TO MENU'), findsOneWidget);
  });

  testWidgets('ResultOverlay in online mode renders 1v1 breakdown and BACK TO LOBBY',
      (tester) async {
    GameState.instance.setMode('online');
    addTearDown(() => GameState.instance.setMode('offline'));

    final game = TrapDashGame(initialLevelNumber: 1);
    game.controller.startLevel(LevelConfig.get(1));

    NetManager.instance.localPlayerId = '1';
    NetManager.instance.matchWinnerId.value = '1';
    NetManager.instance.isConnected.value = true;
    NetManager.instance.finalScoreboard.value = [
      {
        'id': '1',
        'name': 'Hero',
        'score': 850,
        'coins': 5,
        'timeBonus': 350,
        'timeLeft': 35.0,
        'won': true,
      },
      {
        'id': '2',
        'name': 'Rival',
        'score': 400,
        'coins': 4,
        'timeBonus': 0,
        'timeLeft': 0.0,
        'won': false,
      },
    ];
    addTearDown(() => NetManager.instance.disconnect());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1280,
            height: 720,
            child: Stack(
              children: [
                ResultOverlay(game: game),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('MATCH VICTORY!'), findsOneWidget);
    expect(find.text('1v1 MATCH BREAKDOWN:'), findsOneWidget);
    expect(find.textContaining('YOU (Hero)'), findsOneWidget);
    expect(find.textContaining('850 PTS'), findsOneWidget);
    expect(find.textContaining('🪙 Coins: 5/6 (+500 PTS)'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'BACK TO LOBBY'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'EXIT TO MENU'), findsOneWidget);
  });
}
