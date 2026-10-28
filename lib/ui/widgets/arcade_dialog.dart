import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/audio_manager.dart';
import 'package:trap_dash_arena/autoload/palette.dart';

/// Shows a standardized retro arcade confirmation modal dialog.
Future<bool?> showArcadeConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String cancelLabel = 'CANCEL',
  String confirmLabel = 'CONFIRM',
  Color confirmColor = AppPalette.warningRed,
}) async {
  AudioManager.instance.playSfx('unlock.wav');
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppPalette.yellowBackground,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppPalette.brownSolid, width: 2.5),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 14,
          color: AppPalette.playerBlack,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(
          fontFamily: 'AtkinsonHyperlegible',
          fontSize: 16,
          color: AppPalette.playerBlack,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            AudioManager.instance.playSfx('unlock.wav');
            Navigator.pop(ctx, false);
          },
          child: Text(
            cancelLabel,
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              color: AppPalette.brownSolid,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              side: BorderSide(color: AppPalette.playerBlack, width: 2),
            ),
          ),
          onPressed: () {
            AudioManager.instance.playSfx('unlock.wav');
            Navigator.pop(ctx, true);
          },
          child: Text(
            confirmLabel,
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}
