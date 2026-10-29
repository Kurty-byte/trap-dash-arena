import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trap_dash_arena/autoload/audio_manager.dart';

class _FakeAudioBackend implements AudioBackend {
  final List<String> playedBgm = [];
  final List<String> playedSfx = [];
  int stopBgmCalls = 0;
  int initCalls = 0;
  Completer<void>? pendingBgmCompleter;

  @override
  Future<void> init() async {
    initCalls++;
  }

  @override
  Future<void> playBgm(String assetName) async {
    if (pendingBgmCompleter != null) {
      await pendingBgmCompleter!.future;
    }
    playedBgm.add(assetName);
  }

  @override
  Future<void> stopBgm() async {
    stopBgmCalls++;
  }

  @override
  Future<void> playSfx(String assetName) async {
    playedSfx.add(assetName);
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    AudioManager.instance.resetForTesting();
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

    test('Fake backend handles init, pooled sfx, and mute suppression', () async {
      final fake = _FakeAudioBackend();
      final audio = AudioManager.instance;
      audio.setBackendForTesting(fake);
      await audio.init();

      expect(fake.initCalls, equals(1));

      await audio.playSfx('jump.wav');
      expect(fake.playedSfx, equals(['jump.wav']));

      await audio.toggleMute(); // muted = true
      await audio.playSfx('hurt.wav');
      expect(fake.playedSfx, equals(['jump.wav'])); // no new sfx dispatched
    });

    test('enterGameplay stops BGM; unmuting in gameplay does not start BGM until exitGameplay', () async {
      final fake = _FakeAudioBackend();
      final audio = AudioManager.instance;
      audio.setBackendForTesting(fake);
      await audio.init();

      await audio.playBgm('bgm.mp3');
      expect(fake.playedBgm, equals(['bgm.mp3']));

      await audio.enterGameplay();
      expect(fake.stopBgmCalls, equals(1));

      // Toggle mute inside PauseOverlay during gameplay
      await audio.toggleMute(); // muted = true
      expect(fake.stopBgmCalls, equals(2));
      await audio.toggleMute(); // muted = false
      // MUST NOT have played BGM again because we are in gameplay!
      expect(fake.playedBgm, equals(['bgm.mp3']));

      // Exiting gameplay restores menu BGM
      await audio.exitGameplay();
      expect(fake.playedBgm, equals(['bgm.mp3', 'bgm.mp3']));
    });

    test('Rapid route change cancels in-flight playBgm when enterGameplay called mid-flight', () async {
      final fake = _FakeAudioBackend();
      fake.pendingBgmCompleter = Completer<void>();
      final audio = AudioManager.instance;
      audio.setBackendForTesting(fake);
      await audio.init();

      // Start slow BGM load from TitleScreen
      final playFuture = audio.playBgm('bgm.mp3');

      // User taps immediately into gameplay before play completes
      await audio.enterGameplay();

      // In-flight completes
      fake.pendingBgmCompleter!.complete();
      await playFuture;

      // Ensure stopBgm was called to cancel the stale playback
      expect(fake.stopBgmCalls, greaterThanOrEqualTo(1));
    });
  });
}
