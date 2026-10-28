import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

/// Offline Pace-Bot ghost rival runner with visible silhouette and live score simulation.
class SimpleAI extends PositionComponent with HasGameReference<TrapDashGame> {
  final int levelNumber;
  final Vector2 startPosition;
  final double defaultExitX;

  final ValueNotifier<int> score = ValueNotifier<int>(0);
  final ValueNotifier<double> progress = ValueNotifier<double>(0.0);

  late final double intervalDelay;
  double _timer = 0.0;
  bool isFinished = false;

  List<Sprite>? _sprites;
  int _currentFrame = 0;
  double _animTimer = 0.0;
  late final TextPainter _textPainter;

  SimpleAI({
    required this.levelNumber,
    Vector2? startPosition,
    this.defaultExitX = 1200.0,
  })  : startPosition = startPosition ?? Vector2(64, 640),
        super(
          position: startPosition ?? Vector2(64, 640),
          size: Vector2(24, 38),
          anchor: Anchor.bottomCenter,
          priority: 10,
        ) {
    intervalDelay = calculateInterval(levelNumber);
    _textPainter = TextPainter(
      text: const TextSpan(
        text: 'BOT',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 7,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  static double calculateInterval(int level) {
    return max(0.8, 3.0 - 0.4 * (level - 1));
  }

  double get exitX {
    try {
      if (isMounted) return game.exitX;
    } catch (_) {}
    return defaultExitX;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      if (isMounted) {
        final playerImage = await game.images.load('game/player.png');
        _sprites = List.generate(
          5,
          (i) => Sprite(
            playerImage,
            srcPosition: Vector2(i * 40.0, 0),
            srcSize: Vector2(40, 64),
          ),
        );
      }
    } catch (_) {
      // Fallback for headless tests
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isFinished) return;

    _timer += dt;
    _animTimer += dt * 8.0;
    _currentFrame = 1 + (_animTimer.toInt() % 4);

    if (_timer >= intervalDelay) {
      _timer = 0.0;
      score.value += 35;
      progress.value = min(1.0, progress.value + 0.05);

      if (progress.value >= 1.0) {
        isFinished = true;
      }
    }

    // Move smoothly across level based on progress and current step fraction
    final stepFraction = progress.value + (_timer / intervalDelay) * 0.05;
    final clampedFraction = min(1.0, max(0.0, stepFraction));
    final targetX =
        startPosition.x + (exitX - startPosition.x) * clampedFraction;
    position.x = targetX;

    // Slight run bob
    final runBob = sin(_animTimer * 12.0) * 1.5;
    position.y = startPosition.y + runBob;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.save();

    // Flip horizontally: sprite natively faces left, flip when running right
    canvas.translate(size.x, 0);
    canvas.scale(-1, 1);

    // Translucent ghost paint (Level Devil monotone silhouette with 45% opacity)
    final ghostPaint = Paint()..color = const Color(0x77000000);

    if (_sprites != null && _sprites!.length > _currentFrame) {
      _sprites![_currentFrame].render(
        canvas,
        size: size,
        overridePaint: ghostPaint,
      );
    } else {
      // Minimalist fallback for headless tests
      canvas.drawRRect(
        RRect.fromRectAndRadius(size.toRect(), const Radius.circular(3)),
        ghostPaint,
      );
    }

    canvas.restore();

    // Floating square "BOT" tag above head
    final badgeRect = Rect.fromLTWH(size.x / 2 - 13, -15, 26, 11);
    final badgePaint = Paint()..color = AppPalette.brownSolid;
    canvas.drawRect(badgeRect, badgePaint);

    final borderPaint = Paint()
      ..color = AppPalette.playerBlack
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(badgeRect, borderPaint);

    _textPainter.paint(canvas, Offset(size.x / 2 - 10, -14));
  }

  void reset() {
    score.value = 0;
    progress.value = 0.0;
    _timer = 0.0;
    _animTimer = 0.0;
    _currentFrame = 0;
    isFinished = false;
    position.setFrom(startPosition);
  }
}
