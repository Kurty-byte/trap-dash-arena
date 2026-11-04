import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trap_dash_arena/game/level_config.dart';
import 'package:trap_dash_arena/game/level_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LevelConfig Tests', () {
    test('LevelConfig.get provides correct specs for Levels 1-5', () {
      final l1 = LevelConfig.get(1);
      expect(l1.levelNumber, equals(1));
      expect(l1.timeLimit, equals(90.0));
      expect(l1.initialHearts, equals(5));
      expect(l1.requiredKeys, equals(0));
      expect(l1.tmxFile, equals('Level01.tmx'));

      final l2 = LevelConfig.get(2);
      expect(l2.timeLimit, equals(75.0));
      expect(l2.initialHearts, equals(5));
      expect(l2.requiredKeys, equals(0));
      expect(l2.roomCount, equals(3));

      final l3 = LevelConfig.get(3);
      expect(l3.timeLimit, equals(70.0));
      expect(l3.initialHearts, equals(4));

      final l4 = LevelConfig.get(4);
      expect(l4.timeLimit, equals(60.0));
      expect(l4.initialHearts, equals(3));

      final l5 = LevelConfig.get(5);
      expect(l5.timeLimit, equals(60.0));
      expect(l5.initialHearts, equals(3));
    });
  });

  group('LevelController Scoring & Rules Tests', () {
    late LevelController controller;
    late LevelConfig config;

    setUp(() {
      controller = LevelController();
      config = LevelConfig.get(1); // 90s, 5 hearts
      controller.startLevel(config);
    });

    test('Initial level values match config', () {
      expect(controller.timeLeft.value, equals(90.0));
      expect(controller.displayTimeSeconds.value, equals(90));
      expect(controller.hearts.value, equals(5));
      expect(controller.score.value, equals(0));
      expect(controller.isGameOver.value, isFalse);
      expect(controller.isLevelCleared.value, isFalse);
    });

    test('displayTimeSeconds throttles notifications to integer ceiling changes only', () {
      int notifications = 0;
      controller.displayTimeSeconds.addListener(() {
        notifications++;
      });

      expect(controller.displayTimeSeconds.value, equals(90));

      // 50 ticks of 0.016s = 0.80s elapsed (timeLeft drops from 90.0 to 89.2)
      // ceil(89.2) is still 90, so displayTimeSeconds MUST NOT notify!
      for (int i = 0; i < 50; i++) {
        controller.update(0.016);
      }
      expect(controller.timeLeft.value, closeTo(89.2, 0.001));
      expect(controller.displayTimeSeconds.value, equals(90));
      expect(notifications, equals(0));

      // Advance past the 89.0 boundary (another 0.3s -> timeLeft = 88.9, ceil = 89)
      controller.update(0.3);
      expect(controller.timeLeft.value, closeTo(88.9, 0.001));
      expect(controller.displayTimeSeconds.value, equals(89));
      expect(notifications, equals(1));
    });

    test('Triggering checkpoint awards 100 points once', () {
      controller.triggerCheckpoint(1);
      expect(controller.score.value, equals(100));

      // Same checkpoint should not award again
      controller.triggerCheckpoint(1);
      expect(controller.score.value, equals(100));

      // Different checkpoint awards
      controller.triggerCheckpoint(2);
      expect(controller.score.value, equals(200));
    });

    test('Collecting coin awards 50 points', () {
      controller.collectCoin();
      expect(controller.score.value, equals(50));
    });

    test('Collecting key awards 50 points and increments keysCollected', () {
      controller.collectKey();
      expect(controller.score.value, equals(50));
      expect(controller.keysCollected.value, equals(1));
    });

    test('Trap bait awards 25 points once per trap', () {
      controller.onTrapBait('spike_1');
      expect(controller.score.value, equals(25));

      // Re-triggering same trap does not award twice
      controller.onTrapBait('spike_1');
      expect(controller.score.value, equals(25));

      // Different trap awards
      controller.onTrapBait('floor_1');
      expect(controller.score.value, equals(50));
    });

    test('Player hurt deducts 1 heart, penalizes 25 points, floored at 0', () {
      controller.collectCoin(); // score = 50
      controller.onPlayerHurt();

      expect(controller.hearts.value, equals(4));
      expect(controller.score.value, equals(25));

      controller.onPlayerHurt();
      expect(controller.hearts.value, equals(3));
      expect(controller.score.value, equals(0));

      // Cannot go below 0
      controller.onPlayerHurt();
      expect(controller.hearts.value, equals(2));
      expect(controller.score.value, equals(0));
    });

    test('0 hearts triggers game over (loss)', () {
      for (int i = 0; i < 5; i++) {
        controller.onPlayerHurt();
      }

      expect(controller.hearts.value, equals(0));
      expect(controller.isGameOver.value, isTrue);
      expect(controller.isLevelCleared.value, isFalse);
    });

    test('Timer expiry triggers game over (loss)', () {
      controller.update(95.0);

      expect(controller.timeLeft.value, equals(0.0));
      expect(controller.isGameOver.value, isTrue);
      expect(controller.isLevelCleared.value, isFalse);
    });

    test('Reaching exit portal awards exit bonus and clears level', () {
      controller.update(30.0); // 60s left
      controller.reachExitPortal();

      expect(controller.isLevelCleared.value, isTrue);
      expect(controller.isGameOver.value, isTrue);

      // Exit bonus: 300 + ceil(60) * 10 = 900
      expect(controller.score.value, equals(900));
    });

    test('Star calculation for Levels 1-3 vs relaxed Levels 4-5', () {
      // Level 1: 90s, 5 hearts. 3 stars requires t_left > 45s AND hearts >= 3
      controller.startLevel(LevelConfig.get(1));
      controller.update(40.0); // 50s left (> 45s)
      controller.onPlayerHurt(); // 4 hearts left
      controller.onPlayerHurt(); // 3 hearts left
      controller.reachExitPortal();
      expect(controller.calculateStars(), equals(3));

      // Re-run with 2 hearts left -> 2 stars
      controller.startLevel(LevelConfig.get(1));
      controller.update(40.0);
      controller.onPlayerHurt();
      controller.onPlayerHurt();
      controller.onPlayerHurt(); // 2 hearts left
      controller.reachExitPortal();
      expect(controller.calculateStars(), equals(2));

      // Level 4: 60s, 3 hearts. Relaxed: hearts >= min(3, 3 - 1) = 2
      final l4Controller = LevelController();
      l4Controller.startLevel(LevelConfig.get(4));
      l4Controller.update(20.0); // 40s left (> 30s)
      l4Controller.onPlayerHurt(); // 2 hearts left (1 hit taken)
      l4Controller.reachExitPortal();
      expect(l4Controller.calculateStars(), equals(3)); // Relaxed rule passes!

      // Level 4 with 1 heart left -> 2 stars
      l4Controller.startLevel(LevelConfig.get(4));
      l4Controller.update(20.0);
      l4Controller.onPlayerHurt();
      l4Controller.onPlayerHurt(); // 1 heart left
      l4Controller.reachExitPortal();
      expect(l4Controller.calculateStars(), equals(2));
    });
  });
}
