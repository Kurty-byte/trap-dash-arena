import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trap_dash_arena/autoload/audio_manager.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/ui/credits_screen.dart';
import 'package:trap_dash_arena/ui/game_screen.dart';
import 'package:trap_dash_arena/ui/mode_select_screen.dart';
import 'package:trap_dash_arena/ui/settings_screen.dart';
import 'package:trap_dash_arena/ui/widgets/arcade_dialog.dart';
import 'package:trap_dash_arena/ui/widgets/arcade_page_route.dart';
import 'package:trap_dash_arena/ui/widgets/hazard_background.dart';
import 'package:trap_dash_arena/ui/widgets/vertical_flip_ticker.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  @override
  void initState() {
    super.initState();
    AudioManager.instance.playBgm('bgm.mp3');
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = GameState.instance.unlockedLevel;

    return Scaffold(
      backgroundColor: AppPalette.yellowBackground,
      body: HazardBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left Column: Branding / Logo & Ticker
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/game/icon.png',
                              width: 64,
                              height: 64,
                              filterQuality: FilterQuality.none,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox(width: 64, height: 64),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'TRAP DASH',
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 28,
                                color: AppPalette.playerBlack,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'ARENA',
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 18,
                                color: AppPalette.brownSolid,
                                letterSpacing: 6,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const VerticalFlipTicker(
                              width: 300,
                              height: 34,
                            ),
                          ],
                        ),

                        const SizedBox(width: 48),

                        // Right Column: Navigation Action Buttons
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Primary 1-Tap Shortcut: Continue at highest unlocked stage
                          _buildMenuButton(
                            context: context,
                            label: 'CONTINUE LVL $unlocked',
                            color: AppPalette.playerBlack,
                            textColor: AppPalette.yellowBackground,
                            borderColor: AppPalette.brownSolid,
                            onTap: () {
                              AudioManager.instance.playSfx('unlock.wav');
                              GameState.instance.setMode('offline');
                              GameState.instance.currentLevel = unlocked;
                              Navigator.of(context).push(
                                ArcadePageRoute(
                                  page: GameScreen(levelNumber: unlocked),
                                ),
                              ).then((_) => setState(() {}));
                            },
                          ),
                          const SizedBox(height: 10),

                          // Browse all modes / levels
                          _buildMenuButton(
                            context: context,
                            label: 'PLAY GAME',
                            color: AppPalette.brownSolid,
                            onTap: () {
                              AudioManager.instance.playSfx('unlock.wav');
                              Navigator.of(context).push(
                                ArcadePageRoute(page: const ModeSelectScreen()),
                              ).then((_) => setState(() {}));
                            },
                          ),
                          const SizedBox(height: 10),

                          // Settings
                          _buildMenuButton(
                            context: context,
                            label: 'SETTINGS',
                            color: AppPalette.brownSolid,
                            onTap: () {
                              AudioManager.instance.playSfx('unlock.wav');
                              Navigator.of(context).push(
                                ArcadePageRoute(page: const SettingsScreen()),
                              ).then((_) => setState(() {}));
                            },
                          ),
                          const SizedBox(height: 10),

                          // Credits
                          _buildMenuButton(
                            context: context,
                            label: 'CREDITS',
                            color: AppPalette.brownDark,
                            onTap: () {
                              AudioManager.instance.playSfx('unlock.wav');
                              Navigator.of(context).push(
                                ArcadePageRoute(page: const CreditsScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 16,
              child: _buildExitButton(context),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildExitButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'Exit Game',
        child: InkWell(
          key: const Key('exit_game_button'),
          borderRadius: BorderRadius.circular(4),
          onTap: () => _confirmExit(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppPalette.playerBlack,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppPalette.brownSolid, width: 2),
            ),
            child: const Icon(
              Icons.logout,
              color: AppPalette.yellowBackground,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final shouldExit = await showArcadeConfirmDialog(
      context: context,
      title: 'EXIT GAME?',
      message: 'Are you sure you want to exit Trap Dash Arena?',
      cancelLabel: 'CANCEL',
      confirmLabel: 'EXIT',
    );

    if (shouldExit == true) {
      await SystemNavigator.pop();
    }
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required String label,
    required Color color,
    Color textColor = Colors.white,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 300,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 3,
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
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
