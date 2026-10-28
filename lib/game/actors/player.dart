import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

class Player extends PositionComponent
    with CollisionCallbacks, HasGameReference<TrapDashGame> {
  // Kinematic platformer tuning parameters (32x32 tile scale)
  static const double moveSpeed = 240.0;
  static const double jumpVelocity = -659.0;
  static const double riseGravity = 1938.0;
  static const double fallGravity = 3488.0;
  static const double maxFallSpeed = 750.0;
  static const double coyoteDuration = 0.10;
  static const double jumpBufferDuration = 0.10;

  final Vector2 velocity = Vector2.zero();
  bool isOnGround = false;
  bool isEnteringDoor = false;

  double _doorAnimTimer = 0.0;
  static const double doorAnimDuration = 0.45;
  VoidCallback? _onDoorEnterComplete;
  Vector2 _doorTargetPos = Vector2.zero();

  double _coyoteTimer = 0.0;
  double _jumpBufferTimer = 0.0;
  int _horizontalDirection = 0; // -1: left, 0: idle, 1: right
  bool _facingLeft = false;
  bool _isInvulnerable = true;
  double _invulnerableTimer = 0.5;

  List<Sprite>? _sprites;
  int _currentFrame = 0;
  double _animTimer = 0.0;

  final RectangleHitbox hitbox;

  Player({Vector2? position})
      : hitbox = RectangleHitbox(
          size: Vector2(20, 36),
          position: Vector2(2, 2),
        ),
        super(
          position: position ?? Vector2(64, 400),
          size: Vector2(24, 38),
          anchor: Anchor.bottomCenter,
        ) {
    add(hitbox);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      final playerImage = await game.images.load('game/player.png');
      _sprites = List.generate(
        5,
        (i) => Sprite(
          playerImage,
          srcPosition: Vector2(i * 40.0, 0),
          srcSize: Vector2(40, 64),
        ),
      );
    } catch (_) {
      // Fallback for headless tests
    }
  }

  void moveLeft() {
    if (isEnteringDoor) return;
    _horizontalDirection = -1;
    _facingLeft = true;
  }

  void moveRight() {
    if (isEnteringDoor) return;
    _horizontalDirection = 1;
    _facingLeft = false;
  }

  void stopMoving() {
    if (isEnteringDoor) return;
    _horizontalDirection = 0;
  }

  void jump() {
    if (isEnteringDoor) return;
    _jumpBufferTimer = jumpBufferDuration;
  }

  void cutJump() {
    if (isEnteringDoor) return;
    if (velocity.y < 0) {
      velocity.y *= 0.45;
    }
  }

  void enterDoor(Vector2 doorPosition, {required VoidCallback onComplete}) {
    if (isEnteringDoor) return;
    isEnteringDoor = true;
    _doorAnimTimer = doorAnimDuration;
    _onDoorEnterComplete = onComplete;
    _doorTargetPos = doorPosition.clone();
    velocity.setZero();
    _horizontalDirection = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isEnteringDoor) {
      _doorAnimTimer -= dt;
      // Step smoothly toward center of doorway
      position.x += (_doorTargetPos.x - position.x) * min(1.0, dt * 14.0);
      position.y = _doorTargetPos.y;

      if (_doorAnimTimer <= 0) {
        isEnteringDoor = false;
        final callback = _onDoorEnterComplete;
        _onDoorEnterComplete = null;
        callback?.call();
      }
      return;
    }

    if (_isInvulnerable) {
      _invulnerableTimer -= dt;
      if (_invulnerableTimer <= 0) {
        _isInvulnerable = false;
      }
    }

    final physicsDt = min(0.05, dt);

    // Horizontal movement
    velocity.x = _horizontalDirection * moveSpeed;

    // Sprite walk animation cycle (frames 1..4 when running, frame 0 when idle)
    if (_horizontalDirection != 0 && isOnGround) {
      _animTimer += physicsDt * 10.0;
      _currentFrame = 1 + (_animTimer.toInt() % 4);
    } else {
      _animTimer = 0.0;
      _currentFrame = 0;
    }

    // Coyote timer
    if (isOnGround) {
      _coyoteTimer = coyoteDuration;
    } else {
      _coyoteTimer = max(0.0, _coyoteTimer - physicsDt);
    }

    // Jump buffer timer
    _jumpBufferTimer = max(0.0, _jumpBufferTimer - physicsDt);

    // Jump execution
    if (_jumpBufferTimer > 0 && _coyoteTimer > 0) {
      velocity.y = jumpVelocity;
      _jumpBufferTimer = 0.0;
      _coyoteTimer = 0.0;
      isOnGround = false;
      game.audio.playSfx('jump.wav');
    }

    // Asymmetric gravity
    final currentGravity = velocity.y > 0 ? fallGravity : riseGravity;
    velocity.y = min(maxFallSpeed, velocity.y + currentGravity * physicsDt);

    // Apply movement
    position.x += velocity.x * physicsDt;
    position.y += velocity.y * physicsDt;

    // Pit fall check (fell off bottom of stage)
    if (position.y > 732) {
      takeDamage();
      respawnAt(game.lastCheckpointPosition);
    } else if (velocity.y != 0) {
      // In air unless confirmed by solid collision
      isOnGround = false;
    }
  }

  void takeDamage() {
    if (_isInvulnerable || isEnteringDoor) return;

    _isInvulnerable = true;
    _invulnerableTimer = 1.0;
    game.onPlayerHurt();
  }

  void respawnAt(Vector2 newPosition) {
    isEnteringDoor = false;
    _doorAnimTimer = 0.0;
    _onDoorEnterComplete = null;
    position = newPosition.clone();
    velocity.setZero();
    _horizontalDirection = 0;
    _coyoteTimer = 0.0;
    _jumpBufferTimer = 0.0;
    isOnGround = false;
    _isInvulnerable = true;
    _invulnerableTimer = 1.2;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.save();

    // Shrink into doorway center when entering door
    if (isEnteringDoor) {
      final progress =
          (1.0 - (_doorAnimTimer / doorAnimDuration)).clamp(0.0, 1.0);
      final scale = (1.0 - progress * 0.8).clamp(0.0, 1.0);
      canvas.translate(size.x / 2, size.y);
      canvas.scale(scale, scale);
      canvas.translate(-size.x / 2, -size.y);
    }

    // Flip horizontally: sprite natively faces left, so flip when facing right
    if (!_facingLeft) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }

    final int alpha = isEnteringDoor
        ? (((_doorAnimTimer / doorAnimDuration)) * 255).clamp(0, 255).toInt()
        : (_isInvulnerable ? 102 : 255);

    final paint = Paint()..color = Color.fromARGB(alpha, 0, 0, 0);

    if (_sprites != null && _sprites!.length > _currentFrame) {
      _sprites![_currentFrame].render(
        canvas,
        size: size,
        overridePaint: paint,
      );
    } else {
      // Minimalist fallback for headless tests
      canvas.drawRRect(
        RRect.fromRectAndRadius(size.toRect(), const Radius.circular(3)),
        paint,
      );
    }

    canvas.restore();
  }
}
