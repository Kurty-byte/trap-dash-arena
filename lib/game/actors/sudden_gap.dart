import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/actors/ground_block.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

class SuddenGap extends PositionComponent
    with CollisionCallbacks, HasGameReference<TrapDashGame> {
  final String trapId;
  final double triggerLeadPx;

  bool isTriggered = false;
  bool isRevealed = false;
  double _dropOffsetY = 0.0;
  double _survivalTimer = 0.50;
  bool _baitAwarded = false;

  late final RectangleHitbox hitbox;

  static final Paint _floorPaint = Paint()
    ..color = AppPalette.brownSolid
    ..isAntiAlias = false;

  static final Paint _warningPaint = Paint()
    ..color = AppPalette.warningRed
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  SuddenGap({
    required this.trapId,
    required Vector2 position,
    required Vector2 size,
    this.triggerLeadPx = 46.0,
  })  : hitbox = RectangleHitbox(
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
  Future<void> onLoad() async {
    await super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!isTriggered) {
      final player = game.player;
      if (!player.isInDeathCycle && !player.isWarping) {
        final inX = player.position.x >= position.x - triggerLeadPx &&
            player.position.x <= position.x + size.x + 16.0;
        final inY = (player.position.y - position.y).abs() <= 140.0;
        if (inX && inY) {
          triggerCollapse();
        }
      }
    } else {
      if (_dropOffsetY < 750.0) {
        _dropOffsetY += 1100.0 * dt;
      }

      if (!_baitAwarded) {
        _survivalTimer -= dt;
        if (_survivalTimer <= 0) {
          _baitAwarded = true;
          game.controller.onTrapBait(trapId);
        }
      }
    }
  }

  void triggerCollapse() {
    if (isTriggered) return;
    isTriggered = true;
    hitbox.collisionType = CollisionType.inactive;
    game.audio.playSfx('trap_trigger.wav');
    game.shakeCamera(intensity: 5.0, duration: 0.2);
  }

  void resetToSolid() {
    isTriggered = false;
    isRevealed = false;
    _dropOffsetY = 0.0;
    _survivalTimer = 0.50;
    _baitAwarded = false;
    hitbox.collisionType = CollisionType.passive;
  }

  @override
  void onCollision(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollision(intersectionPoints, other);

    if (other is Player && !isTriggered) {
      GroundBlock.resolvePlayerBlockCollision(
        other,
        position.x,
        position.y + _dropOffsetY,
        position.x + size.x,
        position.y + size.y + _dropOffsetY,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // If completely dropped off-screen, nothing to render
    if (_dropOffsetY >= 720.0) return;

    final isHighContrast = GameState.instance.highContrastTells;

    canvas.save();
    canvas.translate(0, _dropOffsetY);

    final rect = Rect.fromLTWH(-0.5, -0.5, size.x + 1.0, size.y + 1.0);
    canvas.drawRect(rect, _floorPaint);

    if (isHighContrast) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, 3),
        _warningPaint,
      );
    }

    canvas.restore();
  }
}
