import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GameState.instance.resetProgress();
  });

  group('GameState Unit Tests', () {
    test('Initial state: level 1 is unlocked, levels 2-5 are locked', () {
      final state = GameState.instance;

      expect(state.unlockedLevel, equals(1));
      expect(state.isUnlocked(1), isTrue);
      expect(state.isUnlocked(2), isFalse);
      expect(state.isUnlocked(3), isFalse);
      expect(state.isUnlocked(4), isFalse);
      expect(state.isUnlocked(5), isFalse);
    });

    test('completeLevel in offline mode unlocks level n+1 and records stars',
        () async {
      final state = GameState.instance;
      state.setMode('offline');

      await state.completeLevel(1, 2);

      expect(state.unlockedLevel, equals(2));
      expect(state.isUnlocked(2), isTrue);
      expect(state.bestStars[1], equals(2));
    });

    test('completeLevel preserves higher star rating (high-water mark)',
        () async {
      final state = GameState.instance;
      state.setMode('offline');

      await state.completeLevel(1, 3);
      expect(state.bestStars[1], equals(3));

      // Replay with lower star rating
      await state.completeLevel(1, 1);
      expect(state.bestStars[1], equals(3));
    });

    test('completeLevel in online mode does not alter offline unlocks or stars',
        () async {
      final state = GameState.instance;
      state.setMode('online');

      await state.completeLevel(1, 3);

      expect(state.unlockedLevel, equals(1));
      expect(state.isUnlocked(2), isFalse);
      expect(state.bestStars.containsKey(1), isFalse);
    });

    test('Persistence survives re-initialization (init reads SharedPreferences)',
        () async {
      final state = GameState.instance;
      state.setMode('offline');

      await state.completeLevel(1, 3);
      await state.completeLevel(2, 2);
      await state.setHighContrastTells(true);
      await state.setPlayerNickname('Speedy');
      await state.setAiBotEnabled(true);

      // Simulate app restart by clearing in-memory fields and calling init()
      state.unlockedLevel = 1;
      state.bestStars.clear();
      state.highContrastTells = false;
      state.playerNickname = 'Runner';
      state.aiBotEnabled = false;

      await state.init();

      expect(state.unlockedLevel, equals(3));
      expect(state.bestStars[1], equals(3));
      expect(state.bestStars[2], equals(2));
      expect(state.highContrastTells, isTrue);
      expect(state.playerNickname, equals('Speedy'));
      expect(state.aiBotEnabled, isTrue);
    });
  });
}
