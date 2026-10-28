import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

class TrapSpike extends PositionComponent
    with CollisionCallbacks, HasGameReference<TrapDashGame> {
  final String trapId;
  final bool isStatic;

  bool isRevealed = false;
  bool isTriggered = false;
  bool isExtended = false;

  double _jitterTimer = 0.30;
  double _survivalTimer = 0.50;
  bool _baitAwarded = false;
  double _jitterOffsetX = 0.0;
  Sprite? _obstacleSprite;

  late final RectangleHitbox hitbox;

  TrapSpike({
    required this.trapId,
    required Vector2 position,
    this.isStatic = false,
  }) : super(
          position: position,
          size: Vector2(36, 26),
          anchor: Anchor.bottomCenter,
        ) {
    if (isStatic) {
      isExtended = true;
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    hitbox = RectangleHitbox(
      size: Vector2(size.x - 4, size.y - 2),
      position: Vector2(2, 2),
    );
    add(hitbox);

    try {
      _obstacleSprite = await game.loadSprite('game/obstacle.png');
    } catch (_) {
      // Fallback for tests
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!isStatic && !isTriggered && !isExtended) {
      // Proximity check (48 px radius from player)
      final player = game.player;
      final distance = (player.position - position).length;
      if (distance <= 48.0) {
        triggerJitter();
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
    if (!isStatic) {
      isTriggered = false;
      isExtended = false;
      isRevealed = true; // Retains memory after death!
      _jitterTimer = 0.30;
      _survivalTimer = 0.50;
      _jitterOffsetX = 0.0;
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
    super.render(canvas);

    final isHighContrast = GameState.instance.highContrastTells;

    canvas.save();
    canvas.translate(_jitterOffsetX, 0);

    final isVisible = isExtended || isStatic;
    final yOffset = isVisible ? 0.0 : (isTriggered ? size.y - 10 : size.y - 4);

    if (_obstacleSprite != null) {
      // Render Level Devil obstacle sprite with vertical shift for pop-up effect
      canvas.clipRect(Rect.fromLTWH(0, 0, size.x, size.y));
      _obstacleSprite!.render(
        canvas,
        position: Vector2(0, yOffset),
        size: size,
      );
    } else {
      // Fallback
      final paint = Paint()
        ..color = isVisible ? AppPalette.brownSolid : AppPalette.brownDark;
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
      final warningPaint = Paint()
        ..color = AppPalette.warningRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(Rect.fromLTWH(0, size.y - 4, size.x, 4), warningPaint);
    }

    canvas.restore();
  }
}
