import 'dart:math' as math;
import 'package:flutter/material.dart';

class HazardParticle {
  final String assetPath;
  final double initialX;
  final double initialY;
  final double vx;
  final double vy;
  final double size;
  final double rotationSpeed;

  const HazardParticle({
    required this.assetPath,
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
  final double opacity;
  final List<HazardParticle>? particles;

  const HazardBackground({
    super.key,
    required this.child,
    this.opacity = 0.13,
    this.particles,
  });

  static const List<HazardParticle> defaultParticles = [
    // Top-left rotating saw blade
    HazardParticle(
      assetPath: 'assets/game/sew.png',
      initialX: 0.12,
      initialY: 0.16,
      vx: 0.015,
      vy: 0.012,
      size: 42,
      rotationSpeed: 1.5,
    ),
    // Mid-top spike obstacle
    HazardParticle(
      assetPath: 'assets/game/obstacle.png',
      initialX: 0.44,
      initialY: 0.10,
      vx: -0.010,
      vy: 0.015,
      size: 34,
      rotationSpeed: 0.3,
    ),
    // Top-right bomb hazard
    HazardParticle(
      assetPath: 'assets/game/bomb.png',
      initialX: 0.82,
      initialY: 0.20,
      vx: -0.012,
      vy: -0.008,
      size: 38,
      rotationSpeed: -0.4,
    ),
    // Mid-left spring trap
    HazardParticle(
      assetPath: 'assets/game/spring.png',
      initialX: 0.07,
      initialY: 0.65,
      vx: 0.012,
      vy: -0.010,
      size: 36,
      rotationSpeed: 0.2,
    ),
    // Center-low iron ball hazard
    HazardParticle(
      assetPath: 'assets/game/ball.png',
      initialX: 0.52,
      initialY: 0.82,
      vx: 0.018,
      vy: -0.015,
      size: 38,
      rotationSpeed: -1.2,
    ),
    // Bottom-right saw blade (reverse rotation)
    HazardParticle(
      assetPath: 'assets/game/sew.png',
      initialX: 0.88,
      initialY: 0.74,
      vx: -0.015,
      vy: 0.010,
      size: 40,
      rotationSpeed: -1.4,
    ),
    // Bottom-left bait coin
    HazardParticle(
      assetPath: 'assets/game/coin.png',
      initialX: 0.28,
      initialY: 0.84,
      vx: 0.008,
      vy: 0.014,
      size: 30,
      rotationSpeed: 0.5,
    ),
  ];

  @override
  State<HazardBackground> createState() => _HazardBackgroundState();
}

class _HazardBackgroundState extends State<HazardBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

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
    final particles = widget.particles ?? HazardBackground.defaultParticles;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;
                  if (width <= 0 || height <= 0) return const SizedBox();

                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final progress = _controller.value;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: particles.map((p) {
                          final double rawX =
                              (p.initialX + p.vx * progress * 20) % 1.0;
                          final double rawY =
                              (p.initialY + p.vy * progress * 20) % 1.0;
                          final double px =
                              (rawX < 0 ? rawX + 1.0 : rawX) * width;
                          final double py =
                              (rawY < 0 ? rawY + 1.0 : rawY) * height;

                          final double rotation =
                              progress * 2 * math.pi * p.rotationSpeed * 5;

                          return Positioned(
                            left: px - p.size / 2,
                            top: py - p.size / 2,
                            child: Transform.rotate(
                              angle: rotation,
                              child: Opacity(
                                opacity: widget.opacity,
                                child: Image.asset(
                                  p.assetPath,
                                  width: p.size,
                                  height: p.size,
                                  filterQuality: FilterQuality.none,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const SizedBox(),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}
