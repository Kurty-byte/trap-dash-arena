import 'package:flutter_test/flutter_test.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Player Kinematic Physics Tests', () {
    late TrapDashGame game;
    late Player player;

    setUp(() async {
      game = TrapDashGame(initialLevelNumber: 1);
      await game.onLoad();
      player = game.player;
    });

    test('Horizontal movement sets velocity correctly', () {
      player.moveRight();
      player.update(0.016);
      expect(player.velocity.x, equals(Player.moveSpeed));

      player.moveLeft();
      player.update(0.016);
      expect(player.velocity.x, equals(-Player.moveSpeed));

      player.stopMoving();
      player.update(0.016);
      expect(player.velocity.x, equals(0.0));
    });

    test('Jump execution sets jump velocity when grounded', () {
      player.isOnGround = true;
      player.jump();
      player.update(0.016);

      // velocity is jumpVelocity (-659) + 1 frame of gravity (1938 * 0.016 = ~31)
      expect(player.velocity.y, closeTo(-628.0, 1.0));
      expect(player.isOnGround, isFalse);
    });

    test('Fixed jump height preserves upward velocity when releasing jump early', () {
      player.isOnGround = true;
      player.jump();
      player.update(0.016);

      final initialJumpVelocity = player.velocity.y;
      expect(initialJumpVelocity, lessThan(0));

      player.cutJump();
      expect(player.velocity.y, equals(initialJumpVelocity));
    });

    test('Coyote time allows jump shortly after leaving ground', () {
      player.isOnGround = true;
      player.update(0.016); // Sets coyote timer

      player.isOnGround = false; // Player stepped off ledge
      player.update(0.05); // 0.05s elapsed (within 0.10s coyote window)

      player.jump();
      player.update(0.016);

      expect(player.velocity.y, closeTo(-628.0, 1.0));
    });

    test('Jump buffer registers jump press slightly before touching ground', () {
      player.isOnGround = false;
      player.velocity.y = 100; // Falling in air
      player.jump(); // Buffered jump
      player.update(0.05); // 0.05s elapsed (within 0.10s buffer window)

      // Player lands on ground
      player.isOnGround = true;
      player.update(0.016);

      // Buffered jump triggers immediately
      expect(player.velocity.y, closeTo(-628.0, 1.0));
    });
  });
}
