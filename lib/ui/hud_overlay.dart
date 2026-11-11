import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/net_manager.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';
import 'package:trap_dash_arena/ui/widgets/hud_sprite.dart';

class HudOverlay extends StatelessWidget {
  final TrapDashGame game;

  const HudOverlay({super.key, required this.game});

  bool _canInteract(TrapDashGame game) {
    if (game.paused) return false;
    if (game.overlays.isActive('PauseOverlay')) return false;
    if (game.overlays.isActive('RespawnOverlay')) return false;
    if (game.overlays.isActive('ResultOverlay')) return false;
    if (game.overlays.isActive('LoadingOverlay')) return false;
    if (game.controller.isGameOver.value) return false;
    try {
      if (game.player.isInDeathCycle) return false;
    } catch (_) {
      // player not initialized yet
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final controller = game.controller;

    return Positioned.fill(
      child: RepaintBoundary(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar seated cleanly inside the solid wall bezel
              SizedBox(
                height: 46,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Left cluster: [Pause] [Restart], Hearts & Keys
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        // Pixel-Art Pause Button
                        HudSpriteButton(
                          key: const Key('hud_pause_button'),
                          sprite: HudSpriteType.pause,
                          size: 28,
                          tooltip: 'Pause',
                          onTap: () {
                            if (_canInteract(game)) {
                              game.pauseGame();
                            }
                          },
                        ),
                        const SizedBox(width: 4),

                        // Pixel-Art Quick-Restart Button (hidden in online mode)
                        if (GameState.instance.mode != 'online') ...[
                          HudSpriteButton(
                            key: const Key('hud_restart_button'),
                            sprite: HudSpriteType.restartCw,
                            size: 28,
                            tooltip: 'Restart Level',
                            onTap: () {
                              if (_canInteract(game)) {
                                game.restartLevel();
                              }
                            },
                          ),
                          const SizedBox(width: 4),
                        ],
                        const SizedBox(width: 4),

                        // Hearts Row with high-contrast shadow (tap to toggle Dev Infinite Lives)
                        GestureDetector(
                          key: const Key('hud_dev_hearts_toggle'),
                          onTap: () {
                            if (_canInteract(game)) {
                              GameState.instance.toggleDevMode();
                            }
                          },
                          child: ValueListenableBuilder<bool>(
                            valueListenable: GameState.instance.devMode,
                            builder: (context, isDev, _) {
                              return ValueListenableBuilder<int>(
                                valueListenable: controller.hearts,
                                builder: (context, heartsVal, _) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ...List.generate(
                                        controller.config.initialHearts,
                                        (index) => Padding(
                                          padding: const EdgeInsets.only(right: 3),
                                          child: Icon(
                                            Icons.favorite_rounded,
                                            color: (isDev || index < heartsVal)
                                                ? AppPalette.yellowBackground
                                                : AppPalette.playerBlack.withValues(alpha: 0.35),
                                            size: 19,
                                            shadows: const [
                                              Shadow(
                                                color: AppPalette.playerBlack,
                                                blurRadius: 2.0,
                                                offset: Offset(1, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isDev)
                                        Container(
                                          margin: const EdgeInsets.only(left: 2),
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppPalette.playerBlack,
                                            border: Border.all(
                                              color: AppPalette.yellowBackground,
                                              width: 1.0,
                                            ),
                                          ),
                                          child: const Text(
                                            'DEV ∞',
                                            style: TextStyle(
                                              fontFamily: 'PressStart2P',
                                              fontSize: 8,
                                              color: AppPalette.yellowBackground,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
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
                  ),

                    // Center cluster: 5-stage progress indicator + Goal Text Banner
                    Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 580),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Platform progression indicator squares
                            ValueListenableBuilder<bool>(
                              valueListenable: controller.isLevelCleared,
                              builder: (context, isCleared, _) {
                                return ValueListenableBuilder<int>(
                                  valueListenable: controller.currentPlatform,
                                  builder: (context, currentPlatformVal, _) {
                                    final totalPlatforms = controller.config.roomCount;
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: List.generate(totalPlatforms, (i) {
                                        final platformNum = i + 1;
                                        final isPast = isCleared || platformNum < currentPlatformVal;
                                        final isCurrent = !isCleared && platformNum == currentPlatformVal;
                                        return Container(
                                          key: Key('hud_platform_square_$platformNum'),
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
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 2),

                            // Goal Banner
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppPalette.yellowBackground,
                                border: Border.all(
                                  color: AppPalette.playerBlack,
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                controller.config.goalText,
                                style: const TextStyle(
                                  fontFamily: 'AtkinsonHyperlegible',
                                  fontSize: 11,
                                  color: AppPalette.playerBlack,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Right cluster: Timer, Score
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        // Timer (hidden when dev mode has no time limit)
                        ValueListenableBuilder<bool>(
                          valueListenable: GameState.instance.devMode,
                          builder: (context, isDev, _) {
                            if (isDev) return const SizedBox.shrink();
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ValueListenableBuilder<int>(
                                  valueListenable: controller.displayTimeSeconds,
                                  builder: (context, secondsVal, _) {
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.timer_outlined,
                                          color: AppPalette.yellowBackground,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${secondsVal}s',
                                          style: const TextStyle(
                                            fontFamily: 'PressStart2P',
                                            fontSize: 11,
                                            color: AppPalette.yellowBackground,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                              ],
                            );
                          },
                        ),

                        // Online Coins counter
                        if (GameState.instance.mode == 'online') ...[
                          ValueListenableBuilder<int>(
                            valueListenable: controller.coinsCollected,
                            builder: (context, coinsVal, _) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.monetization_on_outlined,
                                    color: AppPalette.yellowBackground,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '$coinsVal/6',
                                    style: const TextStyle(
                                      fontFamily: 'PressStart2P',
                                      fontSize: 11,
                                      color: AppPalette.yellowBackground,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              );
                            },
                          ),
                        ],

                        // Score
                        ValueListenableBuilder<int>(
                          valueListenable: controller.score,
                          builder: (context, scoreVal, _) {
                            return Text(
                              '$scoreVal PTS',
                              style: const TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 11,
                                color: AppPalette.yellowBackground,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

              // Online multiplayer live 1v1 leaderboard (tucked just under top wall)
              if (GameState.instance.mode == 'online') ...[
                const SizedBox(height: 2),
                ValueListenableBuilder<Map<String, int>>(
                  valueListenable: NetManager.instance.playerScores,
                  builder: (context, scores, _) {
                    return ValueListenableBuilder<Map<String, int>>(
                      valueListenable: NetManager.instance.playerCoins,
                      builder: (context, coins, _) {
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
                                  final c = coins[id] ?? 0;
                                  final isMe = id == NetManager.instance.localPlayerId;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 5),
                                    child: Text(
                                      '${isMe ? "YOU" : "RIVAL"} ($name): $sc PTS 🪙$c/6',
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
