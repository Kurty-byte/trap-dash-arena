import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

enum PickupType { coin, key }

class PickupItem extends PositionComponent
    with CollisionCallbacks, HasGameReference<TrapDashGame> {
  final PickupType type;
  double _hoverTimer = 0.0;
  late final double _baseY;
  Sprite? _coinSprite;

  PickupItem({
    required this.type,
    required Vector2 position,
  }) : super(
          position: position,
          size: Vector2(18, 18),
          anchor: Anchor.center,
        ) {
    _baseY = position.y;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox(radius: 9));

    try {
      _coinSprite = await game.loadSprite('game/coin.png');
    } catch (_) {
      // Fallback for tests
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _hoverTimer += dt * 3.5;
    position.y = _baseY + sin(_hoverTimer) * 3.0;
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (other is Player) {
      if (type == PickupType.coin) {
        game.controller.collectCoin();
      } else {
        game.controller.collectKey();
      }
      game.audio.playSfx('unlock.wav');
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (_coinSprite != null) {
      _coinSprite!.render(canvas, size: size);
      if (type == PickupType.key) {
        // Subtle key dot indicator
        final keyPaint = Paint()..color = AppPalette.whiteAccent;
        canvas.drawCircle(Offset(size.x / 2, size.y / 2), 2.5, keyPaint);
      }
    } else {
      // Monotone Level Devil fallback diamond
      final paint = Paint()
        ..color = type == PickupType.coin ? AppPalette.brownSolid : AppPalette.brownDark;
      final path = Path()
        ..moveTo(size.x / 2, 0)
        ..lineTo(size.x, size.y / 2)
        ..lineTo(size.x / 2, size.y)
        ..lineTo(0, size.y / 2)
        ..close();
      canvas.drawPath(path, paint);
    }
  }
}
