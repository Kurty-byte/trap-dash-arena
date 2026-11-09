import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trap_dash_arena/game/actors/checkpoint_flag.dart';
import 'package:trap_dash_arena/game/actors/exit_portal.dart';
import 'package:trap_dash_arena/game/actors/fake_floor.dart';
import 'package:trap_dash_arena/game/actors/moving_gap_floor.dart';
import 'package:trap_dash_arena/game/actors/pickup_item.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/actors/trap_spike.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Level 2 Connected Dungeon & Deceptive Spikes Tests', () {
    late TrapDashGame game;
    late Player player;

    setUp(() async {
      game = TrapDashGame(initialLevelNumber: 2);
      await game.onLoad();
      player = game.player;
    });

    test('Level 2 layout contains 3 rooms, 2 checkpoints, zero fake floors, zero keys', () async {
      expect(game.controller.config.roomCount, equals(3));
      expect(game.controller.config.requiredKeys, equals(0));
      expect(game.startSpawnPosition.x, equals(148.0));
      expect(game.exitX, equals(3688.0));

      // Zero cracking fake floors, zero keys or coins
      final fakeFloors = game.world.children.whereType<FakeFloor>();
      final pickups = game.world.children.whereType<PickupItem>();
      expect(fakeFloors, isEmpty);
      expect(pickups, isEmpty);

      // 2 checkpoints in dividing passages
      final checkpoints = game.world.children.whereType<CheckpointFlag>().toList();
      expect(checkpoints.length, equals(2));
      expect(checkpoints[0].checkpointId, equals(1));
      expect(checkpoints[0].position.x, equals(1312.0));
      expect(checkpoints[1].checkpointId, equals(2));
      expect(checkpoints[1].position.x, equals(2592.0));

      // 5 deceptive spikes
      final spikes = game.world.children.whereType<TrapSpike>().toList();
      expect(spikes.length, equals(5));

      // 2 moving gap floors (Platform 1 chase gap, Platform 3 hesitation gap)
      final gaps = game.world.children.whereType<MovingGapFloor>().toList();
      expect(gaps.length, equals(2));

      // Exit portal
      final exits = game.world.children.whereType<ExitPortal>().toList();
      expect(exits.length, equals(1));
      expect(exits.first.position.x, equals(3688.0));
    });

    test('Platform 1 MovingGapFloor opens on proximity but waits for chaseStartPlayerX to chase', () async {
      final gap = MovingGapFloor(
        trapId: 'test_p1_gap',
        position: Vector2(464, 552),
        size: Vector2(720, 200),
        mode: MovingGapMode.chase,
        gapWidth: 88.0,
        triggerPlayerX: 418.0,
        chaseStartPlayerX: 568.0,
        chaseSpeed: 215.0,
        stopGapX: 624.0,
      );
      game.world.add(gap);
      await gap.onLoad();

      // Before trigger
      player.position = Vector2(400, 552);
      gap.update(0.1);
      expect(gap.isGapOpen, isFalse);

      // Player reaches proximity trigger (418): gap opens at 0, but holds still
      player.position = Vector2(420, 552);
      gap.update(0.016);
      expect(gap.isGapOpen, isTrue);
      expect(gap.gapLocalX, equals(0.0));

      // Player in the air jumping over [464, 552] (e.g. at x = 500)
      player.position = Vector2(500, 500);
      player.isOnGround = false;
      gap.update(0.2);
      // Gap must stay at 0.0 so it never traps the jumping player!
      expect(gap.gapLocalX, equals(0.0));

      // Player lands on the right slab past chaseStartPlayerX (x >= 568)
      player.position = Vector2(570, 552);
      player.isOnGround = true;
      gap.update(0.1); // 0.1s * 215 px/s = 21.5 px
      expect(gap.gapLocalX, greaterThan(0.0));
      expect(gap.gapLocalX, closeTo(21.5, 1.0));

      // Reset restores stationary open state
      gap.resetToInitial();
      expect(gap.isGapOpen, isFalse);
      expect(gap.gapLocalX, equals(0.0));
    });

    test('Platform 2 slideRightOnJump spike slides right when jumped toward', () async {
      final spike = TrapSpike(
        trapId: 'test_slide_spike',
        position: Vector2(1780, 552),
        behavior: SpikeBehavior.slideRightOnJump,
        slideRightDistance: 96.0,
        slideSpeed: 460.0,
      );
      game.world.add(spike);
      await spike.onLoad();

      // Grounded player approaching does not trigger jump slide
      player.position = Vector2(1740, 552);
      player.isOnGround = true;
      spike.update(0.1);
      expect(spike.isTriggered, isFalse);
      expect(spike.position.x, equals(1780.0));

      // Jumping player in trigger zone triggers slide
      player.position = Vector2(1740, 500);
      player.isOnGround = false;
      spike.update(0.016);
      expect(spike.isTriggered, isTrue);

      // Spike slides right toward 1780 + 96 = 1876
      spike.update(0.1); // 0.1s * 460 = 46 px
      expect(spike.position.x, closeTo(1826.0, 2.0));

      // Finishes slide at 1876
      spike.update(0.5);
      expect(spike.position.x, equals(1876.0));

      // Retract resets to 1780
      spike.retract();
      expect(spike.isTriggered, isFalse);
      expect(spike.isRevealed, isFalse);
      expect(spike.position.x, equals(1780.0));
    });

    test('Platform 2 close pop-up spike stays hidden until tight proximity', () async {
      final spike = TrapSpike(
        trapId: 'test_close_popup',
        position: Vector2(2376, 552),
        behavior: SpikeBehavior.proximityPopUp,
        triggerDistance: 36.0,
        jitterDuration: 0.08,
        hideCompletelyWhenIdle: true,
      );
      game.world.add(spike);
      await spike.onLoad();

      // Distance 45px (> 36px) does not trigger
      player.position = Vector2(2376 - 45, 552);
      spike.update(0.05);
      expect(spike.isTriggered, isFalse);

      // Distance 30px (<= 36px) triggers
      player.position = Vector2(2376 - 30, 552);
      spike.update(0.016);
      expect(spike.isTriggered, isTrue);
    });

    test('Platform 3 riseOnProximity spike catches jumpers and allows walking under', () async {
      final spike = TrapSpike(
        trapId: 'test_rise_spike',
        position: Vector2(2864, 552),
        behavior: SpikeBehavior.riseOnProximity,
        triggerDistance: 76.0,
        riseHeight: 88.0,
        riseSpeed: 680.0,
      );
      game.world.add(spike);
      await spike.onLoad();

      // Trigger rise
      player.position = Vector2(2864 - 70, 552);
      spike.update(0.016);
      expect(spike.isTriggered, isTrue);

      // Rises to 552 - 88 = 464
      spike.update(0.3);
      expect(spike.position.y, equals(464.0));

      // Grounded walking player at floor y = 552 has head at 552 - 36 = 516
      // Spike bottom is at y = 464, leaving > 50px clearance!
      player.position = Vector2(2864, 552);
      player.isOnGround = true;
      expect(player.position.y - 36, greaterThan(spike.position.y));

      // Reset
      spike.retract();
      expect(spike.position.y, equals(552.0));
    });

    test('Platform 3 doubleSlideTrap slides right on approach and boomerangs left after landing', () async {
      final spike = TrapSpike(
        trapId: 'test_double_spike',
        position: Vector2(3484, 552),
        behavior: SpikeBehavior.doubleSlideTrap,
        triggerDistance: 56.0,
        slideRightDistance: 96.0,
        slideLeftDistance: 80.0,
        slideSpeed: 460.0,
        returnSlideSpeed: 480.0,
      );
      game.world.add(spike);
      await spike.onLoad();

      // 1. Approach triggers Phase 1: slide right
      player.position = Vector2(3484 - 50, 552);
      spike.update(0.016);
      expect(spike.isTriggered, isTrue);

      // Slide right completes to 3484 + 96 = 3580
      spike.update(0.3);
      expect(spike.position.x, equals(3580.0));

      // 2. Player jumped and strafed back left, landing on ground at x = 3520
      player.position = Vector2(3520, 552);
      player.isOnGround = true;

      // Phase 2 beat timer (0.06s)
      spike.update(0.07);

      // Phase 3 begins: slide back left toward 3484 - 80 = 3404
      spike.update(0.1);
      expect(spike.position.x, lessThan(3580.0));

      // Return slide completes to 3404
      spike.update(0.5);
      expect(spike.position.x, equals(3404.0));

      // Retract resets to initial position
      spike.retract();
      expect(spike.position.x, equals(3484.0));
      expect(spike.isTriggered, isFalse);
    });
  });
}
