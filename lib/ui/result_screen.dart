import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/audio_manager.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/net_manager.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/level_controller.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';
import 'package:trap_dash_arena/ui/main_menu_screen.dart';
import 'package:trap_dash_arena/ui/widgets/arcade_confetti.dart';
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
    final isFinalVictory = won && currentLevel == GameState.totalLevels;

    return Positioned.fill(
      child: Stack(
        children: [
          ModalBarrier(
            dismissible: false,
            color: Colors.black.withValues(alpha: 0.75),
          ),
          if (isFinalVictory)
            const Positioned.fill(
              child: ArcadeConfetti(),
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
                    won
                        ? (isFinalVictory ? 'ARENA CONQUERED!' : 'VICTORY!')
                        : 'GAME OVER',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: isFinalVictory ? 18 : 22,
                      color: won ? AppPalette.playerBlack : AppPalette.warningRed,
                      letterSpacing: isFinalVictory ? 1 : 0,
                    ),
                    textAlign: TextAlign.center,
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
                    const SizedBox(height: 12),

                    // Special Grand Finale Completion Message on Level 5
                    if (isFinalVictory) ...[
                      Container(
                        key: const Key('level5_finale_message'),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppPalette.cardYellow,
                          border: Border.all(
                            color: AppPalette.brownSolid,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          stars == 3
                              ? 'GRANDMASTER! ALL 5 CHAMBERS CLEARED FLAWLESSLY!'
                              : stars == 2
                                  ? 'CHAMPION! YOU OUTSMARTED EVERY TRAP IN THE ARENA!'
                                  : 'SURVIVOR! YOU CONQUERED THE MASTER GAUNTLET!',
                          style: const TextStyle(
                            fontFamily: 'AtkinsonHyperlegible',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppPalette.playerBlack,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 2),
                    ],
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
                  // Online multiplayer 1v1 result
                  ValueListenableBuilder<List<Map<String, dynamic>>?>(
                    valueListenable: NetManager.instance.finalScoreboard,
                    builder: (context, board, _) {
                      final hasWinner = board != null;
                      final isForfeit = NetManager.instance.opponentDisconnected.value;
                      final isDraw = NetManager.instance.matchWinnerId.value == 'draw';
                      final isWinner = hasWinner &&
                          !isDraw &&
                          NetManager.instance.matchWinnerId.value ==
                              NetManager.instance.localPlayerId;

                      final String titleText;
                      if (isForfeit) {
                        titleText = 'WIN BY FORFEIT!';
                      } else if (!hasWinner) {
                        titleText = 'WAITING FOR RIVAL...';
                      } else if (isDraw) {
                        titleText = 'MATCH DRAW!';
                      } else if (isWinner) {
                        titleText = 'MATCH VICTORY!';
                      } else {
                        titleText = 'MATCH DEFEAT';
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            titleText,
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 16,
                              color: (isWinner || isForfeit)
                                  ? AppPalette.playerBlack
                                  : isDraw
                                      ? AppPalette.textDark
                                      : AppPalette.warningRed,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),

                          // 1v1 Standings breakdown
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
                                  '1v1 MATCH BREAKDOWN:',
                                  style: TextStyle(
                                    fontFamily: 'PressStart2P',
                                    fontSize: 10,
                                    color: AppPalette.playerBlack,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (board != null)
                                  ...List.generate(board.length, (idx) {
                                    final row = board[idx];
                                    final isMe = row['id'] ==
                                        NetManager.instance.localPlayerId;
                                    final coins = row['coins'] ?? 0;
                                    final coinPts = coins * 100;
                                    final timeBonus = row['timeBonus'] ?? 0;
                                    final wonStage = row['won'] == true;
                                    final forfeit = row['forfeit'] == true;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? AppPalette.brownSolid.withValues(alpha: 0.15)
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isMe ? AppPalette.brownSolid : AppPalette.brownDark.withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '${isMe ? "YOU" : "RIVAL"} (${row['name']})',
                                                style: TextStyle(
                                                  fontFamily: 'PressStart2P',
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isMe
                                                      ? AppPalette.brownSolid
                                                      : AppPalette.playerBlack,
                                                ),
                                              ),
                                              Text(
                                                '${row['score']} PTS',
                                                style: TextStyle(
                                                  fontFamily: 'PressStart2P',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isMe
                                                      ? AppPalette.brownSolid
                                                      : AppPalette.playerBlack,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '🪙 Coins: $coins/${LevelController.totalOnlineCoins} (+$coinPts PTS) | ⏱️ Time: ${wonStage ? "+$timeBonus PTS" : (forfeit ? "FORFEIT" : "0 PTS (ELIMINATED)")}',
                                            style: const TextStyle(
                                              fontFamily: 'AtkinsonHyperlegible',
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: AppPalette.textDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  })
                                else ...[
                                  _buildStatRow('YOUR SCORE', '$score PTS'),
                                  const SizedBox(height: 6),
                                  _buildStatRow('COINS', '${controller.coinsCollected.value}/${LevelController.totalOnlineCoins}'),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Waiting for rival to finish...',
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
                          const SizedBox(height: 18),

                          // Online Buttons
                          Row(
                            children: [
                              if (NetManager.instance.isConnected.value && !isForfeit) ...[
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppPalette.brownSolid,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: const RoundedRectangleBorder(
                                        side: BorderSide(
                                            color: AppPalette.playerBlack, width: 2),
                                      ),
                                    ),
                                    onPressed: () {
                                      AudioManager.instance.playSfx('unlock.wav');
                                      game.resumeEngine();
                                      NetManager.instance.returnToLobby();
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text(
                                      'BACK TO LOBBY',
                                      style: TextStyle(
                                          fontFamily: 'PressStart2P', fontSize: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppPalette.brownDark,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                                        fontFamily: 'PressStart2P', fontSize: 10),
                                  ),
                                ),
                              ),
                            ],
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
