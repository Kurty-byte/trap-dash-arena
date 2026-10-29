import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:trap_dash_arena/autoload/palette.dart';

enum ShardEffectMode {
  disintegrate,
  reintegrate,
}

class ShardTrajectory {
  final Vector2 homeOffset;
  final Vector2 velocity;
  final double gravity;
  final double angularSpan;

  const ShardTrajectory({
    required this.homeOffset,
    required this.velocity,
    this.gravity = 520.0,
    this.angularSpan = 0.0,
  });

  ShardTrajectory mirroredX() {
    return ShardTrajectory(
      homeOffset: Vector2(-homeOffset.x, homeOffset.y),
      velocity: Vector2(-velocity.x, velocity.y),
      gravity: gravity,
      angularSpan: -angularSpan,
    );
  }

  static List<ShardTrajectory> generate({
    Random? rng,
    bool isPitFall = false,
    bool facingLeft = false,
  }) {
    final rand = rng ?? Random();

    // 6 cols x 10 rows matching the 24x38 player silhouette:
    // . # # # # .   (row 0: head top)
    // # # # # # #   (row 1: head mid)
    // . # # # # .   (row 2: head bottom)
    // . # # # # .   (row 3: shoulders)
    // # # # # # #   (row 4: torso + arms)
    // # # # # # #   (row 5: torso + arms)
    // # # # # # #   (row 6: waist)
    // # # . . # #   (row 7: upper legs)
    // # # . . # #   (row 8: lower legs)
    // # # . . # #   (row 9: feet)
    const pattern = [
      [0, 1, 1, 1, 1, 0],
      [1, 1, 1, 1, 1, 1],
      [0, 1, 1, 1, 1, 0],
      [0, 1, 1, 1, 1, 0],
      [1, 1, 1, 1, 1, 1],
      [1, 1, 1, 1, 1, 1],
      [1, 1, 1, 1, 1, 1],
      [1, 1, 0, 0, 1, 1],
      [1, 1, 0, 0, 1, 1],
      [1, 1, 0, 0, 1, 1],
    ];

    const double cellW = 4.0;
    const double cellH = 3.8;
    const double totalW = 24.0;
    const double totalH = 38.0;

    final List<ShardTrajectory> list = [];

    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 6; c++) {
        if (pattern[r][c] == 0) continue;

        // Offset relative to Anchor.bottomCenter:
        // x in [-12, +12], y in [-38, 0]
        final localX = (c * cellW + cellW / 2) - (totalW / 2);
        final localY = (r * cellH + cellH / 2) - totalH;

        final homeOffset = Vector2(localX, localY);

        Vector2 vel;
        if (isPitFall) {
          // Splash upwards from pit
          final vx = (rand.nextDouble() * 2 - 1) * 140.0;
          final vy = -180.0 - rand.nextDouble() * 220.0;
          vel = Vector2(vx, vy);
        } else {
          // Outward radial burst from center of mass (0, -19)
          final dir = Vector2(localX, localY + 19.0);
          final dist = dir.length;
          final normDir = dist > 0.001 ? (dir / dist) : Vector2(0, -1);

          // Add jitter to angle
          final angleJitter = (rand.nextDouble() - 0.5) * 0.8;
          final cosA = cos(angleJitter);
          final sinA = sin(angleJitter);
          final jitteredDir = Vector2(
            normDir.x * cosA - normDir.y * sinA,
            normDir.x * sinA + normDir.y * cosA,
          );

          // Upward bias
          jitteredDir.y -= 0.35;
          final finalDir = jitteredDir.normalized();

          final speed = 120.0 + rand.nextDouble() * 150.0;
          vel = finalDir * speed;
        }

        final angularSpan = (rand.nextDouble() * 2 - 1) * pi * 1.5;

        list.add(ShardTrajectory(
          homeOffset: homeOffset,
          velocity: vel,
          gravity: isPitFall ? 650.0 : 520.0,
          angularSpan: angularSpan,
        ));
      }
    }

    if (facingLeft) {
      return list.map((s) => s.mirroredX()).toList();
    }
    return list;
  }
}

class PlayerShardEffect extends PositionComponent {
  final ShardEffectMode mode;
  final List<ShardTrajectory> shards;
  final double duration;
  final VoidCallback? onComplete;

