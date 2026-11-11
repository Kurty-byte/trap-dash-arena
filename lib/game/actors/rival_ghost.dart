import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/net_manager.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

/// Translucent rival runner ghost that updates every 0.5 seconds in online 1v1 matches.
class RivalGhost extends PositionComponent with HasGameReference<TrapDashGame> {
  final Vector2 _targetPos = Vector2.zero();
  final Vector2 _prevPos = Vector2.zero();
  double _lerpTimer = 0.0;
  static const double syncInterval = 0.50;

  String _rivalName = 'Rival';
  bool _facingLeft = false;

  List<Sprite>? _sprites;
  int _currentFrame = 0;
  double _animTimer = 0.0;

  TextPainter? _nameTagPainter;

  RivalGhost({required Vector2 position})
      : super(
          position: position,
          size: Vector2(24, 38),
          anchor: Anchor.bottomCenter,
          priority: 2,
        ) {
    _targetPos.setFrom(position);
    _prevPos.setFrom(position);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      final img = game.tryGetCachedImage('game/player.png');
      if (img != null) {
        _sprites = [
          Sprite(img, srcPosition: Vector2(0, 0), srcSize: Vector2(48, 76)),
          Sprite(img, srcPosition: Vector2(48, 0), srcSize: Vector2(48, 76)),
          Sprite(img, srcPosition: Vector2(96, 0), srcSize: Vector2(48, 76)),
          Sprite(img, srcPosition: Vector2(144, 0), srcSize: Vector2(48, 76)),
        ];
      }
    } catch (_) {}

    _updateRivalInfo();
  }

  void _updateRivalInfo() {
    final net = NetManager.instance;
    final myId = net.localPlayerId;
    for (final entry in net.players.value.entries) {
      if (entry.key != myId) {
        _rivalName = entry.value;
        break;
      }
    }

    _nameTagPainter = TextPainter(
      text: TextSpan(
        text: _rivalName,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 7,
          color: AppPalette.yellowBackground,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  /// Called when a fresh position update arrives from the network.
  void setTargetPosition(double x, double y) {
    final newTarget = Vector2(x, y);
    final dist = (newTarget - position).length;

    if (dist > 250.0 || _targetPos == Vector2.zero()) {
      // Big jump (respawn / warp) -> snap immediately
      position.setFrom(newTarget);
      _targetPos.setFrom(newTarget);
      _prevPos.setFrom(newTarget);
      _lerpTimer = syncInterval;
    } else {
      _prevPos.setFrom(position);
      _targetPos.setFrom(newTarget);
      _lerpTimer = 0.0;
    }

    if (newTarget.x < position.x - 2.0) {
      _facingLeft = true;
    } else if (newTarget.x > position.x + 2.0) {
      _facingLeft = false;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Refresh rival name if not set yet
    if (_nameTagPainter == null || _rivalName == 'Rival') {
      _updateRivalInfo();
    }

    // Check NetManager for rival position updates
    final net = NetManager.instance;
    final myId = net.localPlayerId;
    for (final entry in net.playerPositions.value.entries) {
      if (entry.key != myId) {
        final netX = entry.value.dx;
        final netY = entry.value.dy;
        if ((netX - _targetPos.x).abs() > 0.5 || (netY - _targetPos.y).abs() > 0.5) {
          setTargetPosition(netX, netY);
        }
        break;
      }
    }

    // Smoothly glide toward latest target over the 0.5s interval
    if (_lerpTimer < syncInterval) {
      _lerpTimer += dt;
      final t = (_lerpTimer / syncInterval).clamp(0.0, 1.0);
      position.x = _prevPos.x + (_targetPos.x - _prevPos.x) * t;
      position.y = _prevPos.y + (_targetPos.y - _prevPos.y) * t;
    }

    // Walk animation if moving
    final isMoving = (position - _prevPos).length > 1.0;
    if (isMoving && _sprites != null && _sprites!.length >= 4) {
      _animTimer += dt;
      if (_animTimer >= 0.10) {
        _animTimer = 0.0;
        _currentFrame = (_currentFrame + 1) % 4;
      }
    } else {
      _currentFrame = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 1. Draw floating name tag above head
    if (_nameTagPainter != null) {
      final tagW = _nameTagPainter!.width + 8;
      const tagH = 12.0;
      final tagX = (size.x - tagW) / 2;
      const tagY = -18.0;

      final bgPaint = Paint()..color = AppPalette.playerBlack.withValues(alpha: 0.75);
      final borderPaint = Paint()
        ..color = AppPalette.brownSolid
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tagX, tagY, tagW, tagH),
        const Radius.circular(2),
      );
      canvas.drawRRect(rrect, bgPaint);
      canvas.drawRRect(rrect, borderPaint);

      _nameTagPainter!.paint(canvas, Offset(tagX + 4, tagY + 2.5));
    }

    // 2. Render translucent silhouette (45% opacity)
    canvas.save();

    // Sprite natively faces left, flip horizontally if facing right
    if (!_facingLeft) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }

    final ghostPaint = Paint()
      ..color = const Color.fromARGB(115, 0, 0, 0); // ~45% opacity

    if (_sprites != null && _sprites!.length > _currentFrame) {
      _sprites![_currentFrame].render(
        canvas,
        size: size,
        overridePaint: ghostPaint,
      );
    } else {
      // Fallback for tests
      canvas.drawRRect(
        RRect.fromRectAndRadius(size.toRect(), const Radius.circular(3)),
        ghostPaint,
      );
    }

    canvas.restore();
  }
}
