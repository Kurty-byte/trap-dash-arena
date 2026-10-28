import 'package:flutter_test/flutter_test.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TrapDashGame initializes camera and enclosed chamber properly', () async {
    final game = TrapDashGame(initialLevelNumber: 1);
    game.images.prefix = 'assets/';
    final img = await game.images.load('game/player.png');
    expect(img.width, equals(200));
    await game.onLoad();

    expect(game.camera.world, isNotNull);
    expect(game.player, isNotNull);

    // Enclosed chamber Level 1 spawn coordinates
    expect(game.player.position.x, equals(148));
    expect(game.player.position.y, equals(552));
    expect(game.world.children.length, greaterThan(8));

    // Fixed single-screen camera framing
    expect(game.camera.viewfinder.position.x, equals(640));
    expect(game.camera.viewfinder.position.y, equals(360));

    // Camera stays locked to (640, 360) as player moves
    game.player.moveRight();
    game.update(0.1);
    expect(game.camera.viewfinder.position.x, equals(640));
    expect(game.camera.viewfinder.position.y, equals(360));

    // Screen shake oscillates around (640, 360) and returns cleanly
    game.shakeCamera(intensity: 10.0, duration: 0.1);
    game.update(0.016);
    expect(game.camera.viewfinder.position.x, isNot(equals(0)));

    // After trauma decays, snaps back to (640, 360)
    game.update(2.0);
    expect(game.camera.viewfinder.position.x, equals(640));
    expect(game.camera.viewfinder.position.y, equals(360));
  });

  test('All 5 levels load enclosed chamber geometry properly', () async {
    for (int lvl = 1; lvl <= 5; lvl++) {
      final game = TrapDashGame(initialLevelNumber: lvl);
      game.images.prefix = 'assets/';
      await game.onLoad();

      expect(game.currentLevelNumber, equals(lvl));
      expect(game.world.children.length, greaterThan(5));
      expect(game.player, isNotNull);
      expect(game.camera.viewfinder.position.x, equals(640));
      expect(game.camera.viewfinder.position.y, equals(360));
    }
  });
}
