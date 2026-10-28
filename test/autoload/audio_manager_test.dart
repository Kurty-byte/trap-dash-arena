import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trap_dash_arena/autoload/audio_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('AudioManager Unit Tests', () {
    test('Initial mute state is false', () async {
      final audio = AudioManager.instance;
      await audio.init();

      expect(audio.isMuted.value, isFalse);
    });

    test('toggleMute toggles state and persists to SharedPreferences', () async {
      final audio = AudioManager.instance;
      await audio.init();

      await audio.toggleMute();
      expect(audio.isMuted.value, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('audio_muted'), isTrue);

      // Re-init reads persisted mute state
      audio.isMuted.value = false;
      await audio.init();
      expect(audio.isMuted.value, isTrue);
    });

    test('playSfx and playBgm execute gracefully without throwing in test environment', () async {
      final audio = AudioManager.instance;
      await audio.init();

      expect(() => audio.playSfx('jump.wav'), returnsNormally);
      expect(() => audio.playBgm('bgm.ogg'), returnsNormally);
      expect(() => audio.stopBgm(), returnsNormally);
    });
  });
}
