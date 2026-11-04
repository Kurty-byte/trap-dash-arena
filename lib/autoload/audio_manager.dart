import 'dart:io';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AudioBackend {
  Future<void> init();
  Future<void> playBgm(String assetName);
  Future<void> stopBgm();
  Future<void> playSfx(String assetName);
  Future<void> dispose();
}

class FlameAudioBackend implements AudioBackend {
  final Map<String, AudioPool> _sfxPools = {};
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await FlameAudio.bgm.initialize().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('FlameAudioBackend: bgm.initialize error: $e');
    }

    try {
      await FlameAudio.audioCache.loadAll([
        'bgm.mp3',
        'hurt.wav',
        'jump.wav',
        'trap_trigger.wav',
        'unlock.wav',
        'win.wav',
      ]).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('FlameAudioBackend: audioCache.loadAll error: $e');
    }

    final poolConfigs = {
      'jump.wav': (min: 2, max: 4),
      'trap_trigger.wav': (min: 2, max: 4),
      'hurt.wav': (min: 1, max: 2),
      'unlock.wav': (min: 1, max: 3),
      'win.wav': (min: 1, max: 2),
    };

    for (final entry in poolConfigs.entries) {
      try {
        final pool = await FlameAudio.createPool(
          entry.key,
          minPlayers: entry.value.min,
          maxPlayers: entry.value.max,
        ).timeout(const Duration(seconds: 2));
        _sfxPools[entry.key] = pool;
      } catch (e) {
        debugPrint('FlameAudioBackend: failed to create pool for ${entry.key}: $e');
      }
    }
  }

  @override
  Future<void> playBgm(String assetName) async {
    await FlameAudio.bgm.play(assetName);
  }

  @override
  Future<void> stopBgm() async {
    await FlameAudio.bgm.stop();
  }

  @override
  Future<void> playSfx(String assetName) async {
    final pool = _sfxPools[assetName];
    if (pool != null) {
      await pool.start();
    } else {
      await FlameAudio.play(assetName);
    }
  }

  @override
  Future<void> dispose() async {
    for (final pool in _sfxPools.values) {
      await pool.dispose();
    }
    _sfxPools.clear();
    await FlameAudio.bgm.dispose();
    _initialized = false;
  }
}

class NoopAudioBackend implements AudioBackend {
  @override
  Future<void> init() async {}

  @override
  Future<void> playBgm(String assetName) async {}

  @override
  Future<void> stopBgm() async {}

  @override
  Future<void> playSfx(String assetName) async {}

  @override
  Future<void> dispose() async {}
}

class AudioManager {
  static final AudioManager instance = AudioManager._();
  AudioManager._();

  final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);

  AudioBackend? _customBackend;
  late final AudioBackend _defaultBackend =
      _isTest ? NoopAudioBackend() : FlameAudioBackend();

  AudioBackend get _activeBackend => _customBackend ?? _defaultBackend;

  String? _currentBgm;
  bool _wantsBgm = false;
  int _gameplayDepth = 0;
  int _bgmOpId = 0;
  String? _playingBgm;

  bool get _isTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  @visibleForTesting
  void setBackendForTesting(AudioBackend? backend) {
    _customBackend = backend;
  }

  @visibleForTesting
  void resetForTesting() {
    _customBackend = null;
    isMuted.value = false;
    _currentBgm = null;
    _wantsBgm = false;
    _gameplayDepth = 0;
    _bgmOpId = 0;
    _playingBgm = null;
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isMuted.value = prefs.getBool('audio_muted') ?? false;
      await _activeBackend.init();
    } catch (e) {
      debugPrint('AudioManager.init error: $e');
    }
  }

  Future<void> playBgm(String assetName) async {
    _currentBgm = assetName;
    _wantsBgm = true;
    final opId = ++_bgmOpId;

    if (isMuted.value || _gameplayDepth > 0) return;
    if (_playingBgm == assetName) return;

    try {
      await _activeBackend.playBgm(assetName);
      if (opId == _bgmOpId && _wantsBgm && !isMuted.value && _gameplayDepth == 0) {
        _playingBgm = assetName;
      } else {
        await _activeBackend.stopBgm();
        _playingBgm = null;
      }
    } catch (e) {
      debugPrint('AudioManager.playBgm error: $e');
    }
  }

  Future<void> stopBgm() async {
    _wantsBgm = false;
    _playingBgm = null;
    ++_bgmOpId;
    try {
      await _activeBackend.stopBgm();
    } catch (e) {
      debugPrint('AudioManager.stopBgm error: $e');
    }
  }

  Future<void> enterGameplay() async {
    _gameplayDepth++;
    _playingBgm = null;
    ++_bgmOpId;
    try {
      await _activeBackend.stopBgm();
    } catch (e) {
      debugPrint('AudioManager.enterGameplay error: $e');
    }
  }

  Future<void> exitGameplay() async {
    if (_gameplayDepth > 0) {
      _gameplayDepth--;
    }
    if (_gameplayDepth == 0 && _wantsBgm && !isMuted.value && _currentBgm != null) {
      await playBgm(_currentBgm!);
    }
  }

  Future<void> playSfx(String assetName) async {
    if (isMuted.value) return;

    try {
      await _activeBackend.playSfx(assetName);
    } catch (e) {
      debugPrint('AudioManager.playSfx error: $e');
    }
  }

  Future<void> toggleMute() async {
    isMuted.value = !isMuted.value;

    if (isMuted.value) {
      _playingBgm = null;
      ++_bgmOpId;
      try {
        await _activeBackend.stopBgm();
      } catch (e) {
        debugPrint('AudioManager.toggleMute stopBgm error: $e');
      }
    } else if (_wantsBgm && _gameplayDepth == 0 && _currentBgm != null) {
      await playBgm(_currentBgm!);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('audio_muted', isMuted.value);
    } catch (e) {
      debugPrint('AudioManager.toggleMute persistence error: $e');
    }
  }
}
