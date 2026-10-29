import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/audio_manager.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';
import 'package:trap_dash_arena/ui/hud_overlay.dart';
import 'package:trap_dash_arena/ui/pause_overlay.dart';
import 'package:trap_dash_arena/ui/respawn_overlay.dart';
import 'package:trap_dash_arena/ui/result_screen.dart';
import 'package:trap_dash_arena/ui/touch_controls_overlay.dart';

class GameScreen extends StatefulWidget {
  final int levelNumber;

  const GameScreen({super.key, this.levelNumber = 1});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late TrapDashGame _game;

  @override
  void initState() {
    super.initState();
    AudioManager.instance.enterGameplay();
    _game = TrapDashGame(currentLevelNumber: widget.levelNumber);
  }

  @override
  void dispose() {
    AudioManager.instance.exitGameplay();
    super.dispose();
  }

  Widget _buildLoadingIndicator() {
    return Container(
      color: AppPalette.yellowBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/game/icon.png',
              width: 56,
              height: 56,
              filterQuality: FilterQuality.none,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox(width: 56, height: 56),
            ),
            const SizedBox(height: 16),
            const Text(
              'LOADING...',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 18,
                color: AppPalette.playerBlack,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'LEVEL ${widget.levelNumber}',
              style: const TextStyle(
                fontFamily: 'AtkinsonHyperlegible',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppPalette.brownSolid,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_game.overlays.isActive('PauseOverlay')) {
            _game.resumeGame();
          } else {
            _game.pauseGame();
          }
        }
      },
      child: Scaffold(
        body: GameWidget<TrapDashGame>(
          game: _game,
          loadingBuilder: (context) => _buildLoadingIndicator(),
          overlayBuilderMap: {
            'Hud': (context, game) => HudOverlay(game: game),
            'TouchControls': (context, game) => TouchControlsOverlay(game: game),
            'RespawnOverlay': (context, game) => RespawnOverlay(game: game),
            'PauseOverlay': (context, game) => PauseOverlay(game: game),
            'ResultOverlay': (context, game) => ResultOverlay(game: game),
            'LoadingOverlay': (context, game) => _buildLoadingIndicator(),
          },
          initialActiveOverlays: const ['Hud', 'TouchControls'],
        ),
      ),
    );
  }
}