  double _elapsed = 0.0;
  bool _completed = false;
  final Paint _paint = Paint()..color = AppPalette.playerBlack;

  late final Float32List _positions;
  late final Uint16List _indices;

  PlayerShardEffect({
    required Vector2 position,
    required this.shards,
    this.mode = ShardEffectMode.disintegrate,
    this.duration = 0.40,
    this.onComplete,
  }) : super(
          position: position,
          anchor: Anchor.bottomCenter,
          size: Vector2(24, 38),
        ) {
    final count = shards.length;
    _positions = Float32List(count * 4 * 2);
    _indices = Uint16List(count * 6);
    for (int i = 0; i < count; i++) {
      final b = i * 4;
      final idx = i * 6;
      _indices[idx + 0] = b + 0;
      _indices[idx + 1] = b + 1;
      _indices[idx + 2] = b + 2;
      _indices[idx + 3] = b + 0;
      _indices[idx + 4] = b + 2;
      _indices[idx + 5] = b + 3;
    }
  }

  double get progress => (_elapsed / duration).clamp(0.0, 1.0);

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    if (!_completed && _elapsed >= duration) {
      _completed = true;
      onComplete?.call();
    }
  }

  @override
  void render(Canvas canvas) {
    if (mode == ShardEffectMode.disintegrate && _elapsed >= duration) return;

    super.render(canvas);

    final u = progress;

    // Disintegrate: tau goes 0.0 -> 1.0 (easeOutCubic)
    // Reintegrate: tau goes 1.0 -> 0.0 (exact reverse of easeOutCubic: tau_rev(u) = tau_dis(1 - u) = 1 - u^3)
    final double tau;
    if (mode == ShardEffectMode.disintegrate) {
      tau = 1.0 - pow(1.0 - u, 3).toDouble();
    } else {
      tau = 1.0 - pow(u, 3).toDouble();
    }

    const double tRef = 0.40;
    final double s = tau * tRef;
    final double scale = (1.0 - 0.65 * tau * tau).clamp(0.1, 1.0);
    final double alpha = (1.0 - pow(tau, 3)).clamp(0.0, 1.0).toDouble();

    final int alphaInt = (alpha * 255).toInt();
    if (alphaInt <= 0) return;

    _paint.color = AppPalette.playerBlack.withAlpha(alphaInt);

    const double shardW = 4.0;
    const double shardH = 4.0;
    final double hw = (shardW / 2) * scale;
    final double hh = (shardH / 2) * scale;

    int posIndex = 0;
    for (int i = 0; i < shards.length; i++) {
      final shard = shards[i];
      final double sx = shard.homeOffset.x + shard.velocity.x * s;
      final double sy =
          shard.homeOffset.y + shard.velocity.y * s + 0.5 * shard.gravity * s * s;
      final double rot = shard.angularSpan * tau;

      final double dxA, dyA, dxB, dyB;
      if (rot != 0.0) {
        final double cosR = cos(rot);
        final double sinR = sin(rot);
        dxA = -hw * cosR + hh * sinR;
        dyA = -hw * sinR - hh * cosR;
        dxB =  hw * cosR + hh * sinR;
        dyB =  hw * sinR - hh * cosR;
      } else {
        dxA = -hw;
        dyA = -hh;
        dxB =  hw;
        dyB = -hh;
      }

      // Vertex 0 (TL)
      _positions[posIndex++] = sx + dxA;
      _positions[posIndex++] = sy + dyA;
      // Vertex 1 (TR)
      _positions[posIndex++] = sx + dxB;
      _positions[posIndex++] = sy + dyB;
      // Vertex 2 (BR: symmetric opposite of TL)
      _positions[posIndex++] = sx - dxA;
      _positions[posIndex++] = sy - dyA;
      // Vertex 3 (BL: symmetric opposite of TR)
      _positions[posIndex++] = sx - dxB;
      _positions[posIndex++] = sy - dyB;
    }

    final vertices = Vertices.raw(
      VertexMode.triangles,
      _positions,
      indices: _indices,
    );
    canvas.drawVertices(vertices, BlendMode.srcOver, _paint);
  }
}
