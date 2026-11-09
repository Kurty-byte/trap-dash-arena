import 'dart:math';
import 'dart:ui' as ui;
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
import 'package:trap_dash_arena/game/actors/control_inverter_zone.dart';
import 'package:trap_dash_arena/game/actors/disappearing_platform.dart';
import 'package:trap_dash_arena/game/actors/fake_floor.dart';
import 'package:trap_dash_arena/game/actors/falling_block.dart';
import 'package:trap_dash_arena/game/actors/moving_gap_floor.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/actors/sudden_gap.dart';
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

  int _roomCount = 1;
  int get roomCount => _roomCount;
  final Vector2 _cameraFocus = Vector2(640, 360);
  Vector2 get cameraFocus => _cameraFocus;

  double targetRoomCenterXFor(double worldX) {
    final roomIndex = (worldX / 1280.0).floor().clamp(0, _roomCount - 1);
    return roomIndex * 1280.0 + 640.0;
  }

  double _trauma = 0.0;
  final Random _random = Random();
  double _exitX = 1128.0;
  double get exitX => _exitX;

  double _netUpdateTimer = 0.0;
  int _lastReportedScore = -1;
  double _lastReportedProgress = -1.0;
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
  Color backgroundColor() => AppPalette.brownSolid;

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
        'game/hud.png',
      ]);
    } catch (_) {}

    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = viewportCenter.clone();
    await loadLevel(currentLevelNumber);
  }

  ui.Image? tryGetCachedImage(String path) {
    try {
      if (images.containsKey(path)) {
        return images.fromCache(path);
      }
    } catch (_) {}
    return null;
  }

  Sprite? tryGetCachedSprite(String path, {Vector2? srcPosition, Vector2? srcSize}) {
    final img = tryGetCachedImage(path);
    if (img != null) {
      return Sprite(img, srcPosition: srcPosition, srcSize: srcSize);
    }
    return null;
  }

  Future<void> loadLevel(int levelNumber) async {
    if (overlays.registeredOverlays.contains('LoadingOverlay')) {
      overlays.add('LoadingOverlay');
    }
    currentLevelNumber = levelNumber;
    world.removeAll(world.children);

    final config = LevelConfig.get(levelNumber);
    _roomCount = config.roomCount;
    controller.startLevel(config);

    // Camera initial framing
    camera.stop();
    _cameraFocus.setValues(640, 360);
    camera.viewfinder.position.setFrom(_cameraFocus);

    // Load enclosed chamber geometry and objects
    final chamberResult = await ChamberLoader.loadIntoWorld(this, config);
    startSpawnPosition = chamberResult.spawnPosition.clone();
    lastCheckpointPosition = startSpawnPosition.clone();
    _exitX = chamberResult.exitX;

    _cameraFocus.setValues(targetRoomCenterXFor(startSpawnPosition.x), 360.0);
    camera.viewfinder.position.setFrom(_cameraFocus);

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
    _lastReportedProgress = -1.0;
    _reportedFinished = false;
  }

  void onPlayerHurt() {
    controller.onPlayerHurt();
    audio.playSfx('hurt.wav');
    shakeCamera(intensity: 12.0, duration: 0.35);
  }

  void onPlayerReadyToRespawn() {
    if (!controller.isGameOver.value) {
      if (overlays.registeredOverlays.contains('RespawnOverlay')) {
        overlays.add('RespawnOverlay');
      }
    }
  }

  void triggerRespawn() {
    if (!player.isAwaitingRespawn || controller.isGameOver.value) return;
    if (overlays.isActive('RespawnOverlay')) {
      overlays.remove('RespawnOverlay');
    }
    audio.playSfx('unlock.wav');
    respawnPlayerAtCheckpoint(playReintegration: true);
  }

  void respawnPlayerAtCheckpoint({bool playReintegration = true}) {
    for (final child in world.children) {
      if (child is FakeFloor) {
        child.resetToSolid();
      } else if (child is TrapSpike) {
        child.retract();
      } else if (child is FallingBlock) {
        child.resetToCeiling();
      } else if (child is DisappearingPlatform) {
        child.isPlatformSolid = true;
        child.hitbox.collisionType = CollisionType.passive;
      } else if (child is SuddenGap) {
        child.resetToSolid();
      } else if (child is MovingGapFloor) {
        child.resetToInitial();
      } else if (child is ControlInverterZone) {
        child.resetToInitial();
      }
    }

    _cameraFocus.setValues(targetRoomCenterXFor(lastCheckpointPosition.x), 360.0);
    camera.viewfinder.position = _cameraFocus.clone();

    final respawnPlatform = (lastCheckpointPosition.x / 1280.0).floor().clamp(0, _roomCount - 1) + 1;
    controller.currentPlatform.value = respawnPlatform;

    player.respawnAt(
      lastCheckpointPosition,
      playReintegration: playReintegration,
    );
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
    if (overlays.isActive('PauseOverlay')) overlays.remove('PauseOverlay');
    if (overlays.isActive('ResultOverlay')) overlays.remove('ResultOverlay');
    if (overlays.isActive('RespawnOverlay')) overlays.remove('RespawnOverlay');
    if (paused) {
      resumeEngine();
    }
    await loadLevel(currentLevelNumber);
  }

  @override
  void update(double dt) {
    super.update(dt);
    controller.update(dt);

    // Update runner progress normalized (0.0 to 1.0) with thresholding
    final span = max(1.0, _exitX - startSpawnPosition.x);
    final progressVal = min(1.0, max(0.0, (player.position.x - startSpawnPosition.x) / span));
    if ((progressVal - controller.progress.value).abs() >= 0.005 || progressVal == 0.0 || progressVal == 1.0) {
      controller.progress.value = progressVal;
    }

    // Update active platform progression index (1..roomCount)
    final activePlatformIndex = (player.position.x / 1280.0).floor().clamp(0, _roomCount - 1) + 1;
    if (controller.currentPlatform.value != activePlatformIndex) {
      controller.currentPlatform.value = activePlatformIndex;
    }

    // Report network multiplayer score and progress
    if (GameState.instance.mode == 'online' && NetManager.instance.isConnected.value) {
      _netUpdateTimer += dt;
      final scoreChanged = controller.score.value != _lastReportedScore;
      final progressChanged = (progressVal - _lastReportedProgress).abs() >= 0.01;
      if (scoreChanged || (_netUpdateTimer >= 0.25 && progressChanged)) {
        _lastReportedScore = controller.score.value;
        _lastReportedProgress = progressVal;
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
    if (controller.isGameOver.value &&
        !player.isDisintegrating &&
        !overlays.isActive('ResultOverlay')) {
      if (overlays.isActive('RespawnOverlay')) {
        overlays.remove('RespawnOverlay');
      }
      pauseEngine();
      if (overlays.registeredOverlays.contains('ResultOverlay')) {
        overlays.add('ResultOverlay');
      }
    }

    // Room-by-room smooth camera panning
    if (!player.isInDeathCycle) {
      final targetCenterX = targetRoomCenterXFor(player.position.x);
      final t = 1.0 - exp(-14.0 * dt);
      _cameraFocus.x += (targetCenterX - _cameraFocus.x) * t;
      if ((targetCenterX - _cameraFocus.x).abs() < 0.5) {
        _cameraFocus.x = targetCenterX;
      }
    }

    // Screen shake around camera focus (zero cumulative drift, idle guard)
    if (_trauma > 0) {
      _trauma = max(0.0, _trauma - dt * 2.0);
      if (_trauma > 0) {
        final shake = _trauma * _trauma * 14.0;
        final offsetX = (_random.nextDouble() * 2 - 1) * shake;
        final offsetY = (_random.nextDouble() * 2 - 1) * shake;
        camera.viewfinder.position = Vector2(
          _cameraFocus.x + offsetX,
          _cameraFocus.y + offsetY,
        );
      } else {
        camera.viewfinder.position = _cameraFocus.clone();
      }
    } else {
      camera.viewfinder.position = _cameraFocus.clone();
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

    if (player.isAwaitingRespawn &&
        event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.keyR)) {
      triggerRespawn();
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
