import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/audio_manager.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';
import 'package:trap_dash_arena/ui/main_menu_screen.dart';
import 'package:trap_dash_arena/ui/widgets/arcade_page_route.dart';

class PauseOverlay extends StatelessWidget {
  final TrapDashGame game;

  const PauseOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          ModalBarrier(
            dismissible: false,
            color: Colors.black.withValues(alpha: 0.7),
          ),
          Center(
            child: Container(
              width: 340,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: BoxDecoration(
                color: AppPalette.yellowBackground,
                border: Border.all(color: AppPalette.brownSolid, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'PAUSED',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 22,
                      color: AppPalette.playerBlack,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Resume button
                  _buildButton(
                    label: 'RESUME',
                    color: AppPalette.brownSolid,
                    textColor: Colors.white,
                    onTap: () {
                      AudioManager.instance.playSfx('unlock.wav');
                      game.resumeGame();
                    },
                  ),
                  const SizedBox(height: 12),

                  // Restart button
                  _buildButton(
                    label: 'RESTART',
                    color: AppPalette.brownDark,
                    textColor: Colors.white,
                    onTap: () {
                      AudioManager.instance.playSfx('unlock.wav');
                      game.restartLevel();
                    },
                  ),
                  const SizedBox(height: 12),

                  // Audio toggle
                  ValueListenableBuilder<bool>(
                    valueListenable: AudioManager.instance.isMuted,
                    builder: (context, muted, _) {
                      return _buildButton(
                        label: muted ? 'AUDIO: OFF' : 'AUDIO: ON',
                        color: AppPalette.yellowBackground,
                        textColor: AppPalette.playerBlack,
                        borderColor: AppPalette.brownSolid,
                        onTap: () {
                          AudioManager.instance.toggleMute();
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Quit to menu
                  _buildButton(
                    label: 'QUIT TO MENU',
                    color: AppPalette.playerBlack,
                    textColor: Colors.white,
                    onTap: () {
                      AudioManager.instance.playSfx('unlock.wav');
                      game.resumeEngine();
                      Navigator.of(context).pushAndRemoveUntil(
                        ArcadePageRoute(page: const MainMenuScreen()),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required Color color,
    required Color textColor,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 2,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: borderColor ?? AppPalette.playerBlack,
              width: 2,
            ),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
