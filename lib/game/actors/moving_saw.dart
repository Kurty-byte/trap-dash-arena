import 'dart:math';
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
  final List<bool>? proximityJumpPattern;
  final List<List<bool>>? proximityJumpPatternSets;
  final double proximityTriggerDistance;
  final double jumpOffsetY;
  final double jumpDuration;

  late final double _totalDistance;
  late final double _pathDeltaX;
  late final double _pathDeltaY;

  double _t = 0.0;
  int _direction = 1;
  double _rotationAngle = 0.0;
  int proximityPatternIndex = 0;
  int activePatternSetIndex = 0;
  bool _inProximityZone = false;
  double _jumpTimer = 0.0;
  Sprite? _sawSprite;
  late final CircleHitbox hitbox;

  List<bool>? get activeProximityJumpPattern {
    if (proximityJumpPatternSets != null && proximityJumpPatternSets!.isNotEmpty) {
      return proximityJumpPatternSets![activePatternSetIndex % proximityJumpPatternSets!.length];
    }
    return proximityJumpPattern;
  }

  MovingSaw({
    required this.pathStart,
    required this.pathEnd,
    this.speed = 120.0,
    double radius = 18.0,
    this.proximityJumpPattern,
    this.proximityJumpPatternSets,
    this.proximityTriggerDistance = 115.0,
    this.jumpOffsetY = -70.0,
    this.jumpDuration = 0.48,
    int priority = -1,
  }) : super(
          position: pathStart.clone(),
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
          priority: priority,
        ) {
    _pathDeltaX = pathEnd.x - pathStart.x;
    _pathDeltaY = pathEnd.y - pathStart.y;
    _totalDistance = sqrt(_pathDeltaX * _pathDeltaX + _pathDeltaY * _pathDeltaY);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    hitbox = CircleHitbox(
      radius: size.x / 2 - 2,
      position: Vector2.all(2),
      collisionType: CollisionType.passive,
    );
    add(hitbox);

    try {
      final cached = game.tryGetCachedSprite('game/sew.png');
      if (cached != null) {
        _sawSprite = cached;
      } else {
        _sawSprite = await game.loadSprite('game/sew.png');
      }
    } catch (_) {
      // Fallback for tests
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    double verticalJumpOffset = 0.0;
    final currentJumpPattern = activeProximityJumpPattern;
    if (currentJumpPattern != null && currentJumpPattern.isNotEmpty) {
      try {
        final player = game.player;
        if (!player.isInDeathCycle) {
          final dist = (player.position.x - position.x).abs();
          if (dist <= proximityTriggerDistance && !_inProximityZone) {
            _inProximityZone = true;
            final shouldJump = currentJumpPattern[proximityPatternIndex];
            proximityPatternIndex =
                (proximityPatternIndex + 1) % currentJumpPattern.length;
            if (shouldJump) {
              _jumpTimer = jumpDuration;
            }
          } else if (dist > proximityTriggerDistance + 48.0) {
            _inProximityZone = false;
          }
        }
      } catch (_) {
        // Fallback when player is not attached in unit tests
      }

      if (_jumpTimer > 0) {
        _jumpTimer = max(0.0, _jumpTimer - dt);
        verticalJumpOffset =
            sin((1.0 - _jumpTimer / jumpDuration) * pi) * jumpOffsetY;
      }
    }

    if (_totalDistance > 0) {
      _t += (_direction * speed * dt) / _totalDistance;
      if (_t >= 1.0) {
        _t = 1.0;
        _direction = -1;
      } else if (_t <= 0.0) {
        _t = 0.0;
        _direction = 1;
      }
      position.setValues(
        pathStart.x + _pathDeltaX * _t,
        pathStart.y + _pathDeltaY * _t + verticalJumpOffset,
      );
    } else {
      position.setValues(
        pathStart.x,
        pathStart.y + verticalJumpOffset,
      );
    }

    _rotationAngle += dt * 12.0;
  }

  void resetToInitial() {
    _t = 0.0;
    _direction = 1;
    _rotationAngle = 0.0;
    proximityPatternIndex = 0;
    _inProximityZone = false;
    _jumpTimer = 0.0;
    position.setFrom(pathStart);
    if (proximityJumpPatternSets != null && proximityJumpPatternSets!.length > 1) {
      activePatternSetIndex = (activePatternSetIndex + 1) % proximityJumpPatternSets!.length;
    }
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
