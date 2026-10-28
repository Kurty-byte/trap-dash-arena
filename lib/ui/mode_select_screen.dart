import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/audio_manager.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/ui/level_select_screen.dart';
import 'package:trap_dash_arena/ui/lobby_screen.dart';
import 'package:trap_dash_arena/ui/widgets/arcade_page_route.dart';
import 'package:trap_dash_arena/ui/widgets/square_back_button.dart';
import 'package:trap_dash_arena/ui/widgets/square_toggle.dart';

class ModeSelectScreen extends StatefulWidget {
  const ModeSelectScreen({super.key});

  @override
  State<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen> {
  bool _aiBot = GameState.instance.aiBotEnabled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.yellowBackground,
      body: SafeArea(
        child: Stack(
          children: [
            // Back button
            const Positioned(
              top: 16,
              left: 16,
              child: SquareBackButton(),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'SELECT MODE',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 24,
                        color: AppPalette.playerBlack,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 2 Game Mode Choices Arranged Horizontally
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Offline Solo Mode Card
                        Container(
                          width: 360,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppPalette.yellowBackground,
                            border: Border.all(color: AppPalette.brownSolid, width: 2.5),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'OFFLINE SOLO',
                                style: TextStyle(
                                  fontFamily: 'PressStart2P',
                                  fontSize: 15,
                                  color: AppPalette.playerBlack,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Solo Campaign & Speedrun',
                                style: TextStyle(
                                  fontFamily: 'AtkinsonHyperlegible',
                                  fontSize: 14,
                                  color: AppPalette.textDark,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // AI Pace-Bot toggle
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Pace-Bot Ghost Rival',
                                      style: TextStyle(
                                        fontFamily: 'AtkinsonHyperlegible',
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppPalette.textDark,
                                      ),
                                    ),
                                  ),
                                  SquareToggle(
                                    value: _aiBot,
                                    onChanged: (val) {
                                      setState(() => _aiBot = val);
                                      GameState.instance.setAiBotEnabled(val);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppPalette.brownSolid,
                                    foregroundColor: Colors.white,
                                    shape: const RoundedRectangleBorder(
                                      side: BorderSide(color: AppPalette.playerBlack, width: 2),
                                    ),
                                  ),
                                  onPressed: () {
                                    GameState.instance.setMode('offline');
                                    AudioManager.instance.playSfx('unlock.wav');
                                    Navigator.of(context).push(
                                      ArcadePageRoute(
                                        page: const LevelSelectScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'START CAMPAIGN',
                                    style: TextStyle(
                                      fontFamily: 'PressStart2P',
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 24),

                        // Online LAN Mode Card
                        Container(
                          width: 360,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppPalette.yellowBackground,
                            border: Border.all(color: AppPalette.brownSolid, width: 2.5),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'LOCAL WI-FI',
                                style: TextStyle(
                                  fontFamily: 'PressStart2P',
                                  fontSize: 15,
                                  color: AppPalette.playerBlack,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '2–5 Players Hotspot / Wi-Fi',
                                style: TextStyle(
                                  fontFamily: 'AtkinsonHyperlegible',
                                  fontSize: 14,
                                  color: AppPalette.textDark,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                height: 38,
                                alignment: Alignment.center,
                                child: const Text(
                                  'Host or join LAN match room',
                                  style: TextStyle(
                                    fontFamily: 'AtkinsonHyperlegible',
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppPalette.textDark,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppPalette.brownDark,
                                    foregroundColor: Colors.white,
                                    shape: const RoundedRectangleBorder(
                                      side: BorderSide(color: AppPalette.playerBlack, width: 2),
                                    ),
                                  ),
                                  onPressed: () {
                                    GameState.instance.setMode('online');
                                    AudioManager.instance.playSfx('unlock.wav');
                                    Navigator.of(context).push(
                                      ArcadePageRoute(
                                        page: const LobbyScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'MULTIPLAYER LOBBY',
                                    style: TextStyle(
                                      fontFamily: 'PressStart2P',
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
