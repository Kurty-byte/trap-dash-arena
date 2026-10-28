import 'package:flutter_test/flutter_test.dart';
import 'package:trap_dash_arena/game/simple_ai.dart';

void main() {
  group('SimpleAI Pace-Bot Unit Tests', () {
    test('calculateInterval adheres to PRD formula across levels', () {
      expect(SimpleAI.calculateInterval(1), closeTo(3.0, 0.001));
      expect(SimpleAI.calculateInterval(2), closeTo(2.6, 0.001));
      expect(SimpleAI.calculateInterval(3), closeTo(2.2, 0.001));
      expect(SimpleAI.calculateInterval(4), closeTo(1.8, 0.001));
      expect(SimpleAI.calculateInterval(5), closeTo(1.4, 0.001));
      expect(SimpleAI.calculateInterval(10), equals(0.8)); // Floor
    });

    test('update increments score and progress when interval triggers', () {
      final ai = SimpleAI(levelNumber: 1); // interval 3.0s
      expect(ai.score.value, equals(0));
      expect(ai.progress.value, equals(0.0));

      ai.update(1.5);
      expect(ai.score.value, equals(0));

      ai.update(1.6); // Total 3.1s > 3.0s
      expect(ai.score.value, equals(35));
      expect(ai.progress.value, closeTo(0.05, 0.001));
    });

    test('progress caps at 1.0 and stops updating', () {
      final ai = SimpleAI(levelNumber: 5); // interval 1.4s
      for (int i = 0; i < 25; i++) {
        ai.update(1.5);
      }
      expect(ai.progress.value, equals(1.0));
      expect(ai.isFinished, isTrue);

      final finalScore = ai.score.value;
      ai.update(2.0);
      expect(ai.score.value, equals(finalScore)); // Does not tick further
    });
  });
}
