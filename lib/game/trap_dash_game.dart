import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:trap_dash_arena/autoload/audio_manager.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/net_manager.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/actors/disappearing_platform.dart';
import 'package:trap_dash_arena/game/actors/fake_floor.dart';
import 'package:trap_dash_arena/game/actors/falling_block.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/actors/trap_spike.dart';
import 'package:trap_dash_arena/game/chamber_loader.dart';
import 'package:trap_dash_arena/game/level_config.dart';
import 'package:trap_dash_arena/game/level_controller.dart';
import 'package:trap_dash_arena/game/simple_ai.dart';

class TrapDashGame extends FlameGame
    with HasCollisionDetection, KeyboardEvents {
  static final Vector2 viewportCenter = Vector2(640, 360);

  int currentLevelNumber;
  final LevelController controller = LevelController();
  final AudioManager audio = AudioManager.instance;

  late Player player;
  SimpleAI? paceBot;
  Vector2 startSpawnPosition = Vector2(148, 552);
  Vector2 lastCheckpointPosition = Vector2(148, 552);

  double _trauma = 0.0;
  final Random _random = Random();
  double _exitX = 1128.0;
  double get exitX => _exitX;

  double _netUpdateTimer = 0.0;
  int _lastReportedScore = -1;
  bool _reportedFinished = false;

  TrapDashGame({int? initialLevelNumber, int? currentLevelNumber})
      : currentLevelNumber = currentLevelNumber ?? initialLevelNumber ?? 1,
        super(
          camera: CameraComponent.withFixedResolution(
            width: 1280,
            height: 720,
          ),
        );

  @override
  Color backgroundColor() => AppPalette.yellowBackground;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    images.prefix = 'assets/';
    try {
      await images.loadAll([
        'game/player.png',
        'game/door.png',
        'game/obstacle.png',
        'game/sew.png',
        'game/spring.png',
        'game/coin.png',
        'game/button.png',
        'game/bomb.png',
        'game/teleport.png',
      ]);
    } catch (_) {}

    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = viewportCenter.clone();
    await loadLevel(currentLevelNumber);
  }

  Future<void> loadLevel(int levelNumber) async {
    if (overlays.registeredOverlays.contains('LoadingOverlay')) {
      overlays.add('LoadingOverlay');
    }
    currentLevelNumber = levelNumber;
    world.removeAll(world.children);

    final config = LevelConfig.get(levelNumber);
    controller.startLevel(config);

    // Fixed single-screen camera framing
    camera.stop();
    camera.viewfinder.position = viewportCenter.clone();

    // Load enclosed chamber geometry and objects
    final chamberResult = await ChamberLoader.loadIntoWorld(this, config);
    startSpawnPosition = chamberResult.spawnPosition.clone();
    lastCheckpointPosition = startSpawnPosition.clone();
    _exitX = chamberResult.exitX;

    // Spawn player inside chamber
    player = Player(position: startSpawnPosition);
    world.add(player);

    // Spawn offline Pace-Bot rival if enabled
    if (GameState.instance.aiBotEnabled) {
      paceBot = SimpleAI(
        levelNumber: levelNumber,
        startPosition: startSpawnPosition,
        defaultExitX: _exitX,
      );
      world.add(paceBot!);
    } else {
      paceBot = null;
    }

    await ready();
    if (overlays.isActive('LoadingOverlay')) {
      overlays.remove('LoadingOverlay');
    }

    _netUpdateTimer = 0.0;
    _lastReportedScore = -1;
    _reportedFinished = false;

    audio.playBgm('bgm.ogg');
  }

  void onPlayerHurt() {
    controller.onPlayerHurt();
    audio.playSfx('hurt.wav');
    shakeCamera(intensity: 12.0, duration: 0.35);

    if (controller.hearts.value > 0) {
      respawnPlayerAtCheckpoint();
    }
  }

  void respawnPlayerAtCheckpoint() {
    player.respawnAt(lastCheckpointPosition);

    for (final child in world.children) {
      if (child is FakeFloor) {
        child.resetToSolid();
      } else if (child is TrapSpike) {
        child.retract();
      } else if (child is FallingBlock) {
        child.resetToCeiling();
      } else if (child is DisappearingPlatform) {
        child.isPlatformSolid = true;
        child.hitbox.collisionType = CollisionType.active;
      }
    }
  }

  void shakeCamera({double intensity = 10.0, double duration = 0.35}) {
    _trauma = min(1.0, _trauma + (intensity / 15.0));
  }

  void pauseGame() {
    pauseEngine();
    overlays.add('PauseOverlay');
  }

  void resumeGame() {
    overlays.remove('PauseOverlay');
    resumeEngine();
  }

  Future<void> restartLevel() async {
    overlays.remove('PauseOverlay');
    overlays.remove('ResultOverlay');
    if (paused) {
      resumeEngine();
    }
    await loadLevel(currentLevelNumber);
  }

  @override
  void update(double dt) {
    super.update(dt);
    controller.update(dt);

    // Update runner progress normalized (0.0 to 1.0)
    final span = max(1.0, _exitX - startSpawnPosition.x);
    final progressVal = min(1.0, max(0.0, (player.position.x - startSpawnPosition.x) / span));
    controller.progress.value = progressVal;

    // Report network multiplayer score and progress
    if (GameState.instance.mode == 'online' && NetManager.instance.isConnected.value) {
      _netUpdateTimer += dt;
      if (controller.score.value != _lastReportedScore || _netUpdateTimer >= 0.25) {
        _lastReportedScore = controller.score.value;
        _netUpdateTimer = 0.0;
        NetManager.instance.sendScore(
          score: controller.score.value,
          progress: progressVal,
        );
      }

      if (controller.isGameOver.value && !_reportedFinished) {
        _reportedFinished = true;
        NetManager.instance.reportFinished(
          score: controller.score.value,
          won: controller.isLevelCleared.value,
        );
      }
    }

    // Trigger ResultOverlay when level ends (loss or victory)
    if (controller.isGameOver.value && !overlays.isActive('ResultOverlay')) {
      pauseEngine();
      overlays.add('ResultOverlay');
    }

    // Screen shake around fixed viewport center (zero cumulative drift)
    if (_trauma > 0) {
      _trauma = max(0.0, _trauma - dt * 2.0);
      final shake = _trauma * _trauma * 14.0;
      final offsetX = (_random.nextDouble() * 2 - 1) * shake;
      final offsetY = (_random.nextDouble() * 2 - 1) * shake;
      camera.viewfinder.position = Vector2(
        viewportCenter.x + offsetX,
        viewportCenter.y + offsetY,
      );
    } else {
      camera.viewfinder.position = viewportCenter.clone();
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      if (overlays.isActive('PauseOverlay')) {
        resumeGame();
      } else {
        pauseGame();
      }
      return KeyEventResult.handled;
    }

    final isLeft = keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA);
    final isRight = keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD);
    final isJump = keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
        keysPressed.contains(LogicalKeyboardKey.keyW) ||
        keysPressed.contains(LogicalKeyboardKey.space);

    if (isLeft && !isRight) {
      player.moveLeft();
    } else if (isRight && !isLeft) {
      player.moveRight();
    } else {
      player.stopMoving();
    }

    if (event is KeyDownEvent && isJump) {
      player.jump();
    } else if (event is KeyUpEvent && !isJump) {
      player.cutJump();
    }

    return KeyEventResult.handled;
  }
}
