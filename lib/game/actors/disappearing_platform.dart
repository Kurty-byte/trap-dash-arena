import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/actors/player.dart';

class DisappearingPlatform extends PositionComponent with CollisionCallbacks {
  final double visibleDuration;
  final double invisibleDuration;

  bool isPlatformSolid = true;
  double _timer = 0.0;
  bool _isBlinking = false;
  late final RectangleHitbox hitbox;
  late final Rect _rect = size.toRect();

  static final Paint _contrastOutlinePaint = Paint()
    ..color = AppPalette.warningRed
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  static final Paint _ghostOutlinePaint = Paint()
    ..color = AppPalette.brownDark.withValues(alpha: 0.3)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  final Paint _basePaint = Paint()..color = AppPalette.brownSolid;
  final Paint _borderPaint = Paint()
    ..color = AppPalette.brownDark
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  DisappearingPlatform({
    required Vector2 position,
    required Vector2 size,
    this.visibleDuration = 2.2,
    this.invisibleDuration = 1.4,
  }) : super(
          position: position,
          size: size,
          anchor: Anchor.topLeft,
        ) {
    hitbox = RectangleHitbox(
      size: this.size,
      collisionType: CollisionType.passive,
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(hitbox);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;

    if (isPlatformSolid) {
      if (_timer >= visibleDuration - 0.6) {
        _isBlinking = true;
      }
      if (_timer >= visibleDuration) {
        isPlatformSolid = false;
        _isBlinking = false;
        _timer = 0.0;
        hitbox.collisionType = CollisionType.inactive;
      }
    } else {
      if (_timer >= invisibleDuration) {
        isPlatformSolid = true;
        _timer = 0.0;
        hitbox.collisionType = CollisionType.passive;
      }
    }
  }

  @override
  void onCollision(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollision(intersectionPoints, other);

    if (other is Player && isPlatformSolid) {
      if (other.velocity.y >= 0 && other.position.y <= position.y + 14) {
        other.position.y = position.y;
        other.velocity.y = 0;
        other.isOnGround = true;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (!isPlatformSolid) {
      // Ghosted dashed outline when inactive
      final outlinePaint = GameState.instance.highContrastTells
          ? _contrastOutlinePaint
          : _ghostOutlinePaint;
      canvas.drawRect(_rect, outlinePaint);
      return;
    }

    // Blinking effect before vanishing
    final alpha = (_isBlinking && ((_timer * 10).toInt() % 2 == 0)) ? 80 : 255;

    _basePaint.color = AppPalette.brownSolid.withAlpha(alpha);
    canvas.drawRect(_rect, _basePaint);

    _borderPaint.color = AppPalette.brownDark.withAlpha(alpha);
    canvas.drawRect(_rect, _borderPaint);
  }
}
