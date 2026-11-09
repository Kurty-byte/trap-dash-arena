import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/actors/ground_block.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

enum MovingGapMode { chase, hesitation }

class MovingGapFloor extends PositionComponent
    with CollisionCallbacks, HasGameReference<TrapDashGame> {
  final String trapId;
  final MovingGapMode mode;
  final double gapWidth;
  final double triggerPlayerX;
  final double chaseStartPlayerX;
  final double chaseSpeed;
  final double stopGapX;
  final double activateRoomX;
  final double initialGapLocalX;
  final double anchorGapLocalX;
  final double proximityRangePx;
  final double punishSpeed;

  bool isGapOpen = false;
  bool isRevealed = false;
  double gapLocalX = 0.0;
  double _survivalTimer = 0.50;
  bool _baitAwarded = false;
  bool _isChasing = false;

  bool _isPunishing = false;
  bool get isPunishing => _isPunishing;
  bool _enteredProximityMovingRight = false;
  double _hesitationTimer = 0.0;

  late final RectangleHitbox hitbox;

  static final Paint _floorPaint = Paint()
    ..color = AppPalette.brownSolid
    ..isAntiAlias = false;

  static final Paint _warningEdgePaint = Paint()
    ..color = AppPalette.warningRed
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  MovingGapFloor({
    required this.trapId,
    required Vector2 position,
    required Vector2 size,
    required this.mode,
    this.gapWidth = 88.0,
    this.triggerPlayerX = 0.0,
    this.chaseStartPlayerX = 0.0,
    this.chaseSpeed = 205.0,
    this.stopGapX = 512.0,
    this.activateRoomX = 0.0,
    this.initialGapLocalX = 300.0,
    this.anchorGapLocalX = 420.0,
    this.proximityRangePx = 140.0,
    this.punishSpeed = 950.0,
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

    final player = game.player;

    if (mode == MovingGapMode.chase) {
      if (!isGapOpen) {
        if (!player.isInDeathCycle && player.position.x >= triggerPlayerX) {
          isGapOpen = true;
          gapLocalX = 0.0;
          game.audio.playSfx('trap_trigger.wav');
          if (chaseStartPlayerX <= 0.0) {
            _isChasing = true;
          }
        }
      } else {
        if (!_isChasing) {
          if (!player.isInDeathCycle && player.position.x >= chaseStartPlayerX) {
            _isChasing = true;
          }
        }

        if (_isChasing && gapLocalX < stopGapX) {
          gapLocalX = min(stopGapX, gapLocalX + chaseSpeed * dt);
        }

        if (!_baitAwarded) {
          _survivalTimer -= dt;
          if (_survivalTimer <= 0) {
            _baitAwarded = true;
            game.controller.onTrapBait(trapId);
          }
        }
      }
    } else {
      // Hesitation mode
      if (!isGapOpen) {
        if (!player.isInDeathCycle && player.position.x >= activateRoomX) {
          isGapOpen = true;
          gapLocalX = initialGapLocalX;
        }
      }

      if (isGapOpen && !player.isInDeathCycle) {
        final gapWorldLeft = position.x + gapLocalX;
        final gapWorldRight = gapWorldLeft + gapWidth;
        final inProximity = player.position.x >= (gapWorldLeft - proximityRangePx) &&
            player.position.x <= (gapWorldRight + 16.0);

        if (!_isPunishing) {
          // Pre-proximity doubt creep: gap creeps forward from initialGapLocalX to anchorGapLocalX
          final approachSpan = max(1.0, anchorGapLocalX - proximityRangePx);
          final progress = ((player.position.x - position.x) / approachSpan)
              .clamp(0.0, 1.0)
              .toDouble();
          final creepX = initialGapLocalX + progress * (anchorGapLocalX - initialGapLocalX);
          if (creepX > gapLocalX) {
            gapLocalX = creepX;
          }

          if (inProximity) {
            if (player.horizontalDirection > 0 && player.velocity.x >= 0) {
              _enteredProximityMovingRight = true;
              _hesitationTimer = 0.0;
            }

            // Second-guess trigger 1: player retreats left (grounded or air)
            if (player.horizontalDirection < 0 || player.velocity.x < 0) {
              _isPunishing = true;
              game.audio.playSfx('trap_trigger.wav');
            }

            // Second-guess trigger 2: stopped or stalled moving right
            if (_enteredProximityMovingRight &&
                player.position.x < gapWorldLeft &&
                player.horizontalDirection == 0) {
              _hesitationTimer += dt;
              if (_hesitationTimer >= 0.08) {
                _isPunishing = true;
                game.audio.playSfx('trap_trigger.wav');
              }
            }
          }

          // Bait award if player clears gap cleanly without punish
          if (!_baitAwarded && player.position.x > gapWorldRight + 16.0) {
            _baitAwarded = true;
            game.controller.onTrapBait(trapId);
          }
        } else {
          // Punish snap: move gap under player's feet
          final targetLocalX = (player.position.x - position.x - gapWidth * 0.5)
              .clamp(0.0, max(0.0, size.x - gapWidth))
              .toDouble();
          if ((gapLocalX - targetLocalX).abs() <= punishSpeed * dt) {
            gapLocalX = targetLocalX;
          } else if (gapLocalX < targetLocalX) {
            gapLocalX += punishSpeed * dt;
          } else {
            gapLocalX -= punishSpeed * dt;
          }
        }
      }
    }
  }

  void resetToInitial() {
    isGapOpen = false;
    isRevealed = false;
    gapLocalX = mode == MovingGapMode.hesitation ? initialGapLocalX : 0.0;
    _survivalTimer = 0.50;
    _baitAwarded = false;
    _isChasing = false;
    _isPunishing = false;
    _enteredProximityMovingRight = false;
    _hesitationTimer = 0.0;
  }

  @override
  void onCollision(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollision(intersectionPoints, other);

    if (other is Player) {
      if (!isGapOpen) {
        // Whole block is solid
        GroundBlock.resolvePlayerBlockCollision(
          other,
          position.x,
          position.y,
          position.x + size.x,
          position.y + size.y,
        );
        return;
      }

      // Left slab: from 0 to gapLocalX
      final leftSlabWidth = gapLocalX;
      if (leftSlabWidth > 1.0) {
        GroundBlock.resolvePlayerBlockCollision(
          other,
          position.x,
          position.y,
          position.x + leftSlabWidth,
          position.y + size.y,
        );
      }

      // Right slab: from gapLocalX + gapWidth to size.x
      final rightSlabStart = gapLocalX + gapWidth;
      if (rightSlabStart < size.x - 1.0) {
        GroundBlock.resolvePlayerBlockCollision(
          other,
          position.x + rightSlabStart,
          position.y,
          position.x + size.x,
          position.y + size.y,
        );
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final isHighContrast = GameState.instance.highContrastTells;

    if (!isGapOpen) {
      final rect = Rect.fromLTWH(-0.5, -0.5, size.x + 1.0, size.y + 1.0);
      canvas.drawRect(rect, _floorPaint);
      if (isHighContrast) {
        canvas.drawRect(Rect.fromLTWH(0, 0, size.x, 3), _warningEdgePaint);
      }
      return;
    }

    // Render left solid slab
    final leftW = gapLocalX;
    if (leftW > 0.0) {
      final leftRect = Rect.fromLTWH(-0.5, -0.5, leftW + 0.5, size.y + 1.0);
      canvas.drawRect(leftRect, _floorPaint);

      if (isHighContrast) {
        canvas.drawLine(
          Offset(leftW, 0),
          Offset(leftW, min(24.0, size.y)),
          _warningEdgePaint,
        );
      }
    }

    // Render right solid slab
    final rightStart = gapLocalX + gapWidth;
    final rightW = size.x - rightStart;
    if (rightW > 0.0) {
      final rightRect = Rect.fromLTWH(
        rightStart - 0.5,
        -0.5,
        rightW + 1.0,
        size.y + 1.0,
      );
      canvas.drawRect(rightRect, _floorPaint);

      if (isHighContrast) {
        canvas.drawLine(
          Offset(rightStart, 0),
          Offset(rightStart, min(24.0, size.y)),
          _warningEdgePaint,
        );
      }
    }
  }
}
