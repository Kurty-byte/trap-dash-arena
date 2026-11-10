import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/components.dart';
import 'package:trap_dash_arena/game/actors/arsenal_cannon.dart';
import 'package:trap_dash_arena/game/actors/checkpoint_flag.dart';
import 'package:trap_dash_arena/game/actors/exit_portal.dart';
import 'package:trap_dash_arena/game/actors/ground_block.dart';
import 'package:trap_dash_arena/game/actors/moving_saw.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/actors/trap_spike.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Level 5 5-Platform Placeholder Sequence Tests', () {
    late TrapDashGame game;
    late Player player;

    setUp(() async {
      game = TrapDashGame(initialLevelNumber: 5);
      await game.onLoad();
      await game.ready();
      player = game.player;
    });

    test('Level 5 config contains 3 rooms, 2 checkpoints, 60s limit, 3 hearts', () async {
      expect(game.controller.config.roomCount, equals(3));
      expect(game.controller.config.requiredKeys, equals(0));
      expect(game.controller.config.timeLimit, equals(60.0));
      expect(game.controller.config.initialHearts, equals(3));
      expect(game.startSpawnPosition.x, equals(148.0));
      expect(game.startSpawnPosition.y, equals(552.0));
      expect(game.exitX, equals(3688.0));

      // 2 checkpoints in dividing passages
      final checkpoints = game.world.children.whereType<CheckpointFlag>().toList();
      expect(checkpoints.length, equals(2));
      expect(checkpoints[0].checkpointId, equals(1));
      expect(checkpoints[0].position.x, equals(1312.0));
      expect(checkpoints[1].checkpointId, equals(2));
      expect(checkpoints[1].position.x, equals(2592.0));

      // 1 Exit portal in Room 3
      final exits = game.world.children.whereType<ExitPortal>().toList();
      expect(exits.length, equals(1));
      expect(exits.first.position.x, equals(3688.0));
    });

    test('Platform 1 contains continuous floor, ArsenalCannon and DisableButton', () {
      final cannons = game.world.children.whereType<ArsenalCannon>().where((c) => c.position.x < 1280.0).toList();
      final buttons = game.world.children.whereType<DisableButton>().where((b) => b.position.x < 1280.0).toList();
      final floors = game.world.children.whereType<GroundBlock>().where((g) => g.position.y == 552.0 && g.position.x == 96.0).toList();

      expect(cannons.length, equals(1));
      expect(cannons.first.position.x, equals(1148.0));
      expect(cannons.first.position.y, equals(530.0));
      expect(cannons.first.rowPattern, equals(const [1, 2, 1, 2, 2, 1]));
      expect(cannons.first.rowPatternSets?.length, equals(3));

      expect(buttons.length, equals(1));
      expect(buttons.first.position.x, equals(1060.0));
      expect(buttons.first.position.y, equals(552.0));
      expect(buttons.first.targetCannon, equals(cannons.first));

      expect(floors.length, equals(1));
      expect(floors.first.size.x, equals(1280.0)); // continuous 96..1376
    });

    test('ArsenalCannon glides and fires according to [1, 2, 1, 2, 2, 1] pattern', () {
      final cannon = game.world.children.whereType<ArsenalCannon>().first;

      // Initial state: at Row 1 (530.0), step index 0
      expect(cannon.patternIndex, equals(0));
      expect(cannon.position.y, equals(530.0));

      // Player in Room 1 triggers cannon shot
      player.position = Vector2(500, 552);

      // Advance fireInterval (0.85s) -> fires Ball 1 at Row 1
      cannon.update(0.86);
      expect(cannon.patternIndex, equals(1));
      var balls = game.world.children.whereType<ArsenalBall>().toList();
      expect(balls.length, equals(1));
      expect(balls.first.position.y, equals(530.0));

      // Step index 1: glides to Row 2 (474.0)
      cannon.update(0.20);
      expect(cannon.position.y, lessThan(530.0));
      cannon.update(0.20);
      expect(cannon.position.y, equals(474.0));

      // Fires Ball 2 at Row 2
      cannon.update(0.86);
      expect(cannon.patternIndex, equals(2));
      balls = game.world.children.whereType<ArsenalBall>().toList();
      expect(balls.length, equals(2));
      expect(balls.last.position.y, equals(474.0));

      // Step index 2: glides back to Row 1 (530.0)
      cannon.update(0.30);
      expect(cannon.position.y, equals(530.0));
      cannon.update(0.86);
      expect(cannon.patternIndex, equals(3));

      // Step index 3: glides to Row 2 (474.0)
      cannon.update(0.30);
      expect(cannon.position.y, equals(474.0));
      cannon.update(0.86);
      expect(cannon.patternIndex, equals(4));

      // Step index 4: stays at Row 2 for double shot trap!
      cannon.update(0.10);
      expect(cannon.position.y, equals(474.0));
      cannon.update(0.86);
      expect(cannon.patternIndex, equals(5));

      // Step index 5: glides to Row 1 (530.0)
      cannon.update(0.30);
      expect(cannon.position.y, equals(530.0));
    });

    test('ArsenalBall Row 1 vs Row 2 clearance: Row 1 hits walker, Row 2 clears standing player and hits jumper', () {
      final ballRow1 = ArsenalBall(
        position: Vector2(500, 530),
      );
      final ballRow2 = ArsenalBall(
        position: Vector2(500, 474),
      );
      game.world.add(ballRow1);
      game.world.add(ballRow2);

      // Standing player at floor y = 552 (head at 516)
      player.position = Vector2(500, 552);
      player.isOnGround = true;
      player.update(0.60); // clear initial spawn invulnerability

      // Row 1 overlaps standing player
      final initialHearts = game.controller.hearts.value;
      ballRow1.onCollisionStart({Vector2(500, 530)}, player);
      expect(game.controller.hearts.value, equals(initialHearts - 1));

      // Standing player does not overlap Row 2 (head at 516 is below ball bottom at 485)
      player.respawnAt(Vector2(500, 552));
      expect(player.position.y - 36.0, greaterThan(ballRow2.position.y + 11.0)); // > 30px clearance!

      // Airborne jumping player at y = 480 overlaps Row 2 ball
      player.update(0.60); // clear respawn invulnerability
      player.position = Vector2(500, 480);
      player.isOnGround = false;
      ballRow2.onCollisionStart({Vector2(500, 474)}, player);
      expect(player.isDisintegrating, isTrue);
    });

    test('DisableButton disables cannon, clears balls, and respawn resets', () {
      final cannon = game.world.children.whereType<ArsenalCannon>().first;
      final button = game.world.children.whereType<DisableButton>().first;

      // Spawn a ball
      cannon.fireBall();
      expect(game.world.children.whereType<ArsenalBall>().length, equals(1));
      expect(cannon.isDisabled, isFalse);
      expect(button.isPressed, isFalse);

      // Step on button
      player.position = button.position.clone();
      button.onCollisionStart({button.position}, player);

      expect(button.isPressed, isTrue);
      expect(cannon.isDisabled, isTrue);
      // All in-flight balls cleared
      expect(game.world.children.whereType<ArsenalBall>(), isEmpty);

      // Cannon cannot fire while disabled
      cannon.update(2.0);
      expect(game.world.children.whereType<ArsenalBall>(), isEmpty);

      // Checkpoint respawn resets both
      game.respawnPlayerAtCheckpoint();
      expect(button.isPressed, isFalse);
      expect(cannon.isDisabled, isFalse);
    });

    test('Camera pans across 3 rooms and snaps on checkpoint respawn', () {
      expect(game.roomCount, equals(3));
      expect(game.cameraFocus.x, equals(640.0));

      // Room 1 (target 640)
      player.position = Vector2(200, 552);
      game.update(0.1);
      expect(game.cameraFocus.x, equals(640.0));
      expect(game.controller.currentPlatform.value, equals(1));

      // Room 2 (target 1920)
      player.position = Vector2(1500, 552);
      expect(game.targetRoomCenterXFor(1500), equals(1920.0));
      game.update(0.8);
      expect(game.cameraFocus.x, equals(1920.0));
      expect(game.controller.currentPlatform.value, equals(2));

      // Room 3 (target 3200)
      player.position = Vector2(2800, 552);
      expect(game.targetRoomCenterXFor(2800), equals(3200.0));
      game.update(0.8);
      expect(game.cameraFocus.x, equals(3200.0));
      expect(game.controller.currentPlatform.value, equals(3));

      // Checkpoint respawn at Passage 2 (2592, 552) snaps camera to 3200 (Room 3)
      game.lastCheckpointPosition = Vector2(2592, 552);
      game.respawnPlayerAtCheckpoint(playReintegration: false);
      expect(game.cameraFocus.x, equals(3200.0));
      expect(game.controller.currentPlatform.value, equals(3));
    });

    test('Rooms 1-3 have floor slabs and 2 passage roof dividers', () {
      final groundBlocks = game.world.children.whereType<GroundBlock>().toList();

      // Verify the 2 passage roofs (y = 104, height = 352)
      final roofs = groundBlocks.where((g) => g.position.y == 104.0 && g.size.y == 352.0).toList();
      expect(roofs.length, equals(2));
      expect(roofs.map((r) => r.position.x), containsAll([1184.0, 2464.0]));

      // Verify rooms 2 and 3 have ground slabs at y = 552
      final room2Slabs = groundBlocks.where((g) => g.position.y == 552.0 && g.position.x >= 1376.0 && g.position.x < 2656.0).toList();
      final room3Slabs = groundBlocks.where((g) => g.position.y == 552.0 && g.position.x >= 2656.0 && g.position.x <= 3744.0).toList();

      expect(room2Slabs.length, equals(4)); // 4 slabs separated by 3 pits
      expect(room3Slabs.length, equals(1)); // 1 continuous flat floor slab
      expect(room3Slabs.first.size.x, equals(1088.0)); // spans 2656..3744
    });

    test('Platform 2 contains 4 floor slabs separated by 3 pits with vertical MovingSaws at varying speeds', () {
      final room2Saws = game.world.children
          .whereType<MovingSaw>()
          .where((s) => s.pathStart.x >= 1376.0 && s.pathStart.x <= 2464.0)
          .toList()
        ..sort((a, b) => a.pathStart.x.compareTo(b.pathStart.x));

      expect(room2Saws.length, equals(3));

      // Saw 1: Pit 1 (1580..1668), x = 1624, speed = 160.0
      final saw1 = room2Saws[0];
      expect(saw1.pathStart.x, equals(1624.0));
      expect(saw1.pathEnd.x, equals(1624.0));
      expect(saw1.pathStart.y, equals(430.0));
      expect(saw1.pathEnd.y, equals(610.0));
      expect(saw1.speed, equals(160.0));

      // Saw 2: Pit 2 (1852..1940), x = 1896, speed = 260.0
      final saw2 = room2Saws[1];
      expect(saw2.pathStart.x, equals(1896.0));
      expect(saw2.pathEnd.x, equals(1896.0));
      expect(saw2.pathStart.y, equals(420.0));
      expect(saw2.pathEnd.y, equals(610.0));
      expect(saw2.speed, equals(260.0));

      // Saw 3: Pit 3 (2124..2212), x = 2168, speed = 360.0
      final saw3 = room2Saws[2];
      expect(saw3.pathStart.x, equals(2168.0));
      expect(saw3.pathEnd.x, equals(2168.0));
      expect(saw3.pathStart.y, equals(410.0));
      expect(saw3.pathEnd.y, equals(610.0));
      expect(saw3.speed, equals(360.0));

      // Escalating speeds
      expect(saw1.speed, lessThan(saw2.speed));
      expect(saw2.speed, lessThan(saw3.speed));
    });

    test('Platform 2 MovingSaws oscillate vertically, damage player, and reset on checkpoint respawn', () {
      final saw1 = game.world.children
          .whereType<MovingSaw>()
          .firstWhere((s) => s.pathStart.x == 1624.0);

      // Initial position at pathStart (y = 430)
      expect(saw1.position.x, equals(1624.0));
      expect(saw1.position.y, equals(430.0));

      // Advance time: stroke distance is 180px, speed is 160px/s -> after 0.5s y should increase
      saw1.update(0.5);
      expect(saw1.position.y, greaterThan(430.0));
      expect(saw1.position.y, lessThanOrEqualTo(610.0));

      // Damage player on collision
      player.position = saw1.position.clone();
      player.update(0.60); // clear spawn invulnerability
      final initialHearts = game.controller.hearts.value;
      saw1.onCollision({saw1.position}, player);
      expect(game.controller.hearts.value, equals(initialHearts - 1));

      // Checkpoint respawn resets saw to pathStart
      saw1.update(0.5);
      expect(saw1.position.y, isNot(equals(430.0)));
      game.respawnPlayerAtCheckpoint();
      expect(saw1.position.x, equals(1624.0));
      expect(saw1.position.y, equals(430.0));
    });

    test('Platform 3 contains flat continuous floor, deceptive proximity-jumping saw, ambush cannon, and button', () {
      final p3Floor = game.world.children
          .whereType<GroundBlock>()
          .where((g) => g.position.x == 2656.0 && g.position.y == 552.0)
          .first;
      expect(p3Floor.size.x, equals(1088.0));

      final p3Saws = game.world.children
          .whereType<MovingSaw>()
          .where((s) => s.pathStart.x > 2656.0 && s.pathStart.x < 3744.0)
          .toList();
      expect(p3Saws.length, equals(1));
      final saw = p3Saws.first;
      expect(saw.pathStart.x, equals(3540.0));
      expect(saw.pathStart.y, equals(552.0)); // half-submerged in floor
      expect(saw.pathEnd.x, equals(2740.0));
      expect(saw.pathEnd.y, equals(552.0));
      expect(saw.size.x, equals(64.0)); // radius 32.0
      expect(saw.speed, equals(260.0));
      expect(saw.proximityJumpPattern, equals(const [true, false, true, true, false]));
      expect(saw.proximityJumpPatternSets?.length, equals(3));

      final p3Cannons = game.world.children
          .whereType<ArsenalCannon>()
          .where((c) => c.trapId == 'l5_p3_arsenal')
          .toList();
      expect(p3Cannons.length, equals(1));
      final cannon = p3Cannons.first;
      expect(cannon.position.x, equals(3590.0));
      expect(cannon.position.y, equals(596.0)); // hidden below
      expect(cannon.isRevealed, isFalse);
      expect(cannon.rowPattern, equals(const [2, 1, 2, 1, 1, 2]));
      expect(cannon.rowPatternSets?.length, equals(3));
      expect(cannon.triggerPlayerX, equals(2960.0));
      expect(cannon.fireInterval, equals(0.45)); // faster shooting
      expect(cannon.ballSpeed, equals(420.0));

      final p3Buttons = game.world.children
          .whereType<DisableButton>()
          .where((b) => b.trapId == 'l5_p3_button')
          .toList();
      expect(p3Buttons.length, equals(1));
      expect(p3Buttons.first.position.x, equals(3510.0));
      expect(p3Buttons.first.targetCannon, equals(cannon));

      // Door spikes
      final frontSpike = game.world.children
          .whereType<TrapSpike>()
          .firstWhere((s) => s.trapId == 'l5_p3_spike_front');
      expect(frontSpike.position.x, equals(3648.0));
      expect(frontSpike.behavior, equals(SpikeBehavior.proximityPopUp));

      final backSpike = game.world.children
          .whereType<TrapSpike>()
          .firstWhere((s) => s.trapId == 'l5_p3_spike_back');
      expect(backSpike.position.x, equals(3724.0));
      expect(backSpike.behavior, equals(SpikeBehavior.proximityPopUp));
    });

    test('Platform 3 MovingSaw jumps on proximity beat 1 (up) and clears walking player, stays low on beat 2 (low)', () {
      final saw = game.world.children
          .whereType<MovingSaw>()
          .firstWhere((s) => s.pathStart.x == 3540.0);

      expect(saw.proximityPatternIndex, equals(0));
      expect(saw.position.y, equals(552.0)); // half submerged in floor

      // Player at x = 3400, saw positioned at x = 3515 (distance 115 <= 120)
      player.position = Vector2(3400, 552);
      saw.position = Vector2(3515, 552);

      // Trigger beat 0 (true -> up)
      saw.update(0.12);
      expect(saw.proximityPatternIndex, equals(1));
      expect(saw.position.y, lessThan(500.0)); // jumped up from floor!

      // Peak jump: saw center at ~454, bottom at 486. Walking player head at 514 (floor 552 - 38)
      saw.update(0.13);
      expect(saw.position.y, lessThanOrEqualTo(460.0));
      expect(player.position.y - 38.0, greaterThan(saw.position.y + 24.0)); // clearance underneath!

      // Move saw away beyond proximity zone (dist > 168)
      saw.position = Vector2(3700, 552);
      saw.update(0.5);

      // Approach player again (distance 100 <= 120) to trigger beat 1 (false -> low)
      saw.position = Vector2(3500, 552);
      saw.update(0.05);
      expect(saw.proximityPatternIndex, equals(2));
      expect(saw.position.y, equals(552.0)); // remains half-submerged in floor!

      // Respawn at checkpoint resets pattern index
      game.respawnPlayerAtCheckpoint();
      expect(saw.proximityPatternIndex, equals(0));
      expect(saw.position.x, equals(3540.0));
      expect(saw.position.y, equals(552.0));
    });

    test('Platform 3 ambush ArsenalCannon stays hidden until player.x >= 2960, emerges, and disables via button', () {
      final cannon = game.world.children
          .whereType<ArsenalCannon>()
          .firstWhere((c) => c.trapId == 'l5_p3_arsenal');
      final button = game.world.children
          .whereType<DisableButton>()
          .firstWhere((b) => b.trapId == 'l5_p3_button');

      // Player enters Room 3 at 2700 (< 2960) -> cannon stays hidden
      player.position = Vector2(2700, 552);
      cannon.update(0.5);
      expect(cannon.isRevealed, isFalse);
      expect(cannon.position.y, equals(596.0));

      // Player crosses trigger distance (2965 >= 2960)
      player.position = Vector2(2965, 552);
      cannon.update(0.05);
      expect(cannon.isRevealed, isTrue);

      // Cannon emerges upward toward rowPattern[0] (which is row 2 = 474.0)
      cannon.update(0.28);
      expect(cannon.position.y, equals(474.0));

      // Fires ball from row 2
      cannon.update(0.30);
      final balls = game.world.children.whereType<ArsenalBall>().toList();
      expect(balls.isNotEmpty, isTrue);
      expect(balls.last.position.y, equals(474.0));

      // Stepping on Room 3 button disables this cannon
      player.position = button.position.clone();
      button.onCollisionStart({button.position}, player);
      expect(cannon.isDisabled, isTrue);

      // Respawn resets cannon to hidden below
      game.respawnPlayerAtCheckpoint();
      expect(cannon.isRevealed, isFalse);
      expect(cannon.isDisabled, isFalse);
      expect(cannon.position.y, equals(596.0));
    });

    test('MovingSaw and ArsenalCannon cycle to next pattern set on each checkpoint respawn', () {
      final saw = game.world.children
          .whereType<MovingSaw>()
          .firstWhere((s) => s.pathStart.x == 3540.0);
      final p1Cannon = game.world.children
          .whereType<ArsenalCannon>()
          .firstWhere((c) => c.trapId == 'l5_p1_arsenal');
      final p3Cannon = game.world.children
          .whereType<ArsenalCannon>()
          .firstWhere((c) => c.trapId == 'l5_p3_arsenal');

      // Initial Spawn: Set 0
      expect(saw.activePatternSetIndex, equals(0));
      expect(saw.activeProximityJumpPattern, equals(const [true, false, true, true, false]));
      expect(p1Cannon.activePatternSetIndex, equals(0));
      expect(p1Cannon.activeRowPattern, equals(const [1, 2, 1, 2, 2, 1]));
      expect(p3Cannon.activePatternSetIndex, equals(0));
      expect(p3Cannon.activeRowPattern, equals(const [2, 1, 2, 1, 1, 2]));

      // Respawn 1: Advances to Set 1
      game.respawnPlayerAtCheckpoint();
      expect(saw.activePatternSetIndex, equals(1));
      expect(saw.activeProximityJumpPattern, equals(const [false, true, false, false, true]));
      expect(p1Cannon.activePatternSetIndex, equals(1));
      expect(p1Cannon.activeRowPattern, equals(const [2, 1, 1, 2, 1, 2]));
      expect(p3Cannon.activePatternSetIndex, equals(1));
      expect(p3Cannon.activeRowPattern, equals(const [1, 1, 2, 1, 2, 2]));

      // Respawn 2: Advances to Set 2
      game.respawnPlayerAtCheckpoint();
      expect(saw.activePatternSetIndex, equals(2));
      expect(saw.activeProximityJumpPattern, equals(const [false, false, true, false, true]));
      expect(p1Cannon.activePatternSetIndex, equals(2));
      expect(p1Cannon.activeRowPattern, equals(const [1, 1, 2, 2, 1, 2]));
      expect(p3Cannon.activePatternSetIndex, equals(2));
      expect(p3Cannon.activeRowPattern, equals(const [2, 2, 1, 2, 1, 1]));

      // Respawn 3: Loops back to Set 0
      game.respawnPlayerAtCheckpoint();
      expect(saw.activePatternSetIndex, equals(0));
      expect(saw.activeProximityJumpPattern, equals(const [true, false, true, true, false]));
      expect(p1Cannon.activePatternSetIndex, equals(0));
      expect(p1Cannon.activeRowPattern, equals(const [1, 2, 1, 2, 2, 1]));
      expect(p3Cannon.activePatternSetIndex, equals(0));
      expect(p3Cannon.activeRowPattern, equals(const [2, 1, 2, 1, 1, 2]));
    });

    test('ExitPortal front and back TrapSpikes pop up on proximity and reset on respawn', () {
      final frontSpike = game.world.children
          .whereType<TrapSpike>()
          .firstWhere((s) => s.trapId == 'l5_p3_spike_front');
      final backSpike = game.world.children
          .whereType<TrapSpike>()
          .firstWhere((s) => s.trapId == 'l5_p3_spike_back');

      // Both spikes idle
      expect(frontSpike.isTriggered, isFalse);
      expect(frontSpike.isExtended, isFalse);
      expect(backSpike.isTriggered, isFalse);
      expect(backSpike.isExtended, isFalse);

      // Player approaches front spike (3648 - 40 = 3608, dist 40 <= 42)
      player.position = Vector2(3610, 552);
      frontSpike.update(0.01);
      expect(frontSpike.isTriggered, isTrue);
      // Completes jitter (0.08s) -> extends
      frontSpike.update(0.09);
      expect(frontSpike.isExtended, isTrue);

      // Player clears front spike and moves past door to behind door (3724 - 35 = 3689, dist 35 <= 40)
      player.position = Vector2(3695, 552);
      backSpike.update(0.01);
      expect(backSpike.isTriggered, isTrue);
      backSpike.update(0.09);
      expect(backSpike.isExtended, isTrue);

      // Checkpoint respawn resets both spikes to un-armed
      game.respawnPlayerAtCheckpoint();
      expect(frontSpike.isTriggered, isFalse);
      expect(frontSpike.isExtended, isFalse);
      expect(backSpike.isTriggered, isFalse);
      expect(backSpike.isExtended, isFalse);
    });

    test('Level05.tmx contains MovingSaw objects and matches programmatic chamber', () {
      final tmxFile = File('assets/tiles/Level05.tmx');
      expect(tmxFile.existsSync(), isTrue);
      final content = tmxFile.readAsStringSync();

      expect(content.contains('roomCount" type="int" value="3"'), isTrue);
      expect(content.contains('name="MovingSaw"'), isTrue);
      expect(content.contains('x="1624" y="430"'), isTrue);
      expect(content.contains('x="1896" y="420"'), isTrue);
      expect(content.contains('x="2168" y="410"'), isTrue);
      expect(content.contains('value="160.0"'), isTrue);
      expect(content.contains('value="260.0"'), isTrue);
      expect(content.contains('value="360.0"'), isTrue);

      // Room 3 objects in Level05.tmx
      expect(content.contains('x="3540" y="552"'), isTrue);
      expect(content.contains('value="32.0"'), isTrue);
      expect(content.contains('value="up,low,up,up,low;low,up,low,low,up;low,low,up,low,up"'), isTrue);
      expect(content.contains('x="3590" y="530"'), isTrue);
      expect(content.contains('value="2,1,2,1,1,2;1,1,2,1,2,2;2,2,1,2,1,1"'), isTrue);
      expect(content.contains('value="0.45"'), isTrue);
      expect(content.contains('value="2960.0"'), isTrue);
      expect(content.contains('x="3510" y="552"'), isTrue);
      expect(content.contains('x="3688" y="552"'), isTrue);

      // Front & Back Door Spikes in Level05.tmx
      expect(content.contains('x="3648" y="552"'), isTrue);
      expect(content.contains('x="3724" y="552"'), isTrue);
      expect(content.contains('value="proximityPopUp"'), isTrue);
    });
  });
}
