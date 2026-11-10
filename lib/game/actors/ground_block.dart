import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/actors/player.dart';

class GroundBlock extends PositionComponent with CollisionCallbacks {
  bool isActive;

  GroundBlock({
    required Vector2 position,
    required Vector2 size,
    this.isActive = true,
  }) : super(
          position: position,
          size: size,
          anchor: Anchor.topLeft,
          children: [RectangleHitbox(size: size, collisionType: CollisionType.passive)],
        );

  @override
  void onCollision(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollision(intersectionPoints, other);
    if (!isActive) return;

    if (other is Player) {
      resolvePlayerBlockCollision(
        other,
        position.x,
        position.y,
        position.x + size.x,
        position.y + size.y,
      );
    }
  }

  static void resolvePlayerBlockCollision(
    Player other,
    double blockLeft,
    double blockTop,
    double blockRight,
    double blockBottom,
  ) {
    final playerBottom = other.position.y;
    final playerTop = other.position.y - 36.0;
    final playerLeft = other.position.x - 10.0;
    final playerRight = other.position.x + 10.0;

    final overlapTop = playerBottom - blockTop;
    final overlapBottom = blockBottom - playerTop;
    final overlapLeft = playerRight - blockLeft;
    final overlapRight = blockRight - playerLeft;

    if (overlapTop <= 0 || overlapBottom <= 0 || overlapLeft <= 0 || overlapRight <= 0) {
      return;
    }

    // Ledge landing forgiveness: when falling onto corner, prioritize floor landing
    final isFalling = other.velocity.y >= 0;
    final isNearTop = overlapTop <= 14.0 && overlapTop <= min(overlapLeft, overlapRight) + 6.0;

    if (isFalling && isNearTop) {
      other.position.y = blockTop;
      other.velocity.y = 0;
      other.isOnGround = true;
      return;
    }

    final minOverlap = min(min(overlapTop, overlapBottom), min(overlapLeft, overlapRight));

    if (minOverlap == overlapTop && isFalling) {
      other.position.y = blockTop;
      other.velocity.y = 0;
      other.isOnGround = true;
    } else if (minOverlap == overlapBottom && other.velocity.y < 0) {
      // Ceiling bonk
      other.position.y = blockBottom + 36.0;
      other.velocity.y = 0;
    } else if (minOverlap == overlapLeft) {
      other.position.x = blockLeft - 10.0;
      if (other.velocity.x > 0) {
        other.velocity.x = 0;
      }
    } else if (minOverlap == overlapRight) {
      other.position.x = blockRight + 10.0;
      if (other.velocity.x < 0) {
        other.velocity.x = 0;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (!isActive) return;
    super.render(canvas);

    // Monolithic flat rust brown block with subpixel margin to prevent hairline seams
    final basePaint = Paint()
      ..color = AppPalette.brownSolid
      ..isAntiAlias = false;
    canvas.drawRect(
      Rect.fromLTWH(-0.5, -0.5, size.x + 1.0, size.y + 1.0),
      basePaint,
    );
  }
}
