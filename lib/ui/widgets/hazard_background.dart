import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/palette.dart';

enum HazardType { saw, spike, brick }

class _HazardParticle {
  final HazardType type;
  final double initialX;
  final double initialY;
  final double vx;
  final double vy;
  final double size;
  final double rotationSpeed;

  const _HazardParticle({
    required this.type,
    required this.initialX,
    required this.initialY,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rotationSpeed,
  });
}

class HazardBackground extends StatefulWidget {
  final Widget child;

  const HazardBackground({
    super.key,
    required this.child,
  });

  @override
  State<HazardBackground> createState() => _HazardBackgroundState();
}

class _HazardBackgroundState extends State<HazardBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const List<_HazardParticle> _particles = [
    // Top-left saw drifting slowly
    _HazardParticle(
      type: HazardType.saw,
      initialX: 0.12,
      initialY: 0.18,
      vx: 0.015,
      vy: 0.012,
      size: 34,
      rotationSpeed: 1.5,
    ),
    // Mid-top spike drifting
    _HazardParticle(
      type: HazardType.spike,
      initialX: 0.45,
      initialY: 0.10,
      vx: -0.010,
      vy: 0.015,
      size: 26,
      rotationSpeed: 0.4,
    ),
    // Top-right cracked brick
    _HazardParticle(
      type: HazardType.brick,
      initialX: 0.82,
      initialY: 0.22,
      vx: -0.012,
      vy: -0.008,
      size: 30,
      rotationSpeed: 0.2,
    ),
    // Mid-left spike
    _HazardParticle(
      type: HazardType.spike,
      initialX: 0.08,
      initialY: 0.65,
      vx: 0.012,
      vy: -0.010,
      size: 28,
      rotationSpeed: -0.5,
    ),
    // Center-low saw blade
    _HazardParticle(
      type: HazardType.saw,
      initialX: 0.52,
      initialY: 0.80,
      vx: 0.018,
      vy: -0.015,
      size: 38,
      rotationSpeed: -1.8,
    ),
    // Bottom-right saw blade
    _HazardParticle(
      type: HazardType.saw,
      initialX: 0.88,
      initialY: 0.75,
      vx: -0.015,
      vy: 0.010,
      size: 32,
      rotationSpeed: 1.2,
    ),
    // Bottom-left cracked brick
    _HazardParticle(
      type: HazardType.brick,
      initialX: 0.28,
      initialY: 0.85,
      vx: 0.008,
      vy: 0.014,
      size: 32,
      rotationSpeed: -0.3,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _HazardPainter(
                    particles: _particles,
                    progress: _controller.value,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _HazardPainter extends CustomPainter {
  final List<_HazardParticle> particles;
  final double progress;

  _HazardPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final strokePaint = Paint()
      ..color = AppPalette.brownSolid.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final fillPaint = Paint()
      ..color = AppPalette.brownSolid.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    for (final p in particles) {
      // Calculate normalized wrapped position
      final double rawX = (p.initialX + p.vx * progress * 20) % 1.0;
      final double rawY = (p.initialY + p.vy * progress * 20) % 1.0;
      final double px = (rawX < 0 ? rawX + 1.0 : rawX) * size.width;
      final double py = (rawY < 0 ? rawY + 1.0 : rawY) * size.height;

      final double rotation = progress * 2 * math.pi * p.rotationSpeed * 5;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rotation);

      switch (p.type) {
        case HazardType.saw:
          _drawSaw(canvas, p.size, strokePaint, fillPaint);
          break;
        case HazardType.spike:
          _drawSpike(canvas, p.size, strokePaint, fillPaint);
          break;
        case HazardType.brick:
          _drawBrick(canvas, p.size, strokePaint, fillPaint);
          break;
      }

      canvas.restore();
    }
  }

  void _drawSaw(Canvas canvas, double radius, Paint stroke, Paint fill) {
    final path = Path();
    const int teeth = 8;
    final double innerRadius = radius * 0.65;

    for (int i = 0; i < teeth; i++) {
      final double angle1 = (i * 2 * math.pi) / teeth;
      final double angle2 = angle1 + (math.pi / teeth);

      final double x1 = math.cos(angle1) * radius;
      final double y1 = math.sin(angle1) * radius;
      final double x2 = math.cos(angle2) * innerRadius;
      final double y2 = math.sin(angle2) * innerRadius;

      if (i == 0) {
        path.moveTo(x1, y1);
      } else {
        path.lineTo(x1, y1);
      }
      path.lineTo(x2, y2);
    }
    path.close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
    // Center axle hole
    canvas.drawCircle(Offset.zero, radius * 0.2, stroke);
  }

  void _drawSpike(Canvas canvas, double size, Paint stroke, Paint fill) {
    final path = Path()
      ..moveTo(0, -size / 2) // Top tip
      ..lineTo(size / 2, size / 2) // Bottom right
      ..lineTo(-size / 2, size / 2) // Bottom left
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
    // Base line
    canvas.drawLine(
      Offset(-size / 2, size / 2),
      Offset(size / 2, size / 2),
      stroke,
    );
  }

  void _drawBrick(Canvas canvas, double size, Paint stroke, Paint fill) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size * 1.3,
      height: size * 0.8,
    );

    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);

    // Jagged crack line through brick
    final crack = Path()
      ..moveTo(-size * 0.5, -size * 0.4)
      ..lineTo(-size * 0.1, -size * 0.1)
      ..lineTo(-size * 0.2, size * 0.1)
      ..lineTo(size * 0.3, size * 0.4);

    canvas.drawPath(crack, stroke);
  }

  @override
  bool shouldRepaint(covariant _HazardPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
