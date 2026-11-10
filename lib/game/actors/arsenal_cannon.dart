import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

class ArsenalBall extends PositionComponent
    with CollisionCallbacks, HasGameReference<TrapDashGame> {
  final double speed;
  final double minX;

  double _rotationAngle = 0.0;
  Sprite? _ballSprite;
  late final CircleHitbox hitbox;

  static final Paint _contrastPaint = Paint()
    ..color = AppPalette.warningRed
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  ArsenalBall({
    required Vector2 position,
    this.speed = 380.0,
    this.minX = 112.0,
  }) : super(
          position: position,
          size: Vector2(26, 26),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    hitbox = CircleHitbox(
      radius: size.x / 2 - 2,
      position: Vector2.all(2),
      collisionType: CollisionType.passive,
    );
    add(hitbox);

    try {
      final cached = game.tryGetCachedSprite('game/ball.png');
      if (cached != null) {
        _ballSprite = cached;
      } else {
        _ballSprite = await game.loadSprite('game/ball.png');
      }
    } catch (_) {
      // Fallback for tests
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _rotationAngle -= dt * 10.0;
    position.x -= speed * dt;

    if (position.x <= minX) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (other is Player && !other.isWarping && !other.isInDeathCycle) {
      other.takeDamage();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final radius = size.x / 2;
    canvas.save();
    canvas.translate(radius, radius);
    canvas.rotate(_rotationAngle);

    if (_ballSprite != null) {
      _ballSprite!.render(
        canvas,
        position: Vector2(-radius, -radius),
        size: size,
      );
    } else {
      final ballPaint = Paint()..color = AppPalette.brownSolid;
      canvas.drawCircle(Offset.zero, radius * 0.85, ballPaint);
    }

    if (GameState.instance.highContrastTells) {
      canvas.drawCircle(Offset.zero, radius, _contrastPaint);
    }

    canvas.restore();
  }
}

class ArsenalCannon extends PositionComponent with HasGameReference<TrapDashGame> {
  final String trapId;
  final double row1Y;
  final double row2Y;
  final List<int> rowPattern;
  final List<List<int>>? rowPatternSets;
  final double moveSpeed;
  final double fireInterval;
  final double ballSpeed;
  final double activeMinPlayerX;
  final double activeMaxPlayerX;
  final bool spawnHiddenBelow;
  final double triggerPlayerX;
  final double hiddenY;
  final double emergeSpeed;

  late bool isRevealed;
  bool _isEmerging = false;
  int patternIndex = 0;
  int activePatternSetIndex = 0;
  bool isDisabled = false;
  double _shotTimer = 0.85;
  late final Vector2 _initialPosition;
  bool _baitAwarded = false;
  Sprite? _cannonSprite;

  List<int> get activeRowPattern {
    if (rowPatternSets != null && rowPatternSets!.isNotEmpty) {
      return rowPatternSets![activePatternSetIndex % rowPatternSets!.length];
    }
    return rowPattern;
  }

  static final Paint _contrastPaint = Paint()
    ..color = AppPalette.warningRed
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  ArsenalCannon({
    required this.trapId,
    required Vector2 position,
    this.row1Y = 530.0,
    this.row2Y = 474.0,
    this.rowPattern = const [1, 2, 1, 2, 2, 1],
    this.rowPatternSets,
    this.moveSpeed = 320.0,
    this.fireInterval = 0.85,
    this.ballSpeed = 380.0,
    this.activeMinPlayerX = 96.0,
    this.activeMaxPlayerX = 1184.0,
    this.spawnHiddenBelow = false,
    this.triggerPlayerX = 0.0,
    this.hiddenY = 596.0,
    this.emergeSpeed = 420.0,
  })  : isRevealed = !spawnHiddenBelow,
        super(
          position: spawnHiddenBelow ? Vector2(position.x, hiddenY) : position,
          size: Vector2(44, 48),
          anchor: Anchor.center,
        ) {
    _initialPosition = spawnHiddenBelow
        ? Vector2(position.x, hiddenY)
        : position.clone();
    _shotTimer = fireInterval;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      final cached = game.tryGetCachedSprite('game/arsenal.png');
      if (cached != null) {
        _cannonSprite = cached;
      } else {
        _cannonSprite = await game.loadSprite('game/arsenal.png');
      }
    } catch (_) {
      // Fallback for tests
    }
  }

  void fireBall() {
    if (isDisabled) return;

    final ball = ArsenalBall(
      position: Vector2(position.x - 24.0, position.y),
      speed: ballSpeed,
      minX: activeMinPlayerX,
    );
    game.world.add(ball);

    game.audio.playSfx('trap_trigger.wav');
    if (!_baitAwarded) {
      _baitAwarded = true;
      game.controller.onTrapBait(trapId);
    }
  }

  void disable() {
    isDisabled = true;
    for (final ball in game.world.children.whereType<ArsenalBall>().toList()) {
      ball.removeFromParent();
    }
  }

  void resetToInitial() {
    isDisabled = false;
    patternIndex = 0;
    isRevealed = !spawnHiddenBelow;
    _isEmerging = false;
    position.setFrom(_initialPosition);
    _shotTimer = fireInterval;
    _baitAwarded = false;
    for (final ball in game.world.children.whereType<ArsenalBall>().toList()) {
      ball.removeFromParent();
    }
    if (rowPatternSets != null && rowPatternSets!.length > 1) {
      activePatternSetIndex = (activePatternSetIndex + 1) % rowPatternSets!.length;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isDisabled) return;

    try {
      final player = game.player;
      if (player.position.x < activeMinPlayerX ||
          player.position.x > activeMaxPlayerX ||
          player.isInDeathCycle) {
        return;
      }

      if (!isRevealed) {
        if (player.position.x >= triggerPlayerX) {
          isRevealed = true;
          _isEmerging = true;
          _shotTimer = 0.20; // Fires right after popping up!
          game.audio.playSfx('trap_trigger.wav');
        } else {
          return;
        }
      }
    } catch (_) {
      // Tests where player is not initialized yet
    }

    if (!isRevealed) return;

    final currentPattern = activeRowPattern;
    final targetY = currentPattern[patternIndex % currentPattern.length] == 1 ? row1Y : row2Y;

    if (_isEmerging) {
      position.y -= emergeSpeed * dt;
      if (position.y <= targetY) {
        position.y = targetY;
        _isEmerging = false;
      }
      return;
    }

    // Glide vertically toward target row
    final diff = targetY - position.y;
    if (diff.abs() > 0.5) {
      final step = (diff > 0 ? 1.0 : -1.0) * moveSpeed * dt;
      if (step.abs() >= diff.abs()) {
        position.y = targetY;
      } else {
        position.y += step;
      }
    } else {
      position.y = targetY;
    }

    // Fire cycle
    _shotTimer -= dt;
    if (_shotTimer <= 0) {
      fireBall();
      patternIndex = (patternIndex + 1) % currentPattern.length;
      _shotTimer = fireInterval;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!isRevealed) return;
    super.render(canvas);

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    // Rotate +90 degrees so barrel faces left
    canvas.rotate(pi / 2);

    final overridePaint = isDisabled
        ? (Paint()..color = AppPalette.playerBlack.withValues(alpha: 0.45))
        : null;

    if (_cannonSprite != null) {
      _cannonSprite!.render(
        canvas,
        position: Vector2(-size.y / 2, -size.x / 2),
        size: Vector2(size.y, size.x),
        overridePaint: overridePaint,
      );
    } else {
      final paint = overridePaint ?? (Paint()..color = AppPalette.brownSolid);
      canvas.drawRect(
        Rect.fromLTWH(-size.y / 2, -size.x / 2, size.y, size.x),
        paint,
      );
    }

    if (GameState.instance.highContrastTells) {
      canvas.drawRect(
        Rect.fromLTWH(-size.y / 2, -size.x / 2, size.y, size.x),
        _contrastPaint,
      );
    }

    canvas.restore();
  }
}

class DisableButton extends PositionComponent
    with CollisionCallbacks, HasGameReference<TrapDashGame> {
  final String trapId;
  final ArsenalCannon? targetCannon;

  bool isPressed = false;
  bool _baitAwarded = false;
  Sprite? _unpressedSprite;
  Sprite? _pressedSprite;

  DisableButton({
    required this.trapId,
    required Vector2 position,
    this.targetCannon,
  }) : super(
          position: position,
          size: Vector2(28, 20),
          anchor: Anchor.bottomCenter,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(
      size: size,
      collisionType: CollisionType.passive,
    ));

    try {
      final cachedImg = game.tryGetCachedImage('game/button.png');
      if (cachedImg != null) {
        _unpressedSprite = Sprite(cachedImg, srcPosition: Vector2(0, 0), srcSize: Vector2(40, 32));
        _pressedSprite = Sprite(cachedImg, srcPosition: Vector2(40, 0), srcSize: Vector2(40, 32));
      } else {
        final img = await game.images.load('game/button.png');
        _unpressedSprite = Sprite(img, srcPosition: Vector2(0, 0), srcSize: Vector2(40, 32));
        _pressedSprite = Sprite(img, srcPosition: Vector2(40, 0), srcSize: Vector2(40, 32));
      }
    } catch (_) {
      // Fallback for tests
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (other is Player && !isPressed) {
      isPressed = true;
      if (targetCannon != null) {
        targetCannon!.disable();
      } else {
        ArsenalCannon? closest;
        double minDistance = double.infinity;
        for (final c in game.world.children.whereType<ArsenalCannon>()) {
          final dist = (c.position.x - position.x).abs();
          if (dist < minDistance && dist <= 1280.0) {
            minDistance = dist;
            closest = c;
          }
        }
        closest?.disable();
      }

      game.audio.playSfx('unlock.wav');
      game.shakeCamera(intensity: 4.0, duration: 0.12);

      if (!_baitAwarded) {
        _baitAwarded = true;
        game.controller.onTrapBait(trapId);
      }
    }
  }

  void resetToInitial() {
    isPressed = false;
    _baitAwarded = false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (_unpressedSprite != null && _pressedSprite != null) {
      final sprite = isPressed ? _pressedSprite! : _unpressedSprite!;
      sprite.render(canvas, size: size);
    } else {
      final paint = Paint()
        ..color = isPressed ? AppPalette.doorTeal : AppPalette.brownSolid;
      canvas.drawRRect(
        RRect.fromRectAndRadius(size.toRect(), const Radius.circular(4)),
        paint,
      );
    }
  }
}
