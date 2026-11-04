import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

enum SpikeBehavior {
  stationary,
  proximityPopUp,
  slideRightOnJump,
  riseOnProximity,
  doubleSlideTrap,
}

class TrapSpike extends PositionComponent
    with CollisionCallbacks, HasGameReference<TrapDashGame> {
  final String trapId;
  final bool isStatic;
  final SpikeBehavior behavior;
  final double triggerDistance;
  final double jitterDuration;
  final bool hideCompletelyWhenIdle;
  final double slideRightDistance;
  final double slideLeftDistance;
  final double slideSpeed;
  final double returnSlideSpeed;
  final double riseHeight;
  final double riseSpeed;

  bool isRevealed = false;
  bool isTriggered = false;
  bool isExtended = false;

  late final Vector2 _initialPosition;
  int _trapPhase = 0;
  double _phaseTimer = 0.0;
  double _jitterTimer = 0.30;
  double _survivalTimer = 0.50;
  bool _baitAwarded = false;
  double _jitterOffsetX = 0.0;
  Sprite? _obstacleSprite;

  final RectangleHitbox hitbox;
  late final Rect _boundsRect = Rect.fromLTWH(0, 0, size.x, size.y);
  late final Rect _warningRect = Rect.fromLTWH(0, size.y - 4, size.x, 4);
  final Vector2 _renderPos = Vector2.zero();

  static final Paint _solidPaint = Paint()..color = AppPalette.brownSolid;
  static final Paint _darkPaint = Paint()..color = AppPalette.brownDark;
  static final Paint _warningPaint = Paint()
    ..color = AppPalette.warningRed
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  TrapSpike({
    required this.trapId,
    required Vector2 position,
    this.isStatic = false,
    SpikeBehavior? behavior,
    this.triggerDistance = 48.0,
    this.jitterDuration = 0.30,
    this.hideCompletelyWhenIdle = false,
    this.slideRightDistance = 96.0,
    this.slideLeftDistance = 80.0,
    this.slideSpeed = 460.0,
    this.returnSlideSpeed = 480.0,
    this.riseHeight = 88.0,
    this.riseSpeed = 680.0,
  })  : behavior = behavior ??
            (isStatic ? SpikeBehavior.stationary : SpikeBehavior.proximityPopUp),
        hitbox = RectangleHitbox(
          size: Vector2(32, 24),
          position: Vector2(2, 2),
          collisionType: CollisionType.passive,
        ),
        super(
          position: position,
          size: Vector2(36, 26),
          anchor: Anchor.bottomCenter,
        ) {
    _initialPosition = position.clone();
    _jitterTimer = jitterDuration;
    if (this.behavior != SpikeBehavior.proximityPopUp) {
      isExtended = true;
    }
    add(hitbox);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      final cached = game.tryGetCachedSprite('game/obstacle.png');
      if (cached != null) {
        _obstacleSprite = cached;
      } else {
        _obstacleSprite = await game.loadSprite('game/obstacle.png');
      }
    } catch (_) {
      // Fallback for tests
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final player = game.player;

    switch (behavior) {
      case SpikeBehavior.stationary:
        break;

      case SpikeBehavior.proximityPopUp:
        if (!isTriggered && !isExtended) {
          if (!player.isInDeathCycle) {
            if (player.position.distanceToSquared(position) <=
                triggerDistance * triggerDistance) {
              triggerJitter();
            }
          }
        }

        if (isTriggered && !isExtended) {
          _jitterTimer -= dt;
          _jitterOffsetX = (sin(_jitterTimer * 50) * 2.0);

          if (_jitterTimer <= 0) {
            thrustUp();
          }
        }

        if (isTriggered && !_baitAwarded) {
          _survivalTimer -= dt;
          if (_survivalTimer <= 0) {
            _baitAwarded = true;
            game.controller.onTrapBait(trapId);
          }
        }
        break;

      case SpikeBehavior.slideRightOnJump:
        if (!isTriggered) {
          if (!player.isInDeathCycle &&
              !player.isOnGround &&
              player.position.x >= _initialPosition.x - 56.0 &&
              player.position.x <= _initialPosition.x + 36.0 &&
              player.position.y <= _initialPosition.y - 16.0) {
            isTriggered = true;
            game.audio.playSfx('trap_trigger.wav');
          }
        } else {
          final targetX = _initialPosition.x + slideRightDistance;
          if (position.x < targetX) {
            position.x = min(targetX, position.x + slideSpeed * dt);
          }

          if (!_baitAwarded && position.x >= targetX) {
            _survivalTimer -= dt;
            if (_survivalTimer <= 0) {
              _baitAwarded = true;
              game.controller.onTrapBait(trapId);
            }
          }
        }
        break;

      case SpikeBehavior.riseOnProximity:
        if (!isTriggered) {
          if (!player.isInDeathCycle &&
              (player.position.x - _initialPosition.x).abs() <= triggerDistance) {
            isTriggered = true;
            game.audio.playSfx('trap_trigger.wav');
          }
        } else {
          final targetY = _initialPosition.y - riseHeight;
          if (position.y > targetY) {
            position.y = max(targetY, position.y - riseSpeed * dt);
          }

          if (!_baitAwarded && position.y <= targetY) {
            _survivalTimer -= dt;
            if (_survivalTimer <= 0) {
              _baitAwarded = true;
              game.controller.onTrapBait(trapId);
            }
          }
        }
        break;

      case SpikeBehavior.doubleSlideTrap:
        if (_trapPhase == 0) {
          if (!player.isInDeathCycle &&
              (player.position.x - _initialPosition.x).abs() <= triggerDistance) {
            isTriggered = true;
            _trapPhase = 1;
            game.audio.playSfx('trap_trigger.wav');
          }
        } else if (_trapPhase == 1) {
          final targetRightX = _initialPosition.x + slideRightDistance;
          if (position.x < targetRightX) {
            position.x = min(targetRightX, position.x + slideSpeed * dt);
          }
          if (position.x >= targetRightX) {
            _trapPhase = 2;
            _phaseTimer = 0.0;
          }
        } else if (_trapPhase == 2) {
          // Waiting for player to land on the left
          if (!player.isInDeathCycle &&
              player.isOnGround &&
              player.position.x < position.x - 24.0) {
            _phaseTimer += dt;
            if (_phaseTimer >= 0.06) {
              _trapPhase = 3;
              game.audio.playSfx('trap_trigger.wav');
            }
          }
        } else if (_trapPhase == 3) {
          final targetLeftX = _initialPosition.x - slideLeftDistance;
          if (position.x > targetLeftX) {
            position.x = max(targetLeftX, position.x - returnSlideSpeed * dt);
          }
          if (position.x <= targetLeftX) {
            _trapPhase = 4;
          }
        } else if (_trapPhase == 4) {
          if (!_baitAwarded) {
            _survivalTimer -= dt;
            if (_survivalTimer <= 0) {
              _baitAwarded = true;
              game.controller.onTrapBait(trapId);
            }
          }
        }
        break;
    }
  }

  void triggerJitter() {
    isTriggered = true;
    game.audio.playSfx('trap_trigger.wav');
  }

  void thrustUp() {
    isExtended = true;
    _jitterOffsetX = 0.0;
  }

  void retract() {
    if (behavior != SpikeBehavior.stationary) {
      if (isTriggered) {
        isRevealed = true;
      }
      isTriggered = false;
      position.setFrom(_initialPosition);
      _jitterTimer = jitterDuration;
      _survivalTimer = 0.50;
      _jitterOffsetX = 0.0;
      _trapPhase = 0;
      _phaseTimer = 0.0;
      _baitAwarded = false;
      if (behavior == SpikeBehavior.proximityPopUp) {
        isExtended = false;
      } else {
        isExtended = true;
      }
    }
  }

  @override
  void onCollision(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollision(intersectionPoints, other);

    if (other is Player && isExtended) {
      other.takeDamage();
    }
  }

  @override
  void render(Canvas canvas) {
    if (hideCompletelyWhenIdle &&
        !isTriggered &&
        !isExtended &&
        !isRevealed &&
        !GameState.instance.highContrastTells) {
      return;
    }

    super.render(canvas);

    final isHighContrast = GameState.instance.highContrastTells;

    final hasJitter = _jitterOffsetX != 0.0;
    if (hasJitter) {
      canvas.save();
      canvas.translate(_jitterOffsetX, 0);
    }

    final isVisible = isExtended || isStatic;
    final yOffset = isVisible ? 0.0 : (isTriggered ? size.y - 10 : size.y - 4);

    if (_obstacleSprite != null) {
      if (!isVisible) {
        canvas.save();
        canvas.clipRect(_boundsRect);
      }
      _renderPos.setValues(0, yOffset);
      _obstacleSprite!.render(
        canvas,
        position: _renderPos,
        size: size,
      );
      if (!isVisible) {
        canvas.restore();
      }
    } else {
      final paint = isVisible ? _solidPaint : _darkPaint;
      final stepW = size.x / 3;
      final h = isVisible ? size.y : 4.0;
      for (int i = 0; i < 3; i++) {
        canvas.drawRect(
          Rect.fromLTWH(i * stepW + 1, size.y - h, stepW - 2, h),
          paint,
        );
      }
    }

    // High-contrast or revealed warning outline
    if (isRevealed || isHighContrast) {
      canvas.drawRect(_warningRect, _warningPaint);
    }

    if (hasJitter) {
      canvas.restore();
    }
  }
}
