import 'dart:io';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioManager {
  static final AudioManager instance = AudioManager._();
  AudioManager._();

  final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);
  String? _currentBgm;

  bool get _isTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isMuted.value = prefs.getBool('audio_muted') ?? false;
    } catch (e) {
      debugPrint('AudioManager.init error: $e');
    }
  }

  Future<void> playBgm(String assetName) async {
    _currentBgm = assetName;
    if (isMuted.value || _isTest) return;

    try {
      await FlameAudio.bgm.play(assetName);
    } catch (e) {
      debugPrint('AudioManager.playBgm error: $e');
    }
  }

  void stopBgm() {
    if (_isTest) return;
    try {
      FlameAudio.bgm.stop();
    } catch (e) {
      debugPrint('AudioManager.stopBgm error: $e');
    }
  }

  Future<void> playSfx(String assetName) async {
    if (isMuted.value || _isTest) return;

    try {
      await FlameAudio.play(assetName);
    } catch (e) {
      debugPrint('AudioManager.playSfx error: $e');
    }
  }

  Future<void> toggleMute() async {
    isMuted.value = !isMuted.value;

    if (isMuted.value) {
      stopBgm();
    } else if (_currentBgm != null) {
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
