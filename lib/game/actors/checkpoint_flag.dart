import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

class CheckpointFlag extends PositionComponent
    with CollisionCallbacks, HasGameReference<TrapDashGame> {
  final int checkpointId;
  bool isActivated = false;
  Sprite? _unpressedSprite;
  Sprite? _pressedSprite;

  CheckpointFlag({
    required this.checkpointId,
    required Vector2 position,
  }) : super(
          position: position,
          size: Vector2(28, 20),
          anchor: Anchor.bottomCenter,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(
      size: size,
      collisionType: CollisionType.passive,
    ));

    try {
      final cachedImg = game.tryGetCachedImage('game/button.png');
      if (cachedImg != null) {
        _unpressedSprite = Sprite(cachedImg, srcPosition: Vector2(0, 0), srcSize: Vector2(40, 32));
        _pressedSprite = Sprite(cachedImg, srcPosition: Vector2(40, 0), srcSize: Vector2(40, 32));
      } else {
        final img = await game.images.load('game/button.png');
        _unpressedSprite = Sprite(img, srcPosition: Vector2(0, 0), srcSize: Vector2(40, 32));
        _pressedSprite = Sprite(img, srcPosition: Vector2(40, 0), srcSize: Vector2(40, 32));
      }
    } catch (_) {
      // Fallback for tests
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (other is Player && !isActivated) {
      isActivated = true;
      game.lastCheckpointPosition = position.clone();
      game.controller.triggerCheckpoint(checkpointId);
      game.audio.playSfx('unlock.wav');
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (_unpressedSprite != null && _pressedSprite != null) {
      final sprite = isActivated ? _pressedSprite! : _unpressedSprite!;
      sprite.render(canvas, size: size);
    } else {
      // Fallback
      final paint = Paint()
        ..color = isActivated ? AppPalette.doorTeal : AppPalette.brownSolid;
      canvas.drawRRect(
        RRect.fromRectAndRadius(size.toRect(), const Radius.circular(4)),
        paint,
      );
    }
  }
}
