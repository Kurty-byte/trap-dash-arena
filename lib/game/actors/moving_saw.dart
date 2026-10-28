import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

class MovingSaw extends PositionComponent
    with CollisionCallbacks, HasGameReference<TrapDashGame> {
  final Vector2 pathStart;
  final Vector2 pathEnd;
  final double speed;

  double _t = 0.0;
  int _direction = 1;
  double _rotationAngle = 0.0;
  Sprite? _sawSprite;
  late final CircleHitbox hitbox;

  MovingSaw({
    required this.pathStart,
    required this.pathEnd,
    this.speed = 120.0,
    double radius = 18.0,
  }) : super(
          position: pathStart.clone(),
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    hitbox = CircleHitbox(
      radius: size.x / 2 - 2,
      position: Vector2.all(2),
    );
    add(hitbox);

    try {
      _sawSprite = await game.loadSprite('game/sew.png');
    } catch (_) {
      // Fallback for tests
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    final totalDistance = (pathEnd - pathStart).length;
    if (totalDistance > 0) {
      _t += (_direction * speed * dt) / totalDistance;
      if (_t >= 1.0) {
        _t = 1.0;
        _direction = -1;
      } else if (_t <= 0.0) {
        _t = 0.0;
        _direction = 1;
      }
      position = pathStart + (pathEnd - pathStart) * _t;
    }

    _rotationAngle += dt * 12.0;
  }

  @override
  void onCollision(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollision(intersectionPoints, other);

    if (other is Player) {
      other.takeDamage();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final radius = size.x / 2;

    canvas.save();
    canvas.translate(radius, radius);
    canvas.rotate(_rotationAngle);

    if (_sawSprite != null) {
      _sawSprite!.render(
        canvas,
        position: Vector2(-radius, -radius),
        size: size,
      );
    } else {
      // Fallback
      final bladePaint = Paint()..color = AppPalette.brownSolid;
      canvas.drawCircle(Offset.zero, radius * 0.8, bladePaint);
      final centerPaint = Paint()..color = AppPalette.whiteAccent;
      canvas.drawRect(const Rect.fromLTWH(-3, -3, 6, 6), centerPaint);
    }

    if (GameState.instance.highContrastTells) {
      final warningPaint = Paint()
        ..color = AppPalette.warningRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(Offset.zero, radius, warningPaint);
    }

    canvas.restore();
  }
}
