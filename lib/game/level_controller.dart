import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/game/level_config.dart';

class LevelController {
  late LevelConfig config;

  final ValueNotifier<double> timeLeft = ValueNotifier<double>(90.0);
  final ValueNotifier<int> displayTimeSeconds = ValueNotifier<int>(90);
  final ValueNotifier<int> hearts = ValueNotifier<int>(5);
  final ValueNotifier<int> score = ValueNotifier<int>(0);
  final ValueNotifier<int> keysCollected = ValueNotifier<int>(0);
  final ValueNotifier<double> progress = ValueNotifier<double>(0.0);
  final ValueNotifier<double> suddenDeathLeft = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> isGameOver = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isLevelCleared = ValueNotifier<bool>(false);
  final ValueNotifier<int> currentPlatform = ValueNotifier<int>(1);

  final Set<int> _visitedCheckpoints = <int>{};
  final Set<String> _baitedTraps = <String>{};

  int _baseScore = 0;
  int _exitBonus = 0;

  void startLevel(LevelConfig newConfig) {
    config = newConfig;
    timeLeft.value = config.timeLimit;
    displayTimeSeconds.value = config.timeLimit.ceil();
    hearts.value = config.initialHearts;
    score.value = 0;
    keysCollected.value = 0;
    progress.value = 0.0;
    currentPlatform.value = 1;
    suddenDeathLeft.value = 0.0;
    isGameOver.value = false;
    isLevelCleared.value = false;

    _visitedCheckpoints.clear();
    _baitedTraps.clear();
    _baseScore = 0;
    _exitBonus = 0;
  }

  void update(double dt) {
    if (isGameOver.value) return;

    if (timeLeft.value > 0) {
      timeLeft.value = max(0.0, timeLeft.value - dt);
      final nextCeil = timeLeft.value.ceil();
      if (nextCeil != displayTimeSeconds.value) {
        displayTimeSeconds.value = nextCeil;
      }
      if (timeLeft.value <= 0.0) {
        endLevel(false);
      }
    }

    if (suddenDeathLeft.value > 0) {
      suddenDeathLeft.value = max(0.0, suddenDeathLeft.value - dt);
      if (suddenDeathLeft.value <= 0.0) {
        endLevel(false);
      }
    }
  }

  void triggerCheckpoint(int checkpointId) {
    if (isGameOver.value) return;

    if (_visitedCheckpoints.add(checkpointId)) {
      _baseScore += 100;
      _updateTotalScore();
    }
  }

  void collectCoin() {
    if (isGameOver.value) return;

    _baseScore += 50;
    _updateTotalScore();
  }

  void collectKey() {
    if (isGameOver.value) return;

    keysCollected.value++;
    _baseScore += 50;
    _updateTotalScore();
  }

  void onTrapBait(String trapId) {
    if (isGameOver.value) return;

    if (_baitedTraps.add(trapId)) {
      _baseScore += 25;
      _updateTotalScore();
    }
  }

  void onPlayerHurt() {
    if (isGameOver.value) return;

    hearts.value = max(0, hearts.value - 1);
    _baseScore = max(0, _baseScore - 25);
    _updateTotalScore();

    if (hearts.value <= 0) {
      endLevel(false);
    }
  }

  void reachExitPortal() {
    if (isGameOver.value) return;

    if (keysCollected.value < config.requiredKeys) {
      return;
    }

    _exitBonus = 300 + (timeLeft.value.ceil() * 10);
    _updateTotalScore();
    endLevel(true);
  }

  int calculateStars() {
    if (!isLevelCleared.value) return 0;

    final target3StarHearts = min(3, config.initialHearts - 1);
    final has3StarTime = timeLeft.value > (0.50 * config.timeLimit);
    final has3StarHearts = hearts.value >= target3StarHearts;

    if (has3StarTime && has3StarHearts) {
      return 3;
    }

    final has2StarTime = timeLeft.value > (0.25 * config.timeLimit);
    final has2StarHearts = hearts.value >= 2;

    if (has2StarTime || has2StarHearts) {
      return 2;
    }

    return 1;
  }

  void endLevel(bool won) {
    if (isGameOver.value) return;

    isGameOver.value = true;
    isLevelCleared.value = won;

    final stars = calculateStars();
    GameState.instance.lastResult = {
      'level': config.levelNumber,
      'won': won,
      'score': score.value,
      'timeLeft': timeLeft.value,
      'heartsLeft': hearts.value,
      'stars': stars,
    };

    if (won) {
      GameState.instance.completeLevel(config.levelNumber, stars);
    }
  }

  void _updateTotalScore() {
    score.value = max(0, _baseScore) + _exitBonus;
  }

  void dispose() {
    timeLeft.dispose();
    displayTimeSeconds.dispose();
    hearts.dispose();
    score.dispose();
    keysCollected.dispose();
    progress.dispose();
    suddenDeathLeft.dispose();
    isGameOver.dispose();
    isLevelCleared.dispose();
  }
}
