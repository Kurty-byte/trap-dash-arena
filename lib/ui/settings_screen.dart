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
  late final FocusNode _nameFocusNode;
  bool _highContrast = GameState.instance.highContrastTells;
  bool _aiBot = GameState.instance.aiBotEnabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: GameState.instance.playerNickname);
    _nameFocusNode = FocusNode();
  }

  @override
  void dispose() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      GameState.instance.setPlayerNickname(name);
    }
    _nameFocusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 68, vertical: 12),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Material(
                    color: AppPalette.yellowBackground,
                    child: Container(
                      width: 720,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
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
                          const SizedBox(height: 10),
                          const Divider(
                            color: AppPalette.brownSolid,
                            thickness: 2,
                            height: 16,
                          ),
                          const SizedBox(height: 10),

                          // Row 1: Player Name Card & Sound Card
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Player Name Box
                                Expanded(
                                  child: _buildPlayerNameTile(),
                                ),
                                const SizedBox(width: 12),
                                // Audio Mute Toggle Box
                                Expanded(
                                  child: _buildAudioTile(),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Row 2: High Contrast & AI Bot
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // High-Contrast Trap Tells Toggle Box
                                Expanded(
                                  child: _buildHighContrastTile(),
                                ),
                                const SizedBox(width: 12),
                                // AI Pace-Bot Rival Toggle Box
                                Expanded(
                                  child: _buildAiBotTile(),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Reset Progress Button Box
                          _buildResetProgressButton(context),
                        ],
                      ),
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

  Widget _buildPlayerNameTile() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _nameFocusNode.requestFocus(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppPalette.yellowBackground,
          border: Border.all(color: AppPalette.brownSolid, width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Player Name',
                    style: TextStyle(
                      fontFamily: 'AtkinsonHyperlegible',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppPalette.playerBlack,
                    ),
                  ),
                  const SizedBox(height: 2),
                  TextField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    maxLength: 12,
                    style: const TextStyle(
                      fontFamily: 'AtkinsonHyperlegible',
                      fontSize: 14,
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
                      GameState.instance.playerNickname = val.trim();
                    },
                    onSubmitted: (val) {
                      GameState.instance.setPlayerNickname(val.trim());
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 52,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppPalette.yellowBackground,
                border: Border.all(color: AppPalette.brownSolid, width: 2),
              ),
              child: const Icon(
                Icons.edit,
                size: 16,
                color: AppPalette.brownSolid,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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
    );
  }

  Widget _buildHighContrastTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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
          'Prominent red outlines on hazards',
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
    );
  }

  Widget _buildAiBotTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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
          'Simulates live opponent in solo run',
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
    );
  }

  Widget _buildResetProgressButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 42,
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
              setState(() {
                _highContrast = GameState.instance.highContrastTells;
                _aiBot = GameState.instance.aiBotEnabled;
                _nameController.text = GameState.instance.playerNickname;
              });
              showArcadeToast(
                context,
                message: 'Progress reset to Level 1.',
                icon: Icons.restart_alt_sharp,
              );
            }
          }
        },
        child: const Text(
          'RESET ALL PROGRESS',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: AppPalette.warningRed,
          ),
        ),
      ),
    );
  }
}
