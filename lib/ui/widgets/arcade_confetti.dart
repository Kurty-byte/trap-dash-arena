import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/palette.dart';

class _ConfettiParticle {
  final double xRatio;
  final double yRatio;
  final double vx;
  final double vy;
  final double gravity;
  final double flutterFreq;
  final double flutterAmp;
  final double width;
  final double height;
  final double rotationSpeed;
  final Color color;

  const _ConfettiParticle({
    required this.xRatio,
    required this.yRatio,
    required this.vx,
    required this.vy,
    required this.gravity,
    required this.flutterFreq,
    required this.flutterAmp,
    required this.width,
    required this.height,
    required this.rotationSpeed,
    required this.color,
  });
}

class ArcadeConfetti extends StatefulWidget {
  final int count;
  final Duration duration;

  const ArcadeConfetti({
    super.key = const Key('arcade_confetti_overlay'),
    this.count = 72,
    this.duration = const Duration(milliseconds: 3200),
  });

  @override
  State<ArcadeConfetti> createState() => _ArcadeConfettiState();
}

class _ArcadeConfettiState extends State<ArcadeConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiParticle> _particles;

  static const List<Color> _paletteColors = [
    AppPalette.yellowBackground,
    AppPalette.cardYellow,
    AppPalette.brownSolid,
    AppPalette.doorTeal,
    AppPalette.warningRed,
    AppPalette.whiteAccent,
    AppPalette.playerBlack,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();

    final rng = math.Random(1337); // Seeded for deterministic testing
    _particles = List.generate(widget.count, (i) {
      final color = _paletteColors[i % _paletteColors.length];
      final sizeW = 6.0 + rng.nextDouble() * 8.0;
      final sizeH = 5.0 + rng.nextDouble() * 6.0;

      return _ConfettiParticle(
        xRatio: rng.nextDouble(),
        yRatio: -0.15 + (rng.nextDouble() * 0.25),
        vx: -60.0 + (rng.nextDouble() * 120.0),
        vy: 140.0 + (rng.nextDouble() * 260.0),
        gravity: 120.0 + (rng.nextDouble() * 80.0),
        flutterFreq: 2.0 + (rng.nextDouble() * 4.0),
        flutterAmp: 14.0 + (rng.nextDouble() * 24.0),
        width: sizeW,
        height: sizeH,
        rotationSpeed: -3.0 + (rng.nextDouble() * 6.0),
        color: color,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              size: Size.infinite,
              painter: _ConfettiPainter(
                particles: _particles,
                progress: _controller.value,
                durationSeconds: widget.duration.inMilliseconds / 1000.0,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;
  final double durationSeconds;

  _ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.durationSeconds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final t = progress * durationSeconds;

    for (final p in particles) {
      // Loop seamlessly using modulo so confetti keeps raining during result display
      final loopT = (t + (p.xRatio * 1.5)) % durationSeconds;

      final startX = p.xRatio * size.width;
      final startY = p.yRatio * size.height;

      final flutter = math.sin(loopT * p.flutterFreq * math.pi) * p.flutterAmp;
      final x = (startX + p.vx * loopT + flutter) % (size.width + 30) - 15;
      final y = (startY + p.vy * loopT + (0.5 * p.gravity * loopT * loopT)) %
          (size.height + 40) - 20;

      final angle = loopT * p.rotationSpeed * math.pi;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);

      final paint = Paint()
        ..color = p.color
        ..style = PaintingStyle.fill;

      // Pixel-perfect sharp rectangle
      canvas.drawRect(
        Rect.fromLTWH(-p.width / 2, -p.height / 2, p.width, p.height),
        paint,
      );

      // Dark retro pixel border for high readability on any background
      final borderPaint = Paint()
        ..color = AppPalette.playerBlack.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawRect(
        Rect.fromLTWH(-p.width / 2, -p.height / 2, p.width, p.height),
        borderPaint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
