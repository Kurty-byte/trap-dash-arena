import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/palette.dart';

class HintArrow extends PositionComponent {
  HintArrow({required Vector2 position})
      : super(
          position: position,
          size: Vector2(24, 24),
          anchor: Anchor.center,
          priority: -1,
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final arrowPaint = Paint()
      ..color = AppPalette.brownSolid.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.square;

    final path = Path()
      ..moveTo(4, 3)
      ..lineTo(16, 12)
      ..lineTo(4, 21);

    canvas.drawPath(path, arrowPaint);
  }
}
