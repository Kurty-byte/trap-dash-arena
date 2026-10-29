import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

class ReverseSpring extends PositionComponent
    with CollisionCallbacks, HasGameReference<TrapDashGame> {
  final String trapId;
  bool isTriggered = false;
  bool _baitAwarded = false;
  double _survivalTimer = 0.50;
  Sprite? _compressedSprite;
  Sprite? _extendedSprite;
  late final RectangleHitbox hitbox;
  late final Rect _baseRect = Rect.fromLTWH(0, size.y - 4, size.x, 4);
  late final Rect _outlineRect = Rect.fromLTWH(0, size.y - 6, size.x, 6);
  late final Offset _coilP1 = Offset(size.x / 2, size.y - 4);
  late final Offset _coilP2 = Offset(size.x / 2, 2);

  static final Paint _basePaint = Paint()..color = AppPalette.brownDark;
  static final Paint _triggeredCoilPaint = Paint()
    ..color = AppPalette.warningRed
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke;
  static final Paint _normalCoilPaint = Paint()
    ..color = AppPalette.brownSolid
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke;
  static final Paint _outlinePaint = Paint()
    ..color = AppPalette.warningRed
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  ReverseSpring({
    required this.trapId,
    required Vector2 position,
    Vector2? size,
  }) : super(
          position: position,
          size: size ?? Vector2(36, 18),
          anchor: Anchor.bottomCenter,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    hitbox = RectangleHitbox(
      size: size,
      collisionType: CollisionType.passive,
    );
    add(hitbox);

    try {
      final cachedImg = game.tryGetCachedImage('game/spring.png');
      if (cachedImg != null) {
        _compressedSprite = Sprite(cachedImg, srcPosition: Vector2(0, 0), srcSize: Vector2(90, 80));
        _extendedSprite = Sprite(cachedImg, srcPosition: Vector2(90, 0), srcSize: Vector2(90, 80));
      } else {
        final img = await game.images.load('game/spring.png');
        _compressedSprite = Sprite(img, srcPosition: Vector2(0, 0), srcSize: Vector2(90, 80));
        _extendedSprite = Sprite(img, srcPosition: Vector2(90, 0), srcSize: Vector2(90, 80));
      }
    } catch (_) {
      // Fallback for tests
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isTriggered && !_baitAwarded) {
      _survivalTimer -= dt;
      if (_survivalTimer <= 0) {
        _baitAwarded = true;
        game.controller.onTrapBait(trapId);
      }
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (other is Player) {
      isTriggered = true;
      game.audio.playSfx('trap_trigger.wav');
      game.shakeCamera(intensity: 8.0, duration: 0.25);

      // Deceptive reverse propulsion: slings player backwards and takes damage
      other.velocity.x = -480.0;
      other.velocity.y = 350.0;
      other.takeDamage();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (_compressedSprite != null && _extendedSprite != null) {
      final sprite = isTriggered ? _extendedSprite! : _compressedSprite!;
      sprite.render(canvas, size: size);
    } else {
      // Fallback
      canvas.drawRect(_baseRect, _basePaint);

      final coilPaint = isTriggered ? _triggeredCoilPaint : _normalCoilPaint;
      canvas.drawLine(_coilP1, _coilP2, coilPaint);
    }

    if (GameState.instance.highContrastTells) {
      canvas.drawRect(_outlineRect, _outlinePaint);
    }
  }
}
