import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

class RespawnOverlay extends StatelessWidget {
  final TrapDashGame game;

  const RespawnOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final controller = game.controller;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
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
                  'YOU DIED',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 18,
                    color: AppPalette.warningRed,
                  ),
                ),
                const SizedBox(height: 12),

                // Hearts left indicator
                ValueListenableBuilder<int>(
                  valueListenable: controller.hearts,
                  builder: (context, heartsVal, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          color: AppPalette.warningRed,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$heartsVal LEFT',
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 11,
                            color: AppPalette.playerBlack,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),

                // Explicit Respawn Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.brownSolid,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shape: const RoundedRectangleBorder(
                        side: BorderSide(color: AppPalette.playerBlack, width: 2),
                      ),
                    ),
                    onPressed: () => game.triggerRespawn(),
                    child: const Text(
                      'RESPAWN',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                const Text(
                  'PRESS SPACE OR TAP TO RESPAWN',
                  style: TextStyle(
                    fontFamily: 'AtkinsonHyperlegible',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppPalette.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
