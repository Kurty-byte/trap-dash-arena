import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/audio_manager.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/ui/game_screen.dart';
import 'package:trap_dash_arena/ui/widgets/arcade_page_route.dart';
import 'package:trap_dash_arena/ui/widgets/square_back_button.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  final Map<int, String> _levelNames = {
    1: 'Tutorial Dash',
    2: 'Spike Vault',
    3: 'Falling Corridor',
    4: 'Saw Gauntlet',
    5: 'Master Trial',
  };

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
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'SELECT LEVEL',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 24,
                        color: AppPalette.playerBlack,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Grid of 5 Levels
                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      alignment: WrapAlignment.center,
                      children: List.generate(GameState.totalLevels, (index) {
                        final level = index + 1;
                        final isUnlocked = GameState.instance.isUnlocked(level);
                        final stars = GameState.instance.bestStars[level] ?? 0;

                        return _buildLevelCard(
                          level: level,
                          name: _levelNames[level] ?? 'Level $level',
                          isUnlocked: isUnlocked,
                          stars: stars,
                        );
                      }),
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

  Widget _buildLevelCard({
    required int level,
    required String name,
    required bool isUnlocked,
    required int stars,
  }) {
    return GestureDetector(
      onTap: isUnlocked
          ? () {
              AudioManager.instance.playSfx('unlock.wav');
              GameState.instance.currentLevel = level;
              Navigator.of(context).push(
                ArcadePageRoute(
                  page: GameScreen(levelNumber: level),
                ),
              ).then((_) => setState(() {}));
            }
          : null,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: isUnlocked ? AppPalette.brownSolid : AppPalette.brownSolid.withValues(alpha: 0.3),
          border: Border.all(
            color: isUnlocked ? AppPalette.playerBlack : AppPalette.brownDark,
            width: 2.5,
          ),
          boxShadow: isUnlocked
              ? [
                  const BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isUnlocked) ...[
              Text(
                'LVL $level',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                style: const TextStyle(
                  fontFamily: 'AtkinsonHyperlegible',
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (i) => Icon(
                    Icons.star_rounded,
                    size: 20,
                    color: i < stars ? AppPalette.yellowBackground : Colors.white30,
                  ),
                ),
              ),
            ] else ...[
              const Icon(
                Icons.lock_rounded,
                size: 36,
                color: AppPalette.playerBlack,
              ),
              const SizedBox(height: 8),
              const Text(
                'LOCKED',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: AppPalette.playerBlack,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
