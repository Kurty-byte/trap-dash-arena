import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/audio_manager.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/net_manager.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';
import 'package:trap_dash_arena/ui/main_menu_screen.dart';
import 'package:trap_dash_arena/ui/widgets/arcade_page_route.dart';

class ResultOverlay extends StatelessWidget {
  final TrapDashGame game;

  const ResultOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final controller = game.controller;
    final won = controller.isLevelCleared.value;
    final stars = controller.calculateStars();
    final score = controller.score.value;
    final currentLevel = game.currentLevelNumber;
    final isOnline = GameState.instance.mode == 'online';

    return Positioned.fill(
      child: Stack(
        children: [
          ModalBarrier(
            dismissible: false,
            color: Colors.black.withValues(alpha: 0.75),
          ),
          Center(
            child: Container(
              width: 420,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppPalette.yellowBackground,
              border: Border.all(
                color: won ? AppPalette.brownSolid : AppPalette.warningRed,
                width: 3,
              ),
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
                if (!isOnline) ...[
                  // Offline banner text
                  Text(
                    won ? 'VICTORY!' : 'GAME OVER',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 22,
                      color: won ? AppPalette.playerBlack : AppPalette.warningRed,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Star rating if won
                  if (won) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (i) => Icon(
                          Icons.star_rounded,
                          size: 38,
                          color: i < stars ? AppPalette.brownSolid : AppPalette.brownDark.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Score stats
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppPalette.yellowBackground,
                      border: Border.all(color: AppPalette.brownSolid, width: 2),
                    ),
                    child: Column(
                      children: [
                        _buildStatRow('SCORE', '$score PTS'),
                        const SizedBox(height: 6),
                        _buildStatRow('HEARTS', '${controller.hearts.value} / ${controller.config.initialHearts}'),
                        const SizedBox(height: 6),
                        _buildStatRow('TIME LEFT', '${controller.timeLeft.value.ceil()}s'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Offline Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Retry
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppPalette.brownSolid,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const RoundedRectangleBorder(
                              side: BorderSide(color: AppPalette.playerBlack, width: 2),
                            ),
                          ),
                          onPressed: () {
                            AudioManager.instance.playSfx('unlock.wav');
                            game.restartLevel();
                          },
                          child: const Text(
                            'RETRY',
                            style: TextStyle(fontFamily: 'PressStart2P', fontSize: 11),
                          ),
                        ),
                      ),
                      if (won && currentLevel < GameState.totalLevels) ...[
                        const SizedBox(width: 10),
                        // Next Stage
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppPalette.playerBlack,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: const RoundedRectangleBorder(
                                side: BorderSide(color: AppPalette.brownSolid, width: 2),
                              ),
                            ),
                            onPressed: () {
                              AudioManager.instance.playSfx('unlock.wav');
                              game.overlays.remove('ResultOverlay');
                              game.resumeEngine();
                              game.loadLevel(currentLevel + 1);
                            },
                            child: const Text(
                              'NEXT',
                              style: TextStyle(fontFamily: 'PressStart2P', fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 10),
                      // Menu
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppPalette.brownDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const RoundedRectangleBorder(
                              side: BorderSide(color: AppPalette.playerBlack, width: 2),
                            ),
                          ),
                          onPressed: () {
                            AudioManager.instance.playSfx('unlock.wav');
                            game.resumeEngine();
                            Navigator.of(context).pushAndRemoveUntil(
                              ArcadePageRoute(page: const MainMenuScreen()),
                              (route) => false,
                            );
                          },
                          child: const Text(
                            'MENU',
                            style: TextStyle(fontFamily: 'PressStart2P', fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Online multiplayer result
                  ValueListenableBuilder<List<Map<String, dynamic>>?>(
                    valueListenable: NetManager.instance.finalScoreboard,
                    builder: (context, board, _) {
                      final hasWinner = board != null;
                      final isWinner = hasWinner &&
                          NetManager.instance.matchWinnerId.value ==
                              NetManager.instance.localPlayerId;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            !hasWinner
                                ? 'WAITING FOR PEERS...'
                                : isWinner
                                    ? 'MATCH VICTORY!'
                                    : 'MATCH FINISHED',
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 16,
                              color: isWinner
                                  ? AppPalette.playerBlack
                                  : AppPalette.brownSolid,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),

                          // Standings table
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppPalette.yellowBackground,
                              border: Border.all(
                                color: AppPalette.brownSolid,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'FINAL STANDINGS:',
                                  style: TextStyle(
                                    fontFamily: 'PressStart2P',
                                    fontSize: 11,
                                    color: AppPalette.playerBlack,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (board != null)
                                  ...List.generate(board.length, (idx) {
                                    final row = board[idx];
                                    final rank = idx + 1;
                                    final isMe = row['id'] ==
                                        NetManager.instance.localPlayerId;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 3),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '#$rank ${row['name']} ${isMe ? "(You)" : ""}',
                                            style: TextStyle(
                                              fontFamily: 'PressStart2P',
                                              fontSize: 10,
                                              color: isMe
                                                  ? AppPalette.brownSolid
                                                  : AppPalette.playerBlack,
                                            ),
                                          ),
                                          Text(
                                            '${row['score']} PTS',
                                            style: TextStyle(
                                              fontFamily: 'PressStart2P',
                                              fontSize: 10,
                                              color: isMe
                                                  ? AppPalette.brownSolid
                                                  : AppPalette.playerBlack,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  })
                                else ...[
                                  _buildStatRow('YOUR SCORE', '$score PTS'),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Waiting for other players to finish...',
                                    style: TextStyle(
                                      fontFamily: 'AtkinsonHyperlegible',
                                      fontSize: 14,
                                      color: AppPalette.textDark,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Online Exit button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppPalette.brownDark,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: const RoundedRectangleBorder(
                                  side: BorderSide(
                                      color: AppPalette.playerBlack, width: 2),
                                ),
                              ),
                              onPressed: () async {
                                AudioManager.instance.playSfx('unlock.wav');
                                game.resumeEngine();
                                await NetManager.instance.disconnect();
                                if (context.mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    ArcadePageRoute(
                                        page: const MainMenuScreen()),
                                    (route) => false,
                                  );
                                }
                              },
                              child: const Text(
                                'EXIT TO MENU',
                                style: TextStyle(
                                    fontFamily: 'PressStart2P', fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: AppPalette.textDark,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: AppPalette.brownSolid,
          ),
        ),
      ],
    );
  }
}
