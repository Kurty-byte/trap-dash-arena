import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/palette.dart';

class ChamberBackground extends Component {
  final int roomCount;

  static final Paint _bgPaint = Paint()
    ..color = AppPalette.yellowBackground
    ..isAntiAlias = false;

  ChamberBackground({required this.roomCount}) : super(priority: -10);

  @override
  void render(Canvas canvas) {
    for (int i = 0; i < roomCount; i++) {
      final roomLeft = i * 1280.0 + 96.0;
      const roomWidth = 1088.0;

      // Playable corridor (y: 104..552) and pit abyss (y: 552..752)
      canvas.drawRect(
        Rect.fromLTWH(roomLeft, 104.0, roomWidth, 648.0),
        _bgPaint,
      );

      // Connective tunnel between rooms (y: 456..552)
      if (i < roomCount - 1) {
        final passageLeft = (i + 1) * 1280.0 - 96.0;
        canvas.drawRect(
          Rect.fromLTWH(passageLeft, 456.0, 192.0, 96.0),
          _bgPaint,
        );
      }
    }
  }
}
