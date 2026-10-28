import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class GameState {
  static final GameState instance = GameState._();
  GameState._();

  static const int totalLevels = 5;
  int unlockedLevel = 1;
  Map<int, int> bestStars = {};
  int currentLevel = 1;
  String mode = 'offline'; // 'offline' or 'online'
  bool highContrastTells = false;
  bool aiBotEnabled = false;
  String playerNickname = 'Runner';
  Map<String, dynamic> lastResult = {};

  bool isUnlocked(int level) => level <= unlockedLevel;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    unlockedLevel = prefs.getInt('unlocked_level') ?? 1;
    highContrastTells = prefs.getBool('high_contrast_tells') ?? false;
    aiBotEnabled = prefs.getBool('ai_bot_enabled') ?? false;
    playerNickname = prefs.getString('player_nickname') ?? 'Runner';

    final starsJson = prefs.getString('best_stars');
    if (starsJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(starsJson);
        bestStars = decoded.map((k, v) => MapEntry(int.parse(k), v as int));
      } catch (_) {
        bestStars = {};
      }
    }
  }

  Future<void> completeLevel(int level, int stars) async {
    if (mode != 'offline') return;

    final currentBest = bestStars[level] ?? 0;
    if (stars > currentBest) {
      bestStars[level] = stars;
    }

    if (level == unlockedLevel && level < totalLevels) {
      unlockedLevel = level + 1;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('unlocked_level', unlockedLevel);
    await prefs.setString(
      'best_stars',
      jsonEncode(bestStars.map((k, v) => MapEntry('$k', v))),
    );
  }

  void setMode(String newMode) {
    mode = newMode;
  }

  Future<void> setHighContrastTells(bool enabled) async {
    highContrastTells = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('high_contrast_tells', enabled);
  }

  Future<void> setAiBotEnabled(bool enabled) async {
    aiBotEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_bot_enabled', enabled);
  }

  Future<void> setPlayerNickname(String name) async {
    playerNickname = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_nickname', name);
  }

  Future<void> resetProgress() async {
    unlockedLevel = 1;
    bestStars = {};
    currentLevel = 1;
    mode = 'offline';
    highContrastTells = false;
    aiBotEnabled = false;
    playerNickname = 'Runner';
    lastResult = {};

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('unlocked_level');
    await prefs.remove('best_stars');
    await prefs.remove('high_contrast_tells');
    await prefs.remove('ai_bot_enabled');
    await prefs.remove('player_nickname');
  }
}
