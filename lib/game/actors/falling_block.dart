import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

class FallingBlock extends PositionComponent
    with CollisionCallbacks, HasGameReference<TrapDashGame> {
  final String trapId;
  final double groundY;
  final Vector2 initialPosition;
  final bool manualTriggerOnly;
  final bool Function()? shouldHoldFall;

  bool isRevealed = false;
  bool isTriggered = false;
  bool isFalling = false;
  bool hasLanded = false;

  double _telegraphTimer = 0.25;
  double _shakeOffsetX = 0.0;
  double _fallVelocity = 0.0;
  bool _baitAwarded = false;
  double _survivalTimer = 0.50;
  Sprite? _bombSprite;

  late final RectangleHitbox hitbox = RectangleHitbox(
    size: size,
    collisionType: CollisionType.passive,
  );
  late final Rect _rect = size.toRect();
  late final Offset _lineP1 = Offset(0, size.y - 1);
  late final Offset _lineP2 = Offset(size.x, size.y - 1);

  static final Paint _warningBlockPaint = Paint()..color = AppPalette.warningRed;
  static final Paint _defaultBlockPaint = Paint()
    ..color = Color.lerp(AppPalette.brownSolid, AppPalette.brownDark, 0.35)!;
  static final Paint _linePaint = Paint()
    ..color = AppPalette.brownDark
    ..strokeWidth = 1.5;

  FallingBlock({
    required this.trapId,
    required Vector2 position,
    required this.groundY,
    Vector2? size,
    this.manualTriggerOnly = false,
    this.shouldHoldFall,
  })  : initialPosition = position.clone(),
        super(
          position: position,
          size: size ?? Vector2(40, 36),
          anchor: Anchor.topLeft,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (!contains(hitbox)) {
      add(hitbox);
    }

    try {
      final cached = game.tryGetCachedSprite('game/bomb.png');
      if (cached != null) {
        _bombSprite = cached;
      } else {
        _bombSprite = await game.loadSprite('game/bomb.png');
      }
    } catch (_) {
      // Fallback for tests
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!manualTriggerOnly && !isTriggered && !hasLanded) {
      // Proximity sensor: triggers if player enters within 64px horizontally beneath block
      final player = game.player;
      if (!player.isInDeathCycle && !player.isWarping) {
        final dx = (player.position.x - (position.x + size.x / 2)).abs();
        if (dx <= 64.0 && player.position.y >= position.y && player.position.y <= groundY + 50) {
          triggerFall();
        }
      }
    }

    if (isTriggered && !isFalling && !hasLanded) {
      if (shouldHoldFall?.call() == true) {
        _shakeOffsetX = sin(_telegraphTimer * 60) * 3.0;
        return;
      }
      _telegraphTimer -= dt;
      _shakeOffsetX = sin(_telegraphTimer * 60) * 3.0;

      if (_telegraphTimer <= 0) {
        isFalling = true;
        _shakeOffsetX = 0.0;
      }
    }

    if (isFalling && !hasLanded) {
      _fallVelocity += 2200.0 * dt;
      position.y += _fallVelocity * dt;

      if (position.y + size.y >= groundY) {
        position.y = groundY - size.y;
        try {
          final player = game.player;
          final overlapsX = player.position.x >= position.x - 10.0 &&
              player.position.x <= position.x + size.x + 10.0;
          final overlapsY = player.position.y > position.y &&
              player.position.y - player.size.y < position.y + size.y;
          if (overlapsX && overlapsY) {
            player.takeDamage();
          }
        } catch (_) {}
        isFalling = false;
        hasLanded = true;
        game.audio.playSfx('trap_trigger.wav');
        game.shakeCamera(intensity: 6.0, duration: 0.2);
      }
    }

    if (isTriggered && !_baitAwarded) {
      _survivalTimer -= dt;
      if (_survivalTimer <= 0) {
        _baitAwarded = true;
        game.controller.onTrapBait(trapId);
      }
    }
  }

  void triggerFall() {
    isTriggered = true;
    game.audio.playSfx('trap_trigger.wav');
  }

  void resetToCeiling() {
    position.setFrom(initialPosition);
    isTriggered = false;
    isFalling = false;
    hasLanded = false;
    isRevealed = false;
    _telegraphTimer = 0.25;
    _shakeOffsetX = 0.0;
    _fallVelocity = 0.0;
    _survivalTimer = 0.50;
    hitbox.collisionType = CollisionType.passive;
  }

  @override
  void onCollision(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollision(intersectionPoints, other);

    if (other is Player) {
      if (isFalling) {
        other.takeDamage();
      } else if (hasLanded) {
        // Acts as solid obstacle when landed
        if (other.velocity.y >= 0 && other.position.y <= position.y + 14) {
          other.position.y = position.y;
          other.velocity.y = 0;
          other.isOnGround = true;
        } else if (other.position.y > position.y + 14) {
          if (other.velocity.x > 0 && other.position.x < position.x + size.x / 2) {
            other.position.x = position.x - 10;
            other.velocity.x = 0;
          } else if (other.velocity.x < 0 && other.position.x > position.x + size.x / 2) {
            other.position.x = position.x + size.x + 10;
            other.velocity.x = 0;
          }
        }
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (manualTriggerOnly && !isTriggered) return;
    super.render(canvas);

    final isHighContrast = GameState.instance.highContrastTells;

    final hasShake = _shakeOffsetX != 0.0;
    if (hasShake) {
      canvas.save();
      canvas.translate(_shakeOffsetX, 0);
    }

    if (_bombSprite != null && (isFalling || hasLanded)) {
      _bombSprite!.render(canvas, size: size);
    } else {
      // In ceiling: disguised as flat brown ceiling block with slight discolored tell
      final blockPaint = isHighContrast
          ? _warningBlockPaint
          : _defaultBlockPaint;
      canvas.drawRect(_rect, blockPaint);
      canvas.drawLine(_lineP1, _lineP2, _linePaint);
    }

    if (hasShake) {
      canvas.restore();
    }
  }
}
