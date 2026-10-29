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

/// Retro pixel-styled floating toast banner widget.
class ArcadeToastBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color accentColor;

  const ArcadeToastBanner({
    super.key = const Key('arcade_toast_banner'),
    required this.message,
    this.icon = Icons.check_sharp,
    this.accentColor = AppPalette.brownSolid,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppPalette.playerBlack,
            border: Border.all(color: accentColor, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                color: accentColor,
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 16,
                  color: AppPalette.yellowBackground,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'AtkinsonHyperlegible',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppPalette.yellowBackground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Displays a compact retro arcade floating toast, replacing any active banner.
void showArcadeToast(
  BuildContext context, {
  required String message,
  IconData icon = Icons.check_sharp,
  Color accentColor = AppPalette.brownSolid,
  Duration duration = const Duration(milliseconds: 1500),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
        padding: EdgeInsets.zero,
        duration: duration,
        content: ArcadeToastBanner(
          message: message,
          icon: icon,
          accentColor: accentColor,
        ),
      ),
    );
}
