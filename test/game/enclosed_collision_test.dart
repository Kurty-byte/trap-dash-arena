import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trap_dash_arena/game/actors/checkpoint_flag.dart';
import 'package:trap_dash_arena/game/actors/disappearing_platform.dart';
import 'package:trap_dash_arena/game/actors/exit_portal.dart';
import 'package:trap_dash_arena/game/actors/fake_floor.dart';
import 'package:trap_dash_arena/game/actors/falling_block.dart';
import 'package:trap_dash_arena/game/actors/ground_block.dart';
import 'package:trap_dash_arena/game/actors/moving_saw.dart';
import 'package:trap_dash_arena/game/actors/pickup_item.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/actors/reverse_spring.dart';
import 'package:trap_dash_arena/game/actors/trap_spike.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('4-Way Enclosed Collision Tests', () {
    late TrapDashGame game;
    late Player player;

    setUp(() async {
      game = TrapDashGame(initialLevelNumber: 1);
      await game.onLoad();
      player = game.player;
    });

    test('Floor landing sets position and isOnGround', () {
      final floor = GroundBlock(
        position: Vector2(100, 500),
        size: Vector2(200, 40),
      );

      // Player falling and penetrating top edge of floor (player bottom is at 504)
      player.position = Vector2(150, 504);
      player.velocity.y = 200;
      player.isOnGround = false;

      floor.onCollision({Vector2(150, 500)}, player);

      expect(player.position.y, equals(500));
      expect(player.velocity.y, equals(0));
      expect(player.isOnGround, isTrue);
    });

    test('Ceiling head-bonk cuts upward velocity without horizontal ejection', () {
      final ceiling = GroundBlock(
        position: Vector2(100, 200),
        size: Vector2(200, 40),
      );

      // Player jumping upward into bottom of ceiling block (bottom is at y = 240)
      // Player head is at y - 36. If player.position.y = 274, head is at 238 (2px penetration)
      player.position = Vector2(150, 274);
      player.velocity.x = 100;
      player.velocity.y = -500;

      ceiling.onCollision({Vector2(150, 240)}, player);

      // Head snaps flush with ceiling bottom (240 + 36 = 276)
      expect(player.position.y, equals(276));
      expect(player.velocity.y, equals(0));
      // X position is preserved (no lateral ejection)
      expect(player.position.x, equals(150));
    });

    test('Left wall blocks rightward penetration', () {
      final wall = GroundBlock(
        position: Vector2(300, 400),
        size: Vector2(40, 200),
      );

      // Player moving right into left edge of wall (wallLeft = 300)
      // playerRight is pos.x + 10. If pos.x = 292, playerRight is 302 (2px penetration)
      player.position = Vector2(292, 500);
      player.velocity.x = 240;
      player.isOnGround = true;

      wall.onCollision({Vector2(300, 500)}, player);

      // Snapped to left of wall (300 - 10 = 290)
      expect(player.position.x, equals(290));
      expect(player.velocity.x, equals(0));
      // isOnGround preserved so player can jump while touching wall
      expect(player.isOnGround, isTrue);
    });

    test('Right wall blocks leftward penetration', () {
      final wall = GroundBlock(
        position: Vector2(100, 400),
        size: Vector2(40, 200),
      );

      // Player moving left into right edge of wall (wallRight = 140)
      // playerLeft is pos.x - 10. If pos.x = 148, playerLeft is 138 (2px penetration)
      player.position = Vector2(148, 500);
      player.velocity.x = -240;
      player.isOnGround = true;

      wall.onCollision({Vector2(140, 500)}, player);

      // Snapped to right of wall (140 + 10 = 150)
      expect(player.position.x, equals(150));
      expect(player.velocity.x, equals(0));
      expect(player.isOnGround, isTrue);
    });
  });

  group('Collision Broadphase Passive Hitbox Tests', () {
    test('Non-player obstacles and pickups use CollisionType.passive', () async {
      final ground = GroundBlock(position: Vector2.zero(), size: Vector2(32, 32));
      final fakeFloor = FakeFloor(trapId: 'ff1', position: Vector2.zero());
      final disappear = DisappearingPlatform(position: Vector2.zero(), size: Vector2(32, 16));
      final spike = TrapSpike(trapId: 's1', position: Vector2.zero());
      final falling = FallingBlock(trapId: 'fb1', position: Vector2.zero(), groundY: 100);
      final saw = MovingSaw(pathStart: Vector2.zero(), pathEnd: Vector2(100, 0));
      final flag = CheckpointFlag(checkpointId: 1, position: Vector2.zero());
      final pickup = PickupItem(type: PickupType.coin, position: Vector2.zero());
      final spring = ReverseSpring(trapId: 'sp1', position: Vector2.zero());
      final portal = ExitPortal(position: Vector2.zero());

      await fakeFloor.onLoad();
      await disappear.onLoad();
      await spike.onLoad();
      await falling.onLoad();
      await saw.onLoad();
      await flag.onLoad();
      await pickup.onLoad();
      await spring.onLoad();
      await portal.onLoad();

      expect(ground.children.whereType<ShapeHitbox>().first.collisionType, equals(CollisionType.passive));
      expect(fakeFloor.hitbox.collisionType, equals(CollisionType.passive));
      expect(disappear.hitbox.collisionType, equals(CollisionType.passive));
      expect(spike.hitbox.collisionType, equals(CollisionType.passive));
      expect(falling.hitbox.collisionType, equals(CollisionType.passive));
      expect(saw.hitbox.collisionType, equals(CollisionType.passive));
      expect(flag.children.whereType<ShapeHitbox>().first.collisionType, equals(CollisionType.passive));
      expect(pickup.children.whereType<ShapeHitbox>().first.collisionType, equals(CollisionType.passive));
      expect(spring.hitbox.collisionType, equals(CollisionType.passive));
      expect(portal.children.whereType<ShapeHitbox>().first.collisionType, equals(CollisionType.passive));

      // Reset to solid maintains passive collision
      fakeFloor.crumble();
      expect(fakeFloor.hitbox.collisionType, equals(CollisionType.inactive));
      fakeFloor.resetToSolid();
      expect(fakeFloor.hitbox.collisionType, equals(CollisionType.passive));
    });
  });
}
