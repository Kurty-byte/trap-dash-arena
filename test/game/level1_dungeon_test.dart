import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trap_dash_arena/game/actors/checkpoint_flag.dart';
import 'package:trap_dash_arena/game/actors/exit_portal.dart';
import 'package:trap_dash_arena/game/actors/ground_block.dart';
import 'package:trap_dash_arena/game/actors/moving_gap_floor.dart';
import 'package:trap_dash_arena/game/actors/pickup_item.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/actors/sudden_gap.dart';
import 'package:trap_dash_arena/game/actors/trap_spike.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GroundBlock Helper & Gap Actors Tests', () {
    late TrapDashGame game;
    late Player player;

    setUp(() async {
      game = TrapDashGame(initialLevelNumber: 1);
      await game.onLoad();
      player = game.player;
    });

    test('GroundBlock.resolvePlayerBlockCollision resolves floor support', () {
      player.position = Vector2(150, 504);
      player.velocity.y = 200;
      player.isOnGround = false;

      GroundBlock.resolvePlayerBlockCollision(player, 100, 500, 300, 540);

      expect(player.position.y, equals(500));
      expect(player.velocity.y, equals(0));
      expect(player.isOnGround, isTrue);
    });

    test('SuddenGap supports player then collapses on proximity', () async {
      final gap = SuddenGap(
        trapId: 'test_gap',
        position: Vector2(500, 552),
        size: Vector2(92, 200),
        triggerLeadPx: 46.0,
      );
      game.world.add(gap);
      await gap.onLoad();

      expect(gap.hitbox.collisionType, equals(CollisionType.passive));
      expect(gap.isTriggered, isFalse);

      // Player stands on solid gap plug before trigger
      player.position = Vector2(400, 554);
      player.velocity.y = 100;
      gap.onCollision({Vector2(400, 552)}, player);

      // When player walks to proximity (500 - 46 = 454)
      player.position = Vector2(455, 552);
      gap.update(0.016);

      expect(gap.isTriggered, isTrue);
      expect(gap.hitbox.collisionType, equals(CollisionType.inactive));

      // After resetToSolid, gap becomes solid again and marked revealed
      gap.resetToSolid();
      expect(gap.isTriggered, isFalse);
      expect(gap.isRevealed, isTrue);
      expect(gap.hitbox.collisionType, equals(CollisionType.passive));
    });

    test('MovingGapFloor in chase mode opens at triggerX and halts at stopGapX', () async {
      final floor = MovingGapFloor(
        trapId: 'test_chase',
        position: Vector2(1840, 552),
        size: Vector2(624, 200),
        mode: MovingGapMode.chase,
        gapWidth: 88.0,
        triggerPlayerX: 1888.0,
        chaseSpeed: 200.0,
        stopGapX: 512.0,
      );
      game.world.add(floor);
      await floor.onLoad();

      expect(floor.isGapOpen, isFalse);

      // Player before trigger
      player.position = Vector2(1850, 552);
      floor.update(0.016);
      expect(floor.isGapOpen, isFalse);

      // Player hits triggerPlayerX
      player.position = Vector2(1890, 552);
      floor.update(0.016);
      expect(floor.isGapOpen, isTrue);
      expect(floor.gapLocalX, equals(0.0));

      // Floor updates and gap chases rightward
      floor.update(1.0); // 1s * 200px/s = 200px
      expect(floor.gapLocalX, closeTo(200.0, 1.0));

      // Advance past stopGapX
      floor.update(3.0);
      expect(floor.gapLocalX, equals(512.0));

      // Player falling inside gap does not receive floor collision
      player.position = Vector2(1840 + 512 + 40, 554); // Inside gap
      player.velocity.y = 100;
      player.isOnGround = false;
      floor.onCollision({player.position}, player);
      expect(player.isOnGround, isFalse); // No floor support in gap!

      // Reset
      floor.resetToInitial();
      expect(floor.isGapOpen, isFalse);
      expect(floor.isRevealed, isTrue);
      expect(floor.gapLocalX, equals(0.0));
    });

    test('MovingGapFloor in hesitation mode rewards commitment and punishes second-guessing', () async {
      final floor = MovingGapFloor(
        trapId: 'test_hesitation',
        position: Vector2(2760, 552),
        size: Vector2(824, 200),
        mode: MovingGapMode.hesitation,
        gapWidth: 92.0,
        activateRoomX: 2560.0,
        initialGapLocalX: 300.0,
        anchorGapLocalX: 420.0,
        proximityRangePx: 140.0,
      );
      game.world.add(floor);
      await floor.onLoad();

      // 1. Before entering room: gap closed
      player.position = Vector2(2400, 552);
      floor.update(0.1);
      expect(floor.isGapOpen, isFalse);

      // 2. Enter room: opens at initialGapLocalX
      player.position = Vector2(2570, 552);
      floor.update(0.016);
      expect(floor.isGapOpen, isTrue);
      expect(floor.gapLocalX, equals(300.0));

      // 3. Doubt creep advances gap toward anchorGapLocalX as player runs right
      player.position = Vector2(2850, 552);
      floor.update(0.016);
      expect(floor.gapLocalX, greaterThan(300.0));
      expect(floor.gapLocalX, lessThanOrEqualTo(420.0));

      // 4. Committed runner: holds moveRight into proximity and clears
      player.position = Vector2(3050, 552); // proximity zone [3040, 3180]
      player.moveRight();
      floor.update(0.05);
      expect(floor.isPunishing, isFalse);
      expect(floor.gapLocalX, equals(420.0));

      // Clear gap cleanly
      player.position = Vector2(3300, 552);
      floor.update(0.016);
      expect(floor.isPunishing, isFalse);

      // 5. Test hesitation punishment: stop inside proximity
      floor.resetToInitial();
      player.position = Vector2(2570, 552);
      floor.update(0.016);
      expect(floor.isGapOpen, isTrue);

      player.position = Vector2(3100, 552); // inside proximity zone
      player.moveRight();
      floor.update(0.016);
      expect(floor.isPunishing, isFalse);

      // Player second-guesses and stops
      player.stopMoving();
      floor.update(0.09); // dwells past 0.08s
      expect(floor.isPunishing, isTrue);

      // Punish snap surges gap toward player
      final gapBeforeSnap = floor.gapLocalX;
      floor.update(0.05);
      expect(floor.gapLocalX, isNot(equals(gapBeforeSnap)));

      // 6. Test pullback punishment: moveLeft triggers immediate punish
      floor.resetToInitial();
      player.position = Vector2(2570, 552);
      floor.update(0.016);
      player.position = Vector2(3120, 552);
      player.moveLeft();
      floor.update(0.016);
      expect(floor.isPunishing, isTrue);
    });

    test('Camera pans smoothly between rooms and snaps on checkpoint respawn', () {
      expect(game.roomCount, equals(3));
      expect(game.cameraFocus.x, equals(640.0));

      // Player in Room 1: camera targets 640
      player.position = Vector2(200, 552);
      game.update(0.1);
      expect(game.cameraFocus.x, equals(640.0));
      expect(game.controller.currentPlatform.value, equals(1));

      // Player steps into Room 2 (x = 1350)
      player.position = Vector2(1350, 552);
      expect(game.targetRoomCenterXFor(1350), equals(1920.0));

      // Camera begins easing toward 1920
      game.update(0.1);
      expect(game.cameraFocus.x, greaterThan(640.0));
      expect(game.cameraFocus.x, lessThan(1920.0));
      expect(game.controller.currentPlatform.value, equals(2));

      // Let easing finish
      game.update(0.5);
      expect(game.cameraFocus.x, equals(1920.0));

      // Player in death cycle freezes camera pan
      player.isDisintegrating = true;
      player.position = Vector2(2700, 552); // Room 3
      game.update(0.1);
      expect(game.cameraFocus.x, equals(1920.0)); // Frozen at Room 2!
      player.isDisintegrating = false;

      // Checkpoint respawn in Room 3 immediately snaps camera and platform
      game.lastCheckpointPosition = Vector2(2592, 552); // Room 3
      game.respawnPlayerAtCheckpoint(playReintegration: false);
      expect(game.cameraFocus.x, equals(3200.0));
      expect(game.camera.viewfinder.position.x, equals(3200.0));
      expect(game.controller.currentPlatform.value, equals(3));
    });

    test('Level 1 layout contains 3 platforms, 2 checkpoints, zero spikes, and zero coins', () async {
      final lvl1Game = TrapDashGame(initialLevelNumber: 1);
      await lvl1Game.onLoad();

      expect(lvl1Game.controller.config.roomCount, equals(3));
      expect(lvl1Game.controller.config.goalText, equals('Cross 3 Platforms & Reach the Exit in 90s'));
      expect(lvl1Game.startSpawnPosition.x, equals(148.0));
      expect(lvl1Game.exitX, equals(3688.0));

      // Verify zero spikes and coins
      final spikes = lvl1Game.world.children.whereType<TrapSpike>();
      final pickups = lvl1Game.world.children.whereType<PickupItem>();
      expect(spikes, isEmpty);
      expect(pickups, isEmpty);

      // Verify checkpoints
      final checkpoints = lvl1Game.world.children.whereType<CheckpointFlag>().toList();
      expect(checkpoints.length, equals(2));
      expect(checkpoints[0].checkpointId, equals(1));
      expect(checkpoints[0].position.x, equals(1312.0));
      expect(checkpoints[1].checkpointId, equals(2));
      expect(checkpoints[1].position.x, equals(2592.0));

      // Verify gaps
      final suddenGaps = lvl1Game.world.children.whereType<SuddenGap>().toList();
      final movingGaps = lvl1Game.world.children.whereType<MovingGapFloor>().toList();
      expect(suddenGaps.length, equals(3));
      expect(movingGaps.length, equals(2));

      // Verify Exit Portal
      final exits = lvl1Game.world.children.whereType<ExitPortal>().toList();
      expect(exits.length, equals(1));
      expect(exits.first.position.x, equals(3688.0));
    });
  });
}
