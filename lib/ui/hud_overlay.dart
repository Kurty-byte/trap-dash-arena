import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/net_manager.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';
import 'package:trap_dash_arena/ui/widgets/hud_sprite.dart';

class HudOverlay extends StatelessWidget {
  final TrapDashGame game;

  const HudOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final controller = game.controller;

    return Positioned.fill(
      child: RepaintBoundary(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar seated cleanly inside the 72px top solid wall
              SizedBox(
                height: 58,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left cluster: [Pause] [Restart], Hearts & Keys
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pixel-Art Pause Button
                        HudSpriteButton(
                          key: const Key('hud_pause_button'),
                          sprite: HudSpriteType.pause,
                          size: 32,
                          tooltip: 'Pause',
                          onTap: () => game.pauseGame(),
                        ),
                        const SizedBox(width: 4),

                        // Pixel-Art Quick-Restart Button
                        HudSpriteButton(
                          key: const Key('hud_restart_button'),
                          sprite: HudSpriteType.restartCw,
                          size: 32,
                          tooltip: 'Restart Level',
                          onTap: () => game.restartLevel(),
                        ),
                        const SizedBox(width: 8),

                        // Hearts Row
                        ValueListenableBuilder<int>(
                          valueListenable: controller.hearts,
                          builder: (context, heartsVal, _) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                controller.config.initialHearts,
                                (index) => Padding(
                                  padding: const EdgeInsets.only(right: 3),
                                  child: Icon(
                                    Icons.favorite_rounded,
                                    color: index < heartsVal
                                        ? AppPalette.yellowBackground
                                        : AppPalette.playerBlack.withValues(alpha: 0.4),
                                    size: 22,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Keys count badge if keys required
                        if (controller.config.requiredKeys > 0) ...[
                          const SizedBox(width: 8),
                          ValueListenableBuilder<int>(
                            valueListenable: controller.keysCollected,
                            builder: (context, keysVal, _) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppPalette.playerBlack,
                                  border: Border.all(
                                    color: AppPalette.yellowBackground,
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.vpn_key_rounded,
                                      color: AppPalette.yellowBackground,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$keysVal/${controller.config.requiredKeys}',
                                      style: const TextStyle(
                                        fontFamily: 'PressStart2P',
                                        fontSize: 10,
                                        color: AppPalette.yellowBackground,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),

                    // Center cluster: 5-stage progress indicator + Goal Text Banner
                    Flexible(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 5 level-progress indicator squares (matching sample.jpg top header)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (i) {
                                final isCurrent = i + 1 == game.currentLevelNumber;
                                final isPast = i + 1 < game.currentLevelNumber;
                                return Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? AppPalette.playerBlack
                                        : (isPast ? AppPalette.yellowBackground : Colors.transparent),
                                    border: Border.all(
                                      color: isCurrent
                                          ? AppPalette.playerBlack
                                          : AppPalette.yellowBackground,
                                      width: 1.2,
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 3),

                            // Goal Banner
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppPalette.yellowBackground,
                                  border: Border.all(
                                    color: AppPalette.playerBlack,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  controller.config.goalText,
                                  style: const TextStyle(
                                    fontFamily: 'AtkinsonHyperlegible',
                                    fontSize: 13,
                                    color: AppPalette.playerBlack,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Right cluster: Pace-Bot, Timer, Score
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pace-Bot badge if active
                        if (game.paceBot != null) ...[
                          ValueListenableBuilder<int>(
                            valueListenable: game.paceBot!.score,
                            builder: (context, botScore, _) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppPalette.playerBlack,
                                  border: Border.all(
                                    color: AppPalette.yellowBackground,
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  'BOT: $botScore',
                                  style: const TextStyle(
                                    fontFamily: 'PressStart2P',
                                    fontSize: 9,
                                    color: AppPalette.yellowBackground,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                        ],

                        // Timer
                        ValueListenableBuilder<int>(
                          valueListenable: controller.displayTimeSeconds,
                          builder: (context, secondsVal, _) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  color: AppPalette.yellowBackground,
                                  size: 18,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${secondsVal}s',
                                  style: const TextStyle(
                                    fontFamily: 'PressStart2P',
                                    fontSize: 12,
                                    color: AppPalette.yellowBackground,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(width: 10),

                        // Score
                        ValueListenableBuilder<int>(
                          valueListenable: controller.score,
                          builder: (context, scoreVal, _) {
                            return Text(
                              '$scoreVal PTS',
                              style: const TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 12,
                                color: AppPalette.yellowBackground,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Online multiplayer live leaderboard (tucked just under top wall)
              if (GameState.instance.mode == 'online') ...[
                const SizedBox(height: 2),
                ValueListenableBuilder<Map<String, int>>(
                  valueListenable: NetManager.instance.playerScores,
                  builder: (context, scores, _) {
                    final players = NetManager.instance.players.value;
                    if (players.isEmpty) return const SizedBox.shrink();

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppPalette.yellowBackground,
                            border: Border.all(color: AppPalette.brownSolid, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: players.entries.map((entry) {
                              final id = entry.key;
                              final name = entry.value;
                              final sc = scores[id] ?? 0;
                              final isMe = id == NetManager.instance.localPlayerId;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                child: Text(
                                  '$name: $sc',
                                  style: TextStyle(
                                    fontFamily: 'PressStart2P',
                                    fontSize: 9,
                                    color: isMe ? AppPalette.brownSolid : AppPalette.playerBlack,
                                    fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
