import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

class FakeFloor extends PositionComponent
    with CollisionCallbacks, HasGameReference<TrapDashGame> {
  final String trapId;
  bool isRevealed = false;
  bool isStepped = false;
  bool isCrumbled = false;

  double _crumbleTimer = 0.30;
  double _survivalTimer = 0.50;
  bool _baitAwarded = false;
  late final RectangleHitbox hitbox;
  late final Rect _rect = size.toRect();
  late final Path _crackPath = Path()
    ..moveTo(size.x * 0.25, 0)
    ..lineTo(size.x * 0.5, size.y * 0.6)
    ..lineTo(size.x * 0.8, size.y);

  static final Paint _floorPaint = Paint()..color = AppPalette.brownSolid;
  static final Paint _revealedCrackPaint = Paint()
    ..color = AppPalette.warningRed
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  static final Paint _subtleCrackPaint = Paint()
    ..color = AppPalette.yellowBackground.withValues(alpha: 0.6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  static final Paint _borderPaint = Paint()
    ..color = AppPalette.warningRed
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  static final Paint _dustPaint = Paint()..color = AppPalette.brownDark;

  FakeFloor({
    required this.trapId,
    required Vector2 position,
    Vector2? size,
  }) : super(
          position: position,
          size: size ?? Vector2(32, 24),
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

    if (isStepped && !isCrumbled) {
      _crumbleTimer -= dt;
      if (_crumbleTimer <= 0) {
        crumble();
      }
    }

    if (isStepped && !_baitAwarded) {
      _survivalTimer -= dt;
      if (_survivalTimer <= 0) {
        _baitAwarded = true;
        game.controller.onTrapBait(trapId);
      }
    }
  }

  void onPlayerStep() {
    if (isStepped) return;
    isStepped = true;
    game.audio.playSfx('trap_trigger.wav');
  }

  void crumble() {
    isCrumbled = true;
    hitbox.collisionType = CollisionType.inactive;
  }

  void resetToSolid() {
    isStepped = false;
    isCrumbled = false;
    isRevealed = false;
    _crumbleTimer = 0.30;
    _survivalTimer = 0.50;
    hitbox.collisionType = CollisionType.passive;
  }

  @override
  void onCollision(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollision(intersectionPoints, other);

    if (other is Player && !isCrumbled) {
      onPlayerStep();
      if (other.velocity.y >= 0 && other.position.y <= position.y + 14) {
        other.position.y = position.y;
        other.velocity.y = 0;
        other.isOnGround = true;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (isCrumbled) return;
    super.render(canvas);

    final isHighContrast = GameState.instance.highContrastTells;

    // Disguised as solid brown floor
    canvas.drawRect(_rect, _floorPaint);

    // Crack tell (1.5px hairline crack in background yellow)
    final crackPaint = isHighContrast
        ? _revealedCrackPaint
        : _subtleCrackPaint;
    canvas.drawPath(_crackPath, crackPaint);

    if (isHighContrast) {
      canvas.drawRect(_rect, _borderPaint);
    }

    // Dust particles emitting downward during crumbling window
    if (isStepped && !isCrumbled) {
      final progress = 1.0 - (_crumbleTimer / 0.30);
      final dropY = size.y + (progress * 14.0);
      canvas.drawCircle(Offset(size.x * 0.2, dropY), 1.5, _dustPaint);
      canvas.drawCircle(Offset(size.x * 0.5, dropY + 2.0), 2.0, _dustPaint);
      canvas.drawCircle(Offset(size.x * 0.8, dropY - 1.0), 1.5, _dustPaint);
    }
  }
}
