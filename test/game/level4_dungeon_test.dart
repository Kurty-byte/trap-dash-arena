import 'dart:io';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trap_dash_arena/game/actors/checkpoint_flag.dart';
import 'package:trap_dash_arena/game/actors/exit_portal.dart';
import 'package:trap_dash_arena/game/actors/falling_block.dart';
import 'package:trap_dash_arena/game/actors/ground_block.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/actors/portal_gauntlet_controller.dart';
import 'package:trap_dash_arena/game/actors/trap_spike.dart';
import 'package:trap_dash_arena/game/actors/warp_portal.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Level 4 Deceptive Warp Portal Gauntlet Tests', () {
    late TrapDashGame game;
    late Player player;

    setUp(() async {
      game = TrapDashGame(initialLevelNumber: 4);
      await game.onLoad();
      await game.ready();
      player = game.player;
    });

    test('Level 4 layout contains 3 rooms, 2 checkpoints, 5 WarpPortals, 1 GauntletController', () async {
      expect(game.controller.config.roomCount, equals(3));
      expect(game.controller.config.timeLimit, equals(60.0));
      expect(game.controller.config.initialHearts, equals(3));
      expect(game.controller.config.requiredKeys, equals(0));
      expect(game.startSpawnPosition.x, equals(140.0));
      expect(game.startSpawnPosition.y, equals(420.0));
      expect(game.exitX, equals(3620.0));

      // 2 checkpoints in dividing passages
      final checkpoints = game.world.children.whereType<CheckpointFlag>().toList();
      expect(checkpoints.length, equals(2));
      expect(checkpoints[0].checkpointId, equals(1));
      expect(checkpoints[0].position.x, equals(1312.0));
      expect(checkpoints[1].checkpointId, equals(2));
      expect(checkpoints[1].position.x, equals(2592.0));

      // 5 WarpPortals across Platform 1 and 2
      final warps = game.world.children.whereType<WarpPortal>().toList();
      expect(warps.length, equals(5));

      // 1 PortalGauntletController on Platform 3
      final controllers = game.world.children.whereType<PortalGauntletController>().toList();
      expect(controllers.length, equals(1));

      // 1 Floating ExitPortal and 1 Solid Exit Ledge
      final exits = game.world.children.whereType<ExitPortal>().toList();
      expect(exits.length, equals(1));
      expect(exits.first.position.x, equals(3620.0));
      expect(exits.first.position.y, equals(400.0));
      final exitLedges = game.world.children.whereType<GroundBlock>().where((g) => g.position.x == 3556.0 && g.position.y == 400.0).toList();
      expect(exitLedges.length, equals(1));
      expect(exitLedges.first.size.x, equals(112.0));
    });

    test('Platform 1 Pillar Conditioning and Gap 3 Betrayal Warp', () async {
      final warp1 = game.world.children.whereType<WarpPortal>().firstWhere((w) => w.trapId == 'l4_p1_warp1');
      final p1Spike = game.world.children.whereType<TrapSpike>().firstWhere((s) => s.trapId == 'l4_p1_pillar1_spike');
      final warp2 = game.world.children.whereType<WarpPortal>().firstWhere((w) => w.trapId == 'l4_p1_warp2');
      final p2Spike = game.world.children.whereType<TrapSpike>().firstWhere((s) => s.trapId == 'l4_p1_pillar2_spike');
      final warp3 = game.world.children.whereType<WarpPortal>().firstWhere((w) => w.trapId == 'l4_p1_warp3_trap');

      expect(p1Spike.isExtended, isFalse);
      expect(p2Spike.isExtended, isFalse);

      // 1. Fall into Gap 1 Warp -> Teleports to Pillar 2 (x=400, y=420) and raises Pillar 1 spike
      warp1.onCollisionStart({Vector2(270, 624)}, player);
      expect(player.position.x, equals(400.0));
      expect(player.position.y, equals(420.0));
      expect(p1Spike.isExtended, isTrue);

      // 2. Fall into Gap 2 Warp -> Teleports to Pillar 3 (x=660, y=420) and raises Pillar 2 spike
      warp2.onCollisionStart({Vector2(530, 624)}, player);
      expect(player.position.x, equals(660.0));
      expect(player.position.y, equals(420.0));
      expect(p2Spike.isExtended, isTrue);

      // 3. Fall into Gap 3 Betrayal Warp -> Teleports onto active Pillar 1 spike (x=140, y=420)!
      warp3.onCollisionStart({Vector2(745, 624)}, player);
      expect(player.position.x, equals(140.0));
      expect(player.position.y, equals(420.0));
      // Player is at same position as p1Spike which is active
      expect(p1Spike.isExtended, isTrue);
    });

    test('Platform 2 Void Bridge Warp shifts left and right on proximity with easing, inverts controls, and fleeing warp restores controls', () async {
      final bridgeWarp = game.world.children.whereType<WarpPortal>().firstWhere((w) => w.trapId == 'l4_p2_bridge_warp');
      final upperWarp = game.world.children.whereType<WarpPortal>().firstWhere((w) => w.trapId == 'l4_p2_upper_warp');
      final initialBridgeWarpX = bridgeWarp.position.x;

      // 1. Player approaches left bridge ledge (x = 1630, grounded) -> warp starts easing left
      player.position.setValues(1630.0, 552.0);
      player.isOnGround = true;
      bridgeWarp.update(0.016);
      expect(bridgeWarp.isShifting, isTrue);

      // Mid-ease check at ~0.11s
      bridgeWarp.update(0.094);
      expect(bridgeWarp.position.x, lessThan(initialBridgeWarpX));
      expect(bridgeWarp.position.x, greaterThan(initialBridgeWarpX - 38.0));

      // Ease completes (total > 0.22s)
      bridgeWarp.update(0.15);
      expect(bridgeWarp.isShifting, isFalse);
      expect(bridgeWarp.position.x, equals(initialBridgeWarpX - 38.0));

      // 2. Pass 1: Entering bridge warp teleports to Right Bridge (1910, 552)
      bridgeWarp.onCollisionStart({bridgeWarp.position}, player);
      expect(player.position.x, equals(1910.0));
      expect(player.position.y, equals(552.0));
      expect(player.controlsInverted, isFalse);

      // Advance cooldown
      bridgeWarp.update(0.60);

      // 3. Player moves left on Right Bridge (x = 1870, grounded) -> warp starts easing right
      player.position.setValues(1870.0, 552.0);
      player.isOnGround = true;
      bridgeWarp.update(0.016);
      expect(bridgeWarp.isShifting, isTrue);

      // Mid-ease check
      bridgeWarp.update(0.094);
      expect(bridgeWarp.position.x, greaterThan(initialBridgeWarpX - 38.0));
      expect(bridgeWarp.position.x, lessThan(initialBridgeWarpX));

      // Ease completes
      bridgeWarp.update(0.15);
      expect(bridgeWarp.isShifting, isFalse);
      expect(bridgeWarp.position.x, equals(initialBridgeWarpX));

      // 4. Pass 2: Entering bridge warp teleports to Upper Platform (1740, 340) and inverts controls
      bridgeWarp.onCollisionStart({bridgeWarp.position}, player);
      expect(player.position.x, equals(1740.0));
      expect(player.position.y, equals(340.0));
      expect(player.controlsInverted, isTrue);

      // 5. Approaching fleeing warp on shortened upper platform causes it to snap left to 1668
      expect(upperWarp.position.x, equals(1868.0));
      player.position.setValues(1768.0, 340.0);
      upperWarp.update(0.016);
      expect(upperWarp.position.x, equals(1668.0));

      // 6. Entering fleeing warp teleports to Passage 2 floor (2360, 552) and un-inverts controls
      upperWarp.onCollisionStart({upperWarp.position}, player);
      expect(player.position.x, equals(2360.0));
      expect(player.position.y, equals(552.0));
      expect(player.controlsInverted, isFalse);
    });

    test('Platform 3 Gauntlet Step 0 Boarding and 5-Step Safe Sequence [L, R, R, L, R]', () async {
      final controller = game.world.children.whereType<PortalGauntletController>().first;
      expect(controller.step, equals(0));
      expect(controller.mainBox.size, equals(Vector2(56, 56)));

      // Verify all wrong-choice elements start hidden/inactive
      expect(controller.isolatedBox.isActive, isFalse);
      expect(controller.isolatedDelayedSpike.isActive, isFalse);
      expect(controller.doorTrapSpike.isActive, isFalse);
      expect(controller.crushBlock.isTriggered, isFalse);
      expect(controller.rideSpike1.isActive, isFalse);
      expect(controller.rideSpike2.isActive, isFalse);

      // Step 0 Boarding: jump into Left Portal below mainBox
      controller.onPortalEntered(GauntletChoice.left, controller.leftPortal);
      expect(controller.step, equals(1));
      expect(player.position.x, equals(controller.mainBox.position.x + 28.0));
      expect(player.position.y, equals(controller.mainBox.position.y));

      // Advance cooldown
      controller.update(0.60);

      // Step 1: Safe choice is Left
      controller.onPortalEntered(GauntletChoice.left, controller.leftPortal);
      expect(controller.step, equals(2));
      expect(controller.mainBoxTargetX, greaterThan(controller.mainBoxInitialPos.x));

      // Player sticks to moving platform and travels with it
      controller.update(0.80);
      expect(controller.mainBox.position.x, equals(controller.mainBoxTargetX));
      expect(player.position.x, equals(controller.mainBox.position.x + 28.0));
      expect(player.position.y, equals(controller.mainBox.position.y));

      // On Step 2, jumping off left edge smoothly dodges left portal away
      player.position.setValues(controller.mainBox.position.x - 4.0, controller.mainBox.position.y + 10.0);
      player.isOnGround = false;
      controller.update(0.016);
      expect(controller.leftPortal.position.x, lessThan(controller.mainBox.position.x - 12.0));
      // Full dodge duration (0.18s)
      controller.update(0.20);
      expect(controller.leftPortal.position.x, equals(controller.mainBox.position.x - 12.0 - 240.0));

      // Step 2: Safe choice is Right -> resets left portal back to normal under-box position
      controller.onPortalEntered(GauntletChoice.right, controller.rightPortal);
      expect(controller.step, equals(3));
      expect(controller.leftPortal.position.x, equals(controller.mainBox.position.x - 12.0));

      controller.update(0.80);
      expect(player.position.x, equals(controller.mainBox.position.x + 28.0));

      // Step 3: Safe choice is Right
      controller.onPortalEntered(GauntletChoice.right, controller.rightPortal);
      expect(controller.step, equals(4));

      controller.update(0.60);

      // Step 4: Safe choice is Left
      controller.onPortalEntered(GauntletChoice.left, controller.leftPortal);
      expect(controller.step, equals(5));

      controller.update(0.60);

      // Step 5: Safe choice is Right -> parks at 3500.0, flush with Exit Ledge at 3556 (56px mainBox width)
      controller.onPortalEntered(GauntletChoice.right, controller.rightPortal);
      expect(controller.step, equals(6));
      expect(controller.mainBoxTargetX, equals(controller.mainBoxInitialPos.x + 5 * 144.0));
      expect(controller.mainBoxTargetX, equals(3500.0));
    });

    test('Platform 3 Gauntlet Wrong Choices 1, 3, 4, 5 reveal only necessary elements on demand', () async {
      final controller = game.world.children.whereType<PortalGauntletController>().first;

      // Board to Step 1
      controller.onPortalEntered(GauntletChoice.left, controller.leftPortal);
      controller.update(0.60);
      expect(controller.step, equals(1));

      // Wrong choice at Step 1 (picks Right): reveals door spike on Exit Ledge and teleports player
      controller.onPortalEntered(GauntletChoice.right, controller.rightPortal);
      expect(player.position.x, equals(3580.0));
      expect(player.position.y, equals(400.0));
      expect(controller.doorTrapSpike.isActive, isTrue);
      expect(controller.doorTrapSpike.isExtended, isTrue);
      expect(controller.isolatedBox.isActive, isFalse);

      // Reset for Step 2 test
      controller.resetToInitial();
      controller.step = 2;
      controller.update(0.60);

      // Wrong choice at Step 2 (picks Left): triggers pit fall damage
      controller.onPortalEntered(GauntletChoice.left, controller.leftPortal);
      expect(player.isDisintegrating, isTrue);

      // Reset for Step 3 test
      player.isDisintegrating = false;
      controller.resetToInitial();
      expect(controller.doorTrapSpike.isActive, isFalse);
      controller.step = 3;
      controller.update(0.60);

      // Wrong choice at Step 3 (picks Left): reveals isolated box & delayed spike (0.45s delay)
      controller.onPortalEntered(GauntletChoice.left, controller.leftPortal);
      expect(controller.isolatedBox.isActive, isTrue);
      expect(controller.isolatedDelayedSpike.isActive, isTrue);
      expect(player.position.x, equals(controller.isolatedBox.position.x + 28.0));
      expect(controller.isolatedDelayedSpike.isExtended, isFalse);
      controller.update(0.50); // 0.45s delay passes
      expect(controller.isolatedDelayedSpike.isExtended, isTrue);

      // Reset for Step 4 test
      controller.resetToInitial();
      expect(controller.isolatedBox.isActive, isFalse);
      controller.step = 4;
      controller.update(0.60);

      // Wrong choice at Step 4 (picks Right): reveals & triggers ceiling crush block
      controller.onPortalEntered(GauntletChoice.right, controller.rightPortal);
      expect(controller.crushBlock.isTriggered, isTrue);

      // Reset for Step 5 test
      controller.resetToInitial();
      expect(controller.crushBlock.isTriggered, isFalse);
      controller.step = 5;
      controller.update(0.60);

      // Wrong choice at Step 5 (picks Left): reveals step5Platform and 2 rushing spikes
      controller.onPortalEntered(GauntletChoice.left, controller.leftPortal);
      expect(controller.step5Platform.isActive, isTrue);
      expect(controller.rideSpike1.isActive, isTrue);
      expect(controller.rideSpike2.isActive, isTrue);
      expect(player.position.x, equals(3148.0));
      expect(player.position.y, equals(240.0));

      // Finish player warp so spikes rush
      player.update(0.80);
      await Future<void>.delayed(Duration.zero);
      expect(player.isWarping, isFalse);

      final initialSpike1X = controller.rideSpike1.position.x;
      controller.update(0.10);
      expect(controller.rideSpike1.position.x, lessThan(initialSpike1X));
    });

    test('Player can jump while mainBox is gliding without jump velocity being cancelled', () async {
      final controller = game.world.children.whereType<PortalGauntletController>().first;
      controller.step = 1;
      controller.mainBox.position.setFrom(controller.mainBoxInitialPos);
      controller.mainBoxTargetX = controller.mainBoxInitialPos.x + 144.0;

      // Player jumps upward (velocity.y < 0)
      player.position.setValues(controller.mainBox.position.x + 28.0, controller.mainBox.position.y - 4.0);
      player.velocity.y = -400.0;
      player.isOnGround = false;

      // Update controller while player is mid-air
      controller.update(0.05);

      // Verify jump velocity was preserved and not zeroed out
      expect(player.velocity.y, equals(-400.0));
      expect(player.isOnGround, isFalse);
    });

    test('FallingBlock damages player when landing at groundY overlapping player', () async {
      final block = FallingBlock(
        trapId: 'test_crush',
        position: Vector2(200, 104),
        groundY: 400,
        size: Vector2(64, 48),
        manualTriggerOnly: true,
      );
      game.world.add(block);
      await game.ready();

      player.position.setValues(220, 400); // standing at groundY
      player.update(0.60); // clear initial spawn invulnerability
      final initialHearts = game.controller.hearts.value;

      block.triggerFall();
      block.update(0.26); // trigger telegraph passes
      block.update(0.60); // block falls down to groundY (position.y = 352, height 48 -> lands at 400)

      expect(block.hasLanded, isTrue);
      expect(game.controller.hearts.value, equals(initialHearts - 1));
    });

    test('WarpPortal and GauntletPortal trigger two-phase slow warp effect and hold traps until finish', () async {
      final warp1 = game.world.children.whereType<WarpPortal>().firstWhere((w) => w.trapId == 'l4_p1_warp1');
      player.position = Vector2(270, 624);

      // 1. WarpPortal collision activates warp effect
      warp1.onCollisionStart({Vector2(270, 624)}, player);
      expect(player.isWarpDisintegrating, isTrue);
      expect(player.isWarping, isTrue);
      expect(player.position.x, equals(400.0));
      expect(player.position.y, equals(420.0));

      // Finish warp1
      player.update(1.25);
      await Future<void>.delayed(Duration.zero);
      expect(player.isWarping, isFalse);

      // 2. GauntletPortal boarding activates warp effect
      final controller = game.world.children.whereType<PortalGauntletController>().first;
      controller.onPortalEntered(GauntletChoice.left, controller.leftPortal);
      expect(player.isWarpDisintegrating, isTrue);
      expect(player.isWarping, isTrue);
      expect(player.isOnGround, isTrue);

      // Finish boarding warp
      player.update(1.25);
      await Future<void>.delayed(Duration.zero);
      expect(player.isWarping, isFalse);

      // Advance cooldown
      controller.update(0.60);

      // 3. Gauntlet Step 4 Wrong Choice holds crush block from falling while player is warping
      controller.step = 4;
      controller.onPortalEntered(GauntletChoice.right, controller.rightPortal);
      expect(player.isWarpDisintegrating, isTrue);
      expect(controller.crushBlock.isTriggered, isTrue);

      // Update falling block while player is still warping (0.20s of 0.70s total)
      controller.crushBlock.update(0.20);
      expect(controller.crushBlock.isFalling, isFalse);

      // Finish warp (0.80s)
      player.update(0.80);
      await Future<void>.delayed(Duration.zero);
      expect(player.isWarping, isFalse);

      // Now after warp completes, telegraph timer elapses and block falls
      controller.crushBlock.update(0.30);
      expect(controller.crushBlock.isFalling, isTrue);
    });

    test('Platform 1 Warp 1 destination on Pillar 2 does not trigger p2Spike while warping or upon arrival', () async {
      final warp1 = game.world.children.whereType<WarpPortal>().firstWhere((w) => w.trapId == 'l4_p1_warp1');
      final p2Spike = game.world.children.whereType<TrapSpike>().firstWhere((s) => s.trapId == 'l4_p1_pillar2_spike');

      expect(p2Spike.isExtended, isFalse);
      expect(p2Spike.isTriggered, isFalse);

      // Enter warp 1
      warp1.onCollisionStart({Vector2(270, 624)}, player);
      expect(player.isWarping, isTrue);

      // Advance through disintegration (0.20s of 0.35s)
      player.update(0.20);
      p2Spike.update(0.20);
      expect(p2Spike.isTriggered, isFalse);
      expect(p2Spike.isExtended, isFalse);

      // Advance into reintegration (0.20s + 0.25s = 0.45s >= 0.35s)
      player.update(0.25);
      p2Spike.update(0.25);
      expect(p2Spike.isTriggered, isFalse);
      expect(p2Spike.isExtended, isFalse);

      // Complete warp (total 0.80s >= 0.70s)
      player.update(0.35);
      p2Spike.update(0.35);
      expect(player.isWarping, isFalse);

      // Player must be alive and p2Spike must remain retracted on Pillar 2!
      expect(p2Spike.isExtended, isFalse);
      expect(player.isInDeathCycle, isFalse);
      expect(player.isDisintegrating, isFalse);
    });

    test('Checkpoint respawn resets all warps and gauntlet state', () async {
      final bridgeWarp = game.world.children.whereType<WarpPortal>().firstWhere((w) => w.trapId == 'l4_p2_bridge_warp');
      final controller = game.world.children.whereType<PortalGauntletController>().first;

      // Alter states
      bridgeWarp.onCollisionStart({bridgeWarp.position}, player);
      controller.step = 4;

      // Respawn
      game.respawnPlayerAtCheckpoint();

      expect(bridgeWarp.useCount, equals(0));
      expect(controller.step, equals(0));
      expect(player.controlsInverted, isFalse);
    });

    test('WarpPortal resolves postWarpSpikeTrapId dynamically and activates linked spike upon entry', () async {
      final targetSpike = TrapSpike(
        trapId: 'test_spike_target',
        position: Vector2(500, 400),
        behavior: SpikeBehavior.proximityPopUp,
        hideCompletelyWhenIdle: true,
        triggerDistance: 0.0,
      );
      game.world.add(targetSpike);

      final portal = WarpPortal(
        trapId: 'test_warp_portal',
        position: Vector2(200, 600),
        targetPosition: Vector2(300, 400),
        postWarpSpikeTrapId: 'test_spike_target',
      );
      game.world.add(portal);
      await game.ready();

      expect(targetSpike.isExtended, isFalse);
      expect(portal.postWarpSpikeToActivate, isNull);

      // Resolve post-warp spike
      final resolved = portal.resolvePostWarpSpike();
      expect(resolved, equals(targetSpike));
      expect(portal.postWarpSpikeToActivate, equals(targetSpike));

      // Collision triggers warp and raises spike
      portal.onCollisionStart({portal.position}, player);
      expect(targetSpike.isExtended, isTrue);
    });

    test('Level04.tmx contains WarpPortals, TrapSpikes, and postWarpSpike wiring matching programmatic chamber', () {
      final tmxFile = File('assets/tiles/Level04.tmx');
      expect(tmxFile.existsSync(), isTrue);
      final content = tmxFile.readAsStringSync();

      expect(content.contains('roomCount" type="int" value="3"'), isTrue);
      expect(content.contains('timeLimit" type="float" value="60.0"'), isTrue);

      // Platform 1 spikes and warps with postWarpSpike wiring
      expect(content.contains('name="TrapSpike" x="140" y="420"'), isTrue);
      expect(content.contains('property name="trapId" value="l4_p1_pillar1_spike"'), isTrue);
      expect(content.contains('name="WarpPortal" x="270" y="624"'), isTrue);
      expect(content.contains('property name="trapId" value="l4_p1_warp1"'), isTrue);
      expect(content.contains('property name="postWarpSpikeTrapId" value="l4_p1_pillar1_spike"'), isTrue);

      expect(content.contains('name="TrapSpike" x="400" y="420"'), isTrue);
      expect(content.contains('property name="trapId" value="l4_p1_pillar2_spike"'), isTrue);
      expect(content.contains('name="WarpPortal" x="530" y="624"'), isTrue);
      expect(content.contains('property name="trapId" value="l4_p1_warp2"'), isTrue);
      expect(content.contains('property name="postWarpSpikeTrapId" value="l4_p1_pillar2_spike"'), isTrue);

      expect(content.contains('name="WarpPortal" x="745" y="624"'), isTrue);
      expect(content.contains('property name="trapId" value="l4_p1_warp3_trap"'), isTrue);

      // Platform 2 & 3 elements in Level04.tmx
      expect(content.contains('property name="trapId" value="l4_p2_bridge_warp"'), isTrue);
      expect(content.contains('property name="trapId" value="l4_p2_bridge_spike"'), isTrue);
      expect(content.contains('property name="trapId" value="l4_p2_upper_spike"'), isTrue);
      expect(content.contains('property name="trapId" value="l4_p2_upper_warp"'), isTrue);
      expect(content.contains('name="PortalGauntletController"'), isTrue);
      expect(content.contains('name="ExitPortal" x="3620" y="400"'), isTrue);
    });
  });
}
