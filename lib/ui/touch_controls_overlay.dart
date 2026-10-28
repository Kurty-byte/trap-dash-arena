import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

class TouchControlsOverlay extends StatelessWidget {
  final TrapDashGame game;

  const TouchControlsOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Left / Right direction controls
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TouchButton(
                    icon: Icons.arrow_back_rounded,
                    onDown: () => game.player.moveLeft(),
                    onUp: () => game.player.stopMoving(),
                  ),
                  const SizedBox(width: 16),
                  _TouchButton(
                    icon: Icons.arrow_forward_rounded,
                    onDown: () => game.player.moveRight(),
                    onUp: () => game.player.stopMoving(),
                  ),
                ],
              ),
              // Jump button
              _TouchButton(
                icon: Icons.arrow_upward_rounded,
                isJump: true,
                onDown: () => game.player.jump(),
                onUp: () => game.player.cutJump(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TouchButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final bool isJump;

  const _TouchButton({
    required this.icon,
    required this.onDown,
    required this.onUp,
    this.isJump = false,
  });

  @override
  State<_TouchButton> createState() => _TouchButtonState();
}

class _TouchButtonState extends State<_TouchButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.isJump ? 128.0 : 120.0;

    return Listener(
      onPointerDown: (_) {
        setState(() => _isPressed = true);
        widget.onDown();
      },
      onPointerUp: (_) {
        setState(() => _isPressed = false);
        widget.onUp();
      },
      onPointerCancel: (_) {
        setState(() => _isPressed = false);
        widget.onUp();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _isPressed
              ? AppPalette.yellowBackground.withValues(alpha: 0.28)
              : Colors.transparent,
          border: Border.all(
            color: AppPalette.yellowBackground,
            width: 2.5,
          ),
        ),
        child: Center(
          child: Icon(
            widget.icon,
            size: widget.isJump ? 52 : 46,
            color: _isPressed ? AppPalette.whiteAccent : AppPalette.yellowBackground,
          ),
        ),
      ),
    );
  }
}
