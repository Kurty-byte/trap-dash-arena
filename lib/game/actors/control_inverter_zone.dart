import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

class ControlInverterZone extends PositionComponent
    with CollisionCallbacks, HasGameReference<TrapDashGame> {
  final String trapId;
  final bool targetInverted;
  final bool requireGrounded;
  final bool triggerFullHeight;

  bool isTriggered = false;
  bool isRevealed = false;
  double _survivalTimer = 0.50;
  bool _baitAwarded = false;

  late final RectangleHitbox hitbox;

  static final Paint _warningPaint = Paint()
    ..color = AppPalette.warningRed
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  ControlInverterZone({
    required this.trapId,
    required Vector2 position,
    required Vector2 size,
    required this.targetInverted,
    this.requireGrounded = false,
    bool? triggerFullHeight,
  })  : triggerFullHeight = triggerFullHeight ?? !requireGrounded,
        hitbox = RectangleHitbox(
          size: size,
          collisionType: CollisionType.passive,
        ),
        super(
          position: position,
          size: size,
          anchor: Anchor.topLeft,
        ) {
    add(hitbox);
  }

  @override
  void update(double dt) {
    super.update(dt);

    final player = game.player;
    if (!player.isInDeathCycle && !player.isWarping && !isTriggered) {
      final inX = player.position.x >= position.x &&
          player.position.x <= position.x + size.x;
      final inY = triggerFullHeight
          ? (player.position.y <= position.y + size.y + 10.0 &&
              player.position.y >= 0.0)
          : (player.position.y >= position.y - 10.0 &&
              player.position.y <= position.y + size.y + 10.0);

      if (inX && inY) {
        if (!requireGrounded || player.isOnGround) {
          triggerInversion(player);
        }
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

  void triggerInversion(Player player) {
    if (isTriggered) return;
    isTriggered = true;
    player.setControlsInverted(targetInverted);
    game.audio.playSfx('trap_trigger.wav');
    game.shakeCamera(intensity: 3.5, duration: 0.15);
  }

  void resetToInitial() {
    isTriggered = false;
    isRevealed = false;
    _survivalTimer = 0.50;
    _baitAwarded = false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (GameState.instance.highContrastTells) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, min(3.0, size.y)),
        _warningPaint,
      );
    }
  }
}
