import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/actors/player_shard_effect.dart';
import 'package:trap_dash_arena/game/level_config.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';
import 'package:trap_dash_arena/ui/respawn_overlay.dart';

class _TestTrapDashGame extends TrapDashGame {
  final VoidCallback onRespawn;

  _TestTrapDashGame(this.onRespawn) : super(initialLevelNumber: 1);

  @override
  void triggerRespawn() {
    onRespawn();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Disintegration & Respawn Lifecycle Tests', () {
    late TrapDashGame game;
    late Player player;

    setUp(() async {
      game = TrapDashGame(initialLevelNumber: 1);
      game.images.prefix = 'assets/';
      game.overlays.addEntry(
        'RespawnOverlay',
        (context, g) => RespawnOverlay(game: g as TrapDashGame),
      );
      game.overlays.addEntry(
        'ResultOverlay',
        (context, g) => const SizedBox(),
      );
      await game.onLoad();
      player = game.player;
    });

    test('Initial load spawns player immediately in active controllable state', () {
      expect(player.isInDeathCycle, isFalse);
      expect(player.isDisintegrating, isFalse);
      expect(player.isAwaitingRespawn, isFalse);
      expect(player.isReintegrating, isFalse);
      expect(player.isDead, isFalse);
      expect(player.hitbox.collisionType, equals(CollisionType.active));

      // No shard effect present
      final shards = game.world.children.whereType<PlayerShardEffect>();
      expect(shards.isEmpty, isTrue);
    });

    test('Damage triggers disintegration without auto-respawn', () {
      player.position = Vector2(250, 552);

      // Take damage
      player.takeDamage(ignoreInvulnerability: true);

      expect(player.isDisintegrating, isTrue);
      expect(player.isAwaitingRespawn, isFalse);
      expect(player.hitbox.collisionType, equals(CollisionType.inactive));
      expect(game.controller.hearts.value, equals(4)); // 1 heart deducted

      // Disintegration shard effect added to world
      final shardEffects = game.world.children.whereType<PlayerShardEffect>().toList();
      expect(shardEffects.length, equals(1));
      expect(shardEffects.first.mode, equals(ShardEffectMode.disintegrate));
      expect(shardEffects.first.position.x, equals(250));

      // Advance half-way through disintegration (0.20s of 0.40s)
      player.update(0.20);
      expect(player.isDisintegrating, isTrue);
      expect(player.isAwaitingRespawn, isFalse);
      expect(player.position.x, equals(250)); // Has not teleported!

      // Advance past completion (total 0.45s >= 0.40s)
      player.update(0.25);
      expect(player.isDisintegrating, isFalse);
      expect(player.isAwaitingRespawn, isTrue);
      expect(player.position.x, equals(250)); // Still at death spot!
      expect(game.overlays.isActive('RespawnOverlay'), isTrue);
    });

    test('triggerRespawn relocates to checkpoint and runs reverse re-integration', () async {
      player.position = Vector2(300, 552);
      player.takeDamage(ignoreInvulnerability: true);

      // Finish disintegration
      player.update(0.45);
      await Future<void>.delayed(Duration.zero);
      expect(player.isAwaitingRespawn, isTrue);

      // Trigger explicit respawn
      game.triggerRespawn();

      expect(game.overlays.isActive('RespawnOverlay'), isFalse);
      expect(player.isAwaitingRespawn, isFalse);
      expect(player.isReintegrating, isTrue);
      expect(player.position.x, equals(game.lastCheckpointPosition.x));
      expect(player.position.y, equals(game.lastCheckpointPosition.y));

      // Reintegration shard effect spawned (prior disintegration effect removed by microtask)
      final reShards = game.world.children.whereType<PlayerShardEffect>().toList();
      expect(reShards.length, equals(1));
      expect(reShards.first.mode, equals(ShardEffectMode.reintegrate));

      // Advance past re-integration duration (0.38s)
      player.update(0.40);
      await Future<void>.delayed(Duration.zero);

      expect(player.isReintegrating, isFalse);
      expect(player.isInDeathCycle, isFalse);
      expect(player.hitbox.collisionType, equals(CollisionType.active));

      // Active shards cleaned up
      final remainingShards = game.world.children.whereType<PlayerShardEffect>();
      expect(remainingShards.isEmpty, isTrue);
    });

    test('Held movement input executes immediately when re-integration completes', () {
      player.takeDamage(ignoreInvulnerability: true);
      player.update(0.45); // enters awaiting respawn

      // Player holds moveRight before / during respawn
      player.moveRight();

      game.triggerRespawn();
      expect(player.isReintegrating, isTrue);

      // Physics does not move player during re-integration
      final startX = player.position.x;
      player.update(0.20);
      expect(player.position.x, equals(startX));

      // Reintegration completes (remaining 0.20s of 0.38s)
      player.update(0.20);
      expect(player.isReintegrating, isFalse);

      // Next tick immediately runs with full moveSpeed!
      player.isOnGround = true;
      player.update(0.016);
      expect(player.velocity.x, equals(Player.moveSpeed));
      expect(player.position.x, greaterThan(startX));
    });

    test('Losing final heart completes disintegration then goes directly to GameOver', () async {
      // Drain hearts down to 1
      for (int i = 0; i < 4; i++) {
        game.controller.onPlayerHurt();
      }
      expect(game.controller.hearts.value, equals(1));

      // Lethal hit
      player.takeDamage(ignoreInvulnerability: true);
      expect(game.controller.hearts.value, equals(0));
      expect(game.controller.isGameOver.value, isTrue);
      expect(player.isDisintegrating, isTrue);

      // During disintegration, ResultOverlay has not shown yet
      game.update(0.20);
      expect(game.overlays.isActive('ResultOverlay'), isFalse);

      // Complete disintegration
      game.update(0.25);
      await Future<void>.delayed(Duration.zero);
      expect(player.isDisintegrating, isFalse);
      expect(player.isDead, isTrue);
      expect(game.overlays.isActive('RespawnOverlay'), isFalse); // Never shows respawn button!
      expect(game.overlays.isActive('ResultOverlay'), isTrue);
    });

    test('Pit fall death clamps effect origin above bottom edge', () {
      player.position = Vector2(400, 740); // fell off stage
      player.update(0.016); // triggers pit fall check

      expect(player.isDisintegrating, isTrue);
      final shardEffect = game.world.children.whereType<PlayerShardEffect>().first;
      expect(shardEffect.position.y, equals(716.0)); // clamped inside viewport!
    });

    test('PlayerShardEffect renders batched vertices and guards onComplete', () {
      int completeCount = 0;
      final shards = ShardTrajectory.generate();
      final effect = PlayerShardEffect(
        position: Vector2.zero(),
        shards: shards,
        duration: 0.40,
        onComplete: () => completeCount++,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      effect.render(canvas);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);

      // Verify onComplete fires once even if update over-ticks
      effect.update(0.45);
      expect(completeCount, equals(1));
      effect.update(0.10);
      expect(completeCount, equals(1));
    });
  });

  group('RespawnOverlay Widget Tests', () {
    testWidgets('Renders YOU DIED banner, hearts left, and triggers triggerRespawn on tap',
        (tester) async {
      bool respawnCalled = false;
      final game = _TestTrapDashGame(() => respawnCalled = true);
      game.controller.startLevel(LevelConfig.get(1));
      game.controller.hearts.value = 4;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 720,
              child: Stack(
                children: [
                  RespawnOverlay(game: game),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('YOU DIED'), findsOneWidget);
      expect(find.text('4 LEFT'), findsOneWidget);
      expect(find.text('RESPAWN'), findsOneWidget);

      await tester.tap(find.text('RESPAWN'));
      await tester.pump();

      expect(respawnCalled, isTrue);
    });
  });
}
