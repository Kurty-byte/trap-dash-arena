import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trap_dash_arena/game/actors/exit_portal.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Door Enter Animation Tests', () {
    late TrapDashGame game;
    late Player player;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      game = TrapDashGame(initialLevelNumber: 1);
      game.images.prefix = 'assets/';
      await game.onLoad();
      player = game.player;
    });

    test('Player entering door blocks input and triggers completion callback', () {
      bool completed = false;
      final doorPos = Vector2(500, 552);

      player.position = Vector2(480, 552);
      player.enterDoor(doorPos, onComplete: () {
        completed = true;
      });

      expect(player.isEnteringDoor, isTrue);

      // Input attempts while entering door are blocked
      player.moveRight();
      expect(player.velocity.x, equals(0));

      player.jump();
      expect(player.velocity.y, equals(0));

      // Advance time half-way
      player.update(0.2);
      expect(player.isEnteringDoor, isTrue);
      expect(completed, isFalse);
      expect(player.position.x, greaterThan(480));

      // Advance past duration (0.45s total)
      player.update(0.3);
      expect(player.isEnteringDoor, isFalse);
      expect(completed, isTrue);
    });

    test('ExitPortal collision triggers door entering animation before clearing level', () async {
      final portal = ExitPortal(position: Vector2(500, 552));
      await game.world.add(portal);
      await game.ready();

      player.position = Vector2(495, 552);

      // Trigger collision
      portal.onCollisionStart({Vector2(500, 552)}, player);

      expect(player.isEnteringDoor, isTrue);
      expect(game.controller.isLevelCleared.value, isFalse);

      // Advance animation to completion
      player.update(0.5);

      expect(player.isEnteringDoor, isFalse);
      expect(game.controller.isLevelCleared.value, isTrue);
    });

    test('ExitPortal collision while player isInDeathCycle does not start entering', () async {
      final portal = ExitPortal(position: Vector2(500, 552));
      await game.world.add(portal);
      await game.ready();

      player.position = Vector2(495, 552);
      player.takeDamage(ignoreInvulnerability: true);
      expect(player.isInDeathCycle, isTrue);

      // Collision while in death cycle
      portal.onCollisionStart({Vector2(500, 552)}, player);

      expect(portal.isEntering, isFalse);
      expect(player.isEnteringDoor, isFalse);
      expect(game.controller.isLevelCleared.value, isFalse);
    });

    test('respawnPlayerAtCheckpoint resets ExitPortal so level can be cleared after death', () async {
      final portal = ExitPortal(position: Vector2(500, 552));
      await game.world.add(portal);
      await game.ready();

      // Simulate player dying near the door
      player.position = Vector2(495, 552);
      player.takeDamage(ignoreInvulnerability: true);

      // Even if portal somehow started entering or was in progress
      portal.onCollisionStart({Vector2(500, 552)}, player);

      // Trigger respawn at checkpoint
      game.respawnPlayerAtCheckpoint(playReintegration: false);

      expect(portal.isEntering, isFalse);
      expect(player.isEnteringDoor, isFalse);
      expect(player.isInDeathCycle, isFalse);

      // Player returns to door alive and enters successfully
      player.position = Vector2(495, 552);
      portal.onCollisionStart({Vector2(500, 552)}, player);

      expect(portal.isEntering, isTrue);
      expect(player.isEnteringDoor, isTrue);

      player.update(0.5);
      expect(player.isEnteringDoor, isFalse);
      expect(game.controller.isLevelCleared.value, isTrue);
    });
  });
}
