import 'package:flutter/material.dart';

/// Named sprite types mapped to 34x34 grid coordinates in assets/game/hud.png.
/// Each icon occupies 3 contiguous column states:
/// baseCol + 0 = Raised Yellow Idle
/// baseCol + 1 = Raised Orange Hover
/// baseCol + 2 = Depressed Orange Pressed
enum HudSpriteType {
  pause(col: 0, row: 4),
  restartCw(col: 3, row: 2),
  restartCcw(col: 0, row: 2),
  audioOn(col: 9, row: 0),
  audioOff(col: 9, row: 1),
  back(col: 0, row: 0),
  settings(col: 3, row: 0),
  bot(col: 6, row: 4);

  final int col;
  final int row;

  const HudSpriteType({required this.col, required this.row});
}

/// Renders a single 34x34 pixel sprite cell from assets/game/hud.png.
class HudSpriteIcon extends StatelessWidget {
  final HudSpriteType sprite;
  final int stateOffset;
  final double size;

  const HudSpriteIcon({
    super.key,
    required this.sprite,
    this.stateOffset = 0,
    this.size = 34.0,
  });

  @override
  Widget build(BuildContext context) {
    const double sheetWidth = 408.0;
    const double sheetHeight = 340.0;
    const double cellSize = 34.0;

    final int targetCol = sprite.col + stateOffset;
    final int targetRow = sprite.row;
    final double scale = size / cellSize;

    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: -targetCol * cellSize * scale,
              top: -targetRow * cellSize * scale,
              width: sheetWidth * scale,
              height: sheetHeight * scale,
              child: Image.asset(
                'assets/game/hud.png',
                filterQuality: FilterQuality.none,
                fit: BoxFit.fill,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: size,
                  height: size,
                  color: Colors.transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive button using 34x34 sprites from assets/game/hud.png.
/// Automatically swaps from raised idle (col) to depressed pressed (col + 2).
class HudSpriteButton extends StatefulWidget {
  final HudSpriteType sprite;
  final double size;
  final VoidCallback onTap;
  final String? tooltip;

  const HudSpriteButton({
    super.key,
    required this.sprite,
    this.size = 34.0,
    required this.onTap,
    this.tooltip,
  });

  @override
  State<HudSpriteButton> createState() => _HudSpriteButtonState();
}

class _HudSpriteButtonState extends State<HudSpriteButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final hitSize = widget.size < 40.0 ? 40.0 : widget.size;

    final buttonWidget = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => setState(() => _isPressed = true),
      onPointerUp: (_) {
        if (_isPressed) {
          setState(() => _isPressed = false);
          widget.onTap();
        }
      },
      onPointerCancel: (_) {
        if (_isPressed) {
          setState(() => _isPressed = false);
        }
      },
      child: SizedBox(
        width: hitSize,
        height: hitSize,
        child: Center(
          child: HudSpriteIcon(
            sprite: widget.sprite,
            stateOffset: _isPressed ? 2 : 0,
            size: widget.size,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        child: buttonWidget,
      );
    }

    return buttonWidget;
  }
}
