import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trap_dash_arena/game/actors/checkpoint_flag.dart';
import 'package:trap_dash_arena/game/actors/control_inverter_zone.dart';
import 'package:trap_dash_arena/game/actors/exit_portal.dart';
import 'package:trap_dash_arena/game/actors/fake_floor.dart';
import 'package:trap_dash_arena/game/actors/moving_gap_floor.dart';
import 'package:trap_dash_arena/game/actors/pickup_item.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/actors/sudden_gap.dart';
import 'package:trap_dash_arena/game/actors/trap_spike.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Level 3 Control Inversion & Connected Gauntlet Tests', () {
    late TrapDashGame game;
    late Player player;

    setUp(() async {
      game = TrapDashGame(initialLevelNumber: 3);
      await game.onLoad();
      player = game.player;
    });

    test('Level 3 layout contains 3 rooms, 2 checkpoints, 12 inverters, 5 sudden gaps, 4 spikes', () async {
      expect(game.controller.config.roomCount, equals(3));
      expect(game.controller.config.requiredKeys, equals(0));
      expect(game.controller.config.timeLimit, equals(70.0));
      expect(game.startSpawnPosition.x, equals(148.0));
      expect(game.exitX, equals(3698.0));

      // No fake floors or keys/coins
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

      // 12 ControlInverterZone triggers across 3 platforms
      final inverters = game.world.children.whereType<ControlInverterZone>().toList();
      expect(inverters.length, equals(12));

      // 5 SuddenGap hazards (3 in P1, 2 in P2)
      final suddenGaps = game.world.children.whereType<SuddenGap>().toList();
      expect(suddenGaps.length, equals(5));

      // 1 MovingGapFloor (hesitation gap on Platform 3 plateau)
      final movingGaps = game.world.children.whereType<MovingGapFloor>().toList();
      expect(movingGaps.length, equals(1));
      expect(movingGaps.first.mode, equals(MovingGapMode.hesitation));

      // 4 TrapSpikes (P2 rear spike, P2 passage spike, P3 step3 ambush spike, P3 surprise pop-up spike)
      final spikes = game.world.children.whereType<TrapSpike>().toList();
      expect(spikes.length, equals(4));

      // Exit portal on plateau
      final exits = game.world.children.whereType<ExitPortal>().toList();
      expect(exits.length, equals(1));
      expect(exits.first.position.x, equals(3698.0));
      expect(exits.first.position.y, equals(344.0));
    });

    test('Player mid-hold immediate direction reversal on control inversion toggle', () async {
      expect(player.controlsInverted, isFalse);

      // Player holds right
      player.moveRight();
      expect(player.horizontalDirection, equals(1.0));
      player.update(0.1);
      expect(player.velocity.x, greaterThan(0.0));

      // Invert controls while still holding right
      player.setControlsInverted(true);
      expect(player.controlsInverted, isTrue);
      expect(player.horizontalDirection, equals(-1.0));
      expect(player.velocity.x, lessThan(0.0));

      // Revert controls back to normal
      player.setControlsInverted(false);
      expect(player.controlsInverted, isFalse);
      expect(player.horizontalDirection, equals(1.0));
      expect(player.velocity.x, greaterThan(0.0));

      // Respawn resets inverted state to false
      player.setControlsInverted(true);
      expect(player.controlsInverted, isTrue);

      // Verify inverted indicator rendering executes without error
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      expect(() => player.render(canvas), returnsNormally);
      recorder.endRecording().dispose();

      player.respawnAt(Vector2(148, 552));
      expect(player.controlsInverted, isFalse);
    });

    test('Platform 1 grounded island parity switches controls on each landing', () async {
      final inverters = game.world.children.whereType<ControlInverterZone>().toList();
      final inv0 = inverters.firstWhere((z) => z.trapId == 'l3_p1_inv_0');
      final inv1 = inverters.firstWhere((z) => z.trapId == 'l3_p1_inv_1');
      final inv2 = inverters.firstWhere((z) => z.trapId == 'l3_p1_inv_2');
      final inv3 = inverters.firstWhere((z) => z.trapId == 'l3_p1_inv_3');

      // Mid-walk trigger before Gap 1 (aerial or grounded)
      player.position = Vector2(275, 530);
      inv0.update(0.016);
      expect(player.controlsInverted, isTrue);

      // Landing on Island 1 while airborne: must NOT trigger until grounded!
      player.position = Vector2(440, 520);
      player.isOnGround = false;
      inv1.update(0.016);
      expect(player.controlsInverted, isTrue); // Stays true while in air

      // Touch down on Island 1
      player.isOnGround = true;
      inv1.update(0.016);
      expect(player.controlsInverted, isFalse); // Reverted to normal

      // Jump over Gap 2 and land on Island 2
      player.position = Vector2(710, 520);
      player.isOnGround = true;
      inv2.update(0.016);
      expect(player.controlsInverted, isTrue); // Inverted again

      // Jump over Gap 3 and land on Runway
      player.position = Vector2(980, 520);
      player.isOnGround = true;
      inv3.update(0.016);
      expect(player.controlsInverted, isFalse); // Normal for Passage 1
    });

    test('Platform 2 rear ambush spike pops up and inverts controls to punish holding Right', () async {
      final rearSpike = game.world.children
          .whereType<TrapSpike>()
          .firstWhere((s) => s.trapId == 'l3_p2_rear_spike');
      final invOn = game.world.children
          .whereType<ControlInverterZone>()
          .firstWhere((z) => z.trapId == 'l3_p2_inv_on');
      final invOff = game.world.children
          .whereType<ControlInverterZone>()
          .firstWhere((z) => z.trapId == 'l3_p2_inv_off');

      expect(rearSpike.isTriggered, isFalse);
      expect(rearSpike.behavior, equals(SpikeBehavior.remotePopUp));

      // Player walks past x = 1548
      player.position = Vector2(1552, 552);
      player.isOnGround = true;
      rearSpike.update(0.016);
      expect(rearSpike.isTriggered, isTrue);

      // Right after at x = 1568, controls invert
      player.position = Vector2(1570, 530);
      invOn.update(0.016);
      expect(player.controlsInverted, isTrue);

      // Holding right causes leftward velocity toward rear spike!
      player.moveRight();
      player.update(0.05);
      expect(player.velocity.x, lessThan(0.0));

      // Player clears Gap 2A and 2B, then lands at x = 2110
      player.position = Vector2(2110, 530);
      player.isOnGround = true;
      invOff.update(0.016);
      expect(player.controlsInverted, isFalse);
    });

    test('Platform 2 inverts controls even when jumping over trigger at jump peak', () async {
      final invOn = game.world.children
          .whereType<ControlInverterZone>()
          .firstWhere((z) => z.trapId == 'l3_p2_inv_on');

      expect(invOn.triggerFullHeight, isTrue);
      expect(player.controlsInverted, isFalse);

      // Player jumps high over the trigger (y = 440, well above trigger box at y = 520..560)
      player.position = Vector2(1570, 440);
      player.isOnGround = false;
      invOn.update(0.016);

      // Inversion must trigger even while airborne at jump peak
      expect(player.controlsInverted, isTrue);
      expect(invOn.isTriggered, isTrue);
    });

    test('Platform 3 staircase flips parity per step and Step 4 activates Step 3 ambush spike', () async {
      final step3Spike = game.world.children
          .whereType<TrapSpike>()
          .firstWhere((s) => s.trapId == 'l3_p3_step3_spike');
      final inverters = game.world.children.whereType<ControlInverterZone>().toList();
      final entryInv = inverters.firstWhere((z) => z.trapId == 'l3_p3_entry_inv');
      final step1Inv = inverters.firstWhere((z) => z.trapId == 'l3_p3_step1_inv');
      final step2Inv = inverters.firstWhere((z) => z.trapId == 'l3_p3_step2_inv');
      final step3Inv = inverters.firstWhere((z) => z.trapId == 'l3_p3_step3_inv');
      final step4Inv = inverters.firstWhere((z) => z.trapId == 'l3_p3_step4_inv');
      final plateauNorm = inverters.firstWhere((z) => z.trapId == 'l3_p3_plateau_norm');

      // Room entry inverts
      player.position = Vector2(2670, 530);
      entryInv.update(0.016);
      expect(player.controlsInverted, isTrue);

      // Step 1 landing (y = 500)
      player.position = Vector2(2760, 480);
      player.isOnGround = true;
      step1Inv.update(0.016);
      expect(player.controlsInverted, isFalse);

      // Step 2 landing (y = 448)
      player.position = Vector2(2850, 430);
      player.isOnGround = true;
      step2Inv.update(0.016);
      expect(player.controlsInverted, isTrue);

      // Step 3 landing (y = 396)
      player.position = Vector2(2940, 380);
      player.isOnGround = true;
      step3Inv.update(0.016);
      expect(player.controlsInverted, isFalse);
      expect(step3Spike.isTriggered, isFalse);

      // Step 4 landing (y = 344)
      player.position = Vector2(3035, 330);
      player.isOnGround = true;
      step4Inv.update(0.016);
      step3Spike.update(0.016);

      // Step 4 inverts controls AND springs Step 3 ambush spike!
      expect(player.controlsInverted, isTrue);
      expect(step3Spike.isTriggered, isTrue);

      // Player advances onto plateau normalizer
      player.position = Vector2(3100, 330);
      player.isOnGround = true;
      plateauNorm.update(0.016);
      expect(player.controlsInverted, isFalse);
    });

    test('Platform 3 surprise pop-up spike pops up on proximity without moving', () async {
      final surpriseSpike = game.world.children
          .whereType<TrapSpike>()
          .firstWhere((s) => s.trapId == 'l3_p3_surprise_spike');

      expect(surpriseSpike.position.x, equals(3588.0));
      expect(surpriseSpike.position.y, equals(344.0));
      expect(surpriseSpike.behavior, equals(SpikeBehavior.proximityPopUp));
      expect(surpriseSpike.hideCompletelyWhenIdle, isTrue);
      expect(surpriseSpike.isTriggered, isFalse);
      expect(surpriseSpike.isExtended, isFalse);

      // Player approaches within 44px (3588 - 44 = 3544)
      player.position = Vector2(3550, 344);
      surpriseSpike.update(0.016);
      expect(surpriseSpike.isTriggered, isTrue);

      // Jitter window (0.08s) finishes, thrusts upward
      surpriseSpike.update(0.1);
      expect(surpriseSpike.isExtended, isTrue);

      // Does not move horizontally! Position remains exactly 3588.0
      expect(surpriseSpike.position.x, equals(3588.0));
    });
  });
}
