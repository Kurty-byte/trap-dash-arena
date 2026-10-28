import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/audio_manager.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/ui/widgets/arcade_dialog.dart';
import 'package:trap_dash_arena/ui/widgets/square_back_button.dart';
import 'package:trap_dash_arena/ui/widgets/square_toggle.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;
  bool _highContrast = GameState.instance.highContrastTells;
  bool _aiBot = GameState.instance.aiBotEnabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: GameState.instance.playerNickname);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

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
              child: SingleChildScrollView(
                child: Material(
                  color: AppPalette.yellowBackground,
                  child: Container(
                    width: 520,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                    decoration: BoxDecoration(
                      color: AppPalette.yellowBackground,
                      border: Border.all(color: AppPalette.brownSolid, width: 3),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'SETTINGS',
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 22,
                            color: AppPalette.playerBlack,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(
                          color: AppPalette.brownSolid,
                          thickness: 2,
                          height: 20,
                        ),
                        const SizedBox(height: 12),

                        // Player Nickname Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppPalette.yellowBackground,
                            border: Border.all(color: AppPalette.brownSolid, width: 2),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                'PLAYER NAME: ',
                                style: TextStyle(
                                  fontFamily: 'PressStart2P',
                                  fontSize: 11,
                                  color: AppPalette.playerBlack,
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _nameController,
                                  maxLength: 12,
                                  style: const TextStyle(
                                    fontFamily: 'AtkinsonHyperlegible',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppPalette.brownSolid,
                                  ),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    counterText: '',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: 'Enter name',
                                  ),
                                  onChanged: (val) {
                                    GameState.instance.setPlayerNickname(val.trim());
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Audio Mute Toggle Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppPalette.yellowBackground,
                            border: Border.all(color: AppPalette.brownSolid, width: 2),
                          ),
                          child: ValueListenableBuilder<bool>(
                            valueListenable: AudioManager.instance.isMuted,
                            builder: (context, muted, _) {
                              return SquareToggleListTile(
                                title: const Text(
                                  'Sound & Music',
                                  style: TextStyle(
                                    fontFamily: 'AtkinsonHyperlegible',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppPalette.playerBlack,
                                  ),
                                ),
                                subtitle: Text(
                                  muted ? 'Audio Muted' : 'Audio Enabled',
                                  style: const TextStyle(
                                    fontFamily: 'AtkinsonHyperlegible',
                                    fontSize: 13,
                                    color: AppPalette.brownDark,
                                  ),
                                ),
                                value: !muted,
                                onChanged: (val) {
                                  AudioManager.instance.toggleMute();
                                },
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        // High-Contrast Trap Tells Toggle Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppPalette.yellowBackground,
                            border: Border.all(color: AppPalette.brownSolid, width: 2),
                          ),
                          child: SquareToggleListTile(
                            title: const Text(
                              'High-Contrast Trap Tells',
                              style: TextStyle(
                                fontFamily: 'AtkinsonHyperlegible',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppPalette.playerBlack,
                              ),
                            ),
                            subtitle: const Text(
                              'Prominent red warning outlines on hazards',
                              style: TextStyle(
                                fontFamily: 'AtkinsonHyperlegible',
                                fontSize: 13,
                                color: AppPalette.brownDark,
                              ),
                            ),
                            value: _highContrast,
                            onChanged: (val) {
                              setState(() => _highContrast = val);
                              GameState.instance.setHighContrastTells(val);
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        // AI Pace-Bot Rival Toggle Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppPalette.yellowBackground,
                            border: Border.all(color: AppPalette.brownSolid, width: 2),
                          ),
                          child: SquareToggleListTile(
                            title: const Text(
                              'Offline Pace-Bot Rival',
                              style: TextStyle(
                                fontFamily: 'AtkinsonHyperlegible',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppPalette.playerBlack,
                              ),
                            ),
                            subtitle: const Text(
                              'Simulates live opponent score in solo run',
                              style: TextStyle(
                                fontFamily: 'AtkinsonHyperlegible',
                                fontSize: 13,
                                color: AppPalette.brownDark,
                              ),
                            ),
                            value: _aiBot,
                            onChanged: (val) {
                              setState(() => _aiBot = val);
                              GameState.instance.setAiBotEnabled(val);
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Reset Progress Button Box
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppPalette.warningRed, width: 2),
                              foregroundColor: AppPalette.warningRed,
                              shape: const RoundedRectangleBorder(),
                            ),
                            onPressed: () async {
                              final confirm = await showArcadeConfirmDialog(
                                context: context,
                                title: 'RESET PROGRESS?',
                                message: 'This will clear all unlocked levels and stars.',
                                cancelLabel: 'CANCEL',
                                confirmLabel: 'RESET',
                              );
                              if (confirm == true) {
                                await GameState.instance.resetProgress();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Progress reset to Level 1.')),
                                  );
                                }
                              }
                            },
                            child: const Text(
                              'RESET ALL PROGRESS',
                              style: TextStyle(fontFamily: 'PressStart2P', fontSize: 10, color: AppPalette.warningRed),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
