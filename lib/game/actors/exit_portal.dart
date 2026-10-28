import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

class ExitPortal extends PositionComponent
    with CollisionCallbacks, HasGameReference<TrapDashGame> {
  bool isFakeFirst;
  Vector2? realTargetPosition;
  Sprite? _doorSprite;
  Sprite? _teleportSprite;
  bool _isEntering = false;
  double _openTimer = 0.0;

  ExitPortal({
    required Vector2 position,
    this.isFakeFirst = false,
    this.realTargetPosition,
  }) : super(
          position: position,
          size: Vector2(45, 40),
          anchor: Anchor.bottomCenter,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(size: size));

    try {
      _doorSprite = await game.loadSprite('game/door.png');
      _teleportSprite = await game.loadSprite('game/teleport.png');
    } catch (_) {
      // Fallback for tests
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isEntering) {
      _openTimer += dt;
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (other is Player && !_isEntering) {
      if (isFakeFirst && realTargetPosition != null) {
        // Decoy portal jumps away to real platform!
        isFakeFirst = false;
        position = realTargetPosition!.clone();
        game.audio.playSfx('trap_trigger.wav');
        game.shakeCamera(intensity: 8.0, duration: 0.25);
        return;
      }

      final requiredKeys = game.controller.config.requiredKeys;
      final collectedKeys = game.controller.keysCollected.value;

      if (collectedKeys >= requiredKeys) {
        _isEntering = true;
        game.audio.playSfx('win.wav');
        other.enterDoor(
          position,
          onComplete: () {
            game.controller.reachExitPortal();
          },
        );
      } else {
        game.audio.playSfx('trap_trigger.wav');
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final requiredKeys = game.controller.config.requiredKeys;
    final hasEnoughKeys = game.controller.keysCollected.value >= requiredKeys;

    if (isFakeFirst && _teleportSprite != null) {
      _teleportSprite!.render(canvas, size: size);
      return;
    }

    if (_doorSprite != null) {
      _doorSprite!.render(canvas, size: size);
      if (!hasEnoughKeys) {
        // Locked door indicator: black overlay
        final lockPaint = Paint()..color = const Color(0x99000000);
        canvas.drawRRect(
          RRect.fromRectAndRadius(size.toRect(), const Radius.circular(4)),
          lockPaint,
        );
      }
    } else {
      // Monotone Level Devil fallback
      final framePaint = Paint()..color = AppPalette.brownSolid;
      canvas.drawRRect(
        RRect.fromRectAndRadius(size.toRect(), const Radius.circular(4)),
        framePaint,
      );

      final innerPaint = Paint()..color = AppPalette.doorTeal;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(6, 6, size.x - 12, size.y - 6),
          const Radius.circular(2),
        ),
        innerPaint,
      );
    }

    if (_isEntering) {
      final openProgress = (_openTimer / 0.45).clamp(0.0, 1.0);
      final darkAperture = Paint()
        ..color = Color.fromARGB((openProgress * 230).toInt(), 0, 0, 0);
      final insetX = (1.0 - openProgress) * (size.x * 0.25);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            6 + insetX,
            6,
            size.x - 12 - (insetX * 2),
            size.y - 6,
          ),
          const Radius.circular(3),
        ),
        darkAperture,
      );
    }
  }
}
