import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/ui/widgets/square_back_button.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

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
                child: Container(
                  width: 540,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  decoration: BoxDecoration(
                    color: AppPalette.yellowBackground,
                    border: Border.all(color: AppPalette.brownSolid, width: 2.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'CREDITS',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 22,
                          color: AppPalette.playerBlack,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Trap Dash Arena',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 14,
                          color: AppPalette.brownSolid,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'ITSD 85 – Special Topics in Software Development',
                        style: TextStyle(
                          fontFamily: 'AtkinsonHyperlegible',
                          fontSize: 14,
                          color: AppPalette.textDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(color: AppPalette.brownSolid, height: 28, thickness: 1.5),

                      _buildCreditSection('Visual Art & Game Design', [
                        'Minimalist Monotone Aesthetics inspired by Level Devil (Unept)',
                        'Game sprites in assets/game/ (player, door, obstacles, saws, springs)',
                        'HUD icon sprites in assets/game/hud.png — Thomas / Mewily (mewily.itch.io)',
                      ]),
                      const SizedBox(height: 12),

                      _buildCreditSection('Typography (OFL)', [
                        'Press Start 2P — CodeMan38 (SIL OFL 1.1)',
                        'Atkinson Hyperlegible — Braille Institute (SIL OFL 1.1)',
                      ]),
                      const SizedBox(height: 12),

                      _buildCreditSection('Audio & Sound Effects (CC0)', [
                        'SFX synthesized with jsfxr (Public Domain / CC0)',
                        'BGM loops courtesy of OpenGameArt.org (CC0 / OGA-BY 3.0)',
                      ]),
                      const SizedBox(height: 12),

                      _buildCreditSection('Engine & Framework', [
                        'Flutter SDK & Flame Game Engine (BSD 3-Clause)',
                        'flame_tiled, flame_audio, shared_preferences',
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditSection(String header, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          header,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: AppPalette.playerBlack,
          ),
        ),
        const SizedBox(height: 6),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: AppPalette.brownDark, fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontFamily: 'AtkinsonHyperlegible',
                      fontSize: 13,
                      color: AppPalette.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
