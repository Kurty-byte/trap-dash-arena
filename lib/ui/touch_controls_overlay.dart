import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

enum TouchActionShape {
  left,
  right,
  jump,
}

class TouchControlsOverlay extends StatefulWidget {
  final TrapDashGame game;

  const TouchControlsOverlay({super.key, required this.game});

  @override
  State<TouchControlsOverlay> createState() => _TouchControlsOverlayState();
}

class _TouchControlsOverlayState extends State<TouchControlsOverlay> {
  bool _leftHeld = false;
  bool _rightHeld = false;
  bool _jumpHeld = false;

  bool get _canControl {
    final game = widget.game;
    if (game.paused) return false;
    if (game.overlays.isActive('PauseOverlay')) return false;
    if (game.overlays.isActive('RespawnOverlay')) return false;
    if (game.overlays.isActive('ResultOverlay')) return false;
    if (game.overlays.isActive('LoadingOverlay')) return false;
    if (game.controller.isGameOver.value) return false;
    try {
      if (game.player.isInDeathCycle) return false;
    } catch (_) {
      // player not initialized yet
    }
    return true;
  }

  void _updateHorizontalMovement() {
    if (!_canControl) {
      widget.game.player.stopMoving();
      return;
    }
    if (_leftHeld && !_rightHeld) {
      widget.game.player.moveLeft();
    } else if (_rightHeld && !_leftHeld) {
      widget.game.player.moveRight();
    } else {
      widget.game.player.stopMoving();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Direction controls (Left / Right chevrons)
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _WireframeActionPad(
                    key: const Key('touch_left_button'),
                    shape: TouchActionShape.left,
                    hitWidth: 148.0,
                    hitHeight: 124.0,
                    visualWidth: 148.0,
                    visualHeight: 62.0,
                    isPressed: _leftHeld,
                    onDown: () {
                      setState(() => _leftHeld = true);
                      _updateHorizontalMovement();
                    },
                    onUp: () {
                      setState(() => _leftHeld = false);
                      _updateHorizontalMovement();
                    },
                  ),
                  const SizedBox(width: 24),
                  _WireframeActionPad(
                    key: const Key('touch_right_button'),
                    shape: TouchActionShape.right,
                    hitWidth: 148.0,
                    hitHeight: 124.0,
                    visualWidth: 148.0,
                    visualHeight: 62.0,
                    isPressed: _rightHeld,
                    onDown: () {
                      setState(() => _rightHeld = true);
                      _updateHorizontalMovement();
                    },
                    onUp: () {
                      setState(() => _rightHeld = false);
                      _updateHorizontalMovement();
                    },
                  ),
                ],
              ),

              // Jump control (Upward roof pentagon)
              _WireframeActionPad(
                key: const Key('touch_jump_button'),
                shape: TouchActionShape.jump,
                hitWidth: 156.0,
                hitHeight: 128.0,
                visualWidth: 156.0,
                visualHeight: 68.0,
                isPressed: _jumpHeld,
                onDown: () {
                  if (!_canControl) return;
                  setState(() => _jumpHeld = true);
                  widget.game.player.jump();
                },
                onUp: () {
                  setState(() => _jumpHeld = false);
                  widget.game.player.cutJump();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WireframeActionPad extends StatelessWidget {
  final TouchActionShape shape;
  final double hitWidth;
  final double hitHeight;
  final double visualWidth;
  final double visualHeight;
  final bool isPressed;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _WireframeActionPad({
    super.key,
    required this.shape,
    required this.hitWidth,
    required this.hitHeight,
    required this.visualWidth,
    required this.visualHeight,
    required this.isPressed,
    required this.onDown,
    required this.onUp,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => onDown(),
        onPointerUp: (_) => onUp(),
        onPointerCancel: (_) => onUp(),
        child: SizedBox(
          width: hitWidth,
          height: hitHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: CustomPaint(
              size: Size(visualWidth, visualHeight),
              painter: _ActionPolygonPainter(
                shape: shape,
                isPressed: isPressed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionPolygonPainter extends CustomPainter {
  final TouchActionShape shape;
  final bool isPressed;

  static final Map<String, Path> _pathCache = {};
  static final Paint _pressedFillPaint = Paint()
    ..color = const Color(0x44FFD56B)
    ..style = PaintingStyle.fill;
  static final Paint _idleFillPaint = Paint()
    ..color = AppPalette.brownSolid.withValues(alpha: 0.55)
    ..style = PaintingStyle.fill;
  static final Paint _pressedStrokePaint = Paint()
    ..color = const Color(0xFFFFF3C4)
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  static final Paint _idleStrokePaint = Paint()
    ..color = const Color(0xFFFFC46B)
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;

  _ActionPolygonPainter({
    required this.shape,
    required this.isPressed,
  });

  Path _buildPath(Size size) {
    final key = '${shape.name}_${size.width}_${size.height}';
    final cached = _pathCache[key];
    if (cached != null) return cached;

    final Path path = Path();
    final double w = size.width;
    final double h = size.height;

    switch (shape) {
      case TouchActionShape.left:
        final double tipInset = h * 0.42;
        path.moveTo(tipInset, 0);
        path.lineTo(w, 0);
        path.lineTo(w, h);
        path.lineTo(tipInset, h);
        path.lineTo(0, h * 0.5);
        path.close();
        break;

      case TouchActionShape.right:
        final double tipInset = h * 0.42;
        path.moveTo(0, 0);
        path.lineTo(w - tipInset, 0);
        path.lineTo(w, h * 0.5);
        path.lineTo(w - tipInset, h);
        path.lineTo(0, h);
        path.close();
        break;

      case TouchActionShape.jump:
        path.moveTo(w * 0.5, 0);
        path.lineTo(w, h * 0.55);
        path.lineTo(w, h);
        path.lineTo(0, h);
        path.lineTo(0, h * 0.55);
        path.close();
        break;
    }

    _pathCache[key] = path;
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = _buildPath(size);
    canvas.drawPath(path, isPressed ? _pressedFillPaint : _idleFillPaint);
    canvas.drawPath(path, isPressed ? _pressedStrokePaint : _idleStrokePaint);
  }

  @override
  bool shouldRepaint(covariant _ActionPolygonPainter oldDelegate) {
    return oldDelegate.shape != shape || oldDelegate.isPressed != isPressed;
  }
}
