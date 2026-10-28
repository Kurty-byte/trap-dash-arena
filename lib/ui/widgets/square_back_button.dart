import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/audio_manager.dart';
import 'package:trap_dash_arena/autoload/palette.dart';

/// Retro sharp square back button matching Level Devil monotone aesthetic.
class SquareBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const SquareBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AudioManager.instance.playSfx('unlock.wav');
        if (onPressed != null) {
          onPressed!();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppPalette.yellowBackground,
          border: Border.all(color: AppPalette.brownSolid, width: 2.5),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.arrow_back,
          color: AppPalette.playerBlack,
          size: 24,
        ),
      ),
    );
  }
}
