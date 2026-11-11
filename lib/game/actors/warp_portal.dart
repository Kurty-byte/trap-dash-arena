import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/actors/trap_spike.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

class WarpPortal extends PositionComponent
    with CollisionCallbacks, HasGameReference<TrapDashGame> {
  final String trapId;
  Vector2 targetPosition;
  TrapSpike? postWarpSpikeToActivate;
  final String? postWarpSpikeTrapId;
  bool? setControlsInvertedOnWarp;

  // Multi-pass bridge support (Platform 2)
  Vector2? secondTargetPosition;
  bool? secondSetControlsInvertedOnWarp;
  double pass1JumpShiftX;
  double pass2JumpShiftX;
  final double shiftDuration;

  // Fleeing portal support (Platform 2 upper platform)
  Vector2? fleeTargetPosition;
  double fleeSpeed;
  double fleeTriggerX;

  final Vector2 _initialPosition;
  int _useCount = 0;
  int get useCount => _useCount;
  bool _hasShiftedPass1 = false;
  bool _hasShiftedPass2 = false;
  double _cooldown = 0.0;

  double _shiftStartX = 0.0;
  double? _shiftTargetX;
  double _shiftElapsed = 0.0;
  bool get isShifting => _shiftTargetX != null;

  List<Sprite>? _sprites;
  int _currentFrame = 0;
  double _animTimer = 0.0;

  WarpPortal({
    required this.trapId,
    required Vector2 position,
    required this.targetPosition,
    this.postWarpSpikeToActivate,
    this.postWarpSpikeTrapId,
    this.setControlsInvertedOnWarp,
    this.secondTargetPosition,
    this.secondSetControlsInvertedOnWarp,
    this.pass1JumpShiftX = 0.0,
    this.pass2JumpShiftX = 0.0,
    this.shiftDuration = 0.22,
    this.fleeTargetPosition,
    this.fleeSpeed = 480.0,
    this.fleeTriggerX = 1764.0,
    Vector2? size,
  })  : _initialPosition = position.clone(),
        super(
          position: position,
          size: size ?? Vector2(44, 44),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(
      size: size,
      collisionType: CollisionType.passive,
    ));

    try {
      final cachedImg = game.tryGetCachedImage('game/teleport.png');
      if (cachedImg != null) {
        _sprites = [
          Sprite(cachedImg, srcPosition: Vector2(0, 0), srcSize: Vector2(80, 80)),
          Sprite(cachedImg, srcPosition: Vector2(80, 0), srcSize: Vector2(80, 80)),
        ];
      } else {
        final img = await game.images.load('game/teleport.png');
        _sprites = [
          Sprite(img, srcPosition: Vector2(0, 0), srcSize: Vector2(80, 80)),
          Sprite(img, srcPosition: Vector2(80, 0), srcSize: Vector2(80, 80)),
        ];
      }
    } catch (_) {
      // Test environment fallback
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_cooldown > 0) {
      _cooldown -= dt;
    }

    _animTimer += dt;
    if (_animTimer >= 0.18) {
      _animTimer = 0.0;
      _currentFrame = (_currentFrame + 1) % 2;
    }

    try {
      final player = game.player;

      // Pass 1 proximity shift: eases left when player approaches Left Bridge ledge (grounded or airborne)
      if (pass1JumpShiftX != 0.0 && _useCount == 0 && !_hasShiftedPass1) {
        if (player.position.x >= 1620.0 && player.position.x <= 1770.0) {
          _hasShiftedPass1 = true;
          _startHorizontalShift(_initialPosition.x + pass1JumpShiftX);
          game.audio.playSfx('trap_trigger.wav');
          game.shakeCamera(intensity: 4.0, duration: 0.12);
        }
      }

      // Pass 2 proximity shift: eases right when player approaches Right Bridge ledge (grounded or airborne)
      if (pass2JumpShiftX != 0.0 && _useCount == 1 && !_hasShiftedPass2) {
        if (player.position.x >= 1732.0 && player.position.x <= 1880.0) {
          _hasShiftedPass2 = true;
          _startHorizontalShift(
            _initialPosition.x + pass1JumpShiftX + pass2JumpShiftX,
          );
          game.audio.playSfx('trap_trigger.wav');
          game.shakeCamera(intensity: 4.0, duration: 0.12);
        }
      }

      // Advance eased horizontal shift
      if (_shiftTargetX != null) {
        _shiftElapsed += dt;
        if (shiftDuration <= 0.0 || _shiftElapsed >= shiftDuration) {
          position.x = _shiftTargetX!;
          _shiftTargetX = null;
        } else {
          final t = Curves.easeInOutCubic.transform(
            (_shiftElapsed / shiftDuration).clamp(0.0, 1.0),
          );
          position.x = _shiftStartX + (_shiftTargetX! - _shiftStartX) * t;
        }
      }

      // Flee mode: instantaneously moves to the left instead of gliding across the player
      if (fleeTargetPosition != null && position.x != fleeTargetPosition!.x) {
        if (player.position.y <= 380 && player.position.x >= fleeTriggerX) {
          position.setFrom(fleeTargetPosition!);
          game.audio.playSfx('trap_trigger.wav');
          game.shakeCamera(intensity: 5.0, duration: 0.15);
        }
      }
    } catch (_) {
      // Unit tests where player is not yet loaded
    }
  }

  void _startHorizontalShift(double targetX) {
    _shiftStartX = position.x;
    _shiftTargetX = targetX;
    _shiftElapsed = 0.0;
  }

  TrapSpike? resolvePostWarpSpike() {
    if (postWarpSpikeToActivate != null) return postWarpSpikeToActivate;
    if (postWarpSpikeTrapId != null) {
      try {
        for (final s in game.world.children.whereType<TrapSpike>()) {
          if (s.trapId == postWarpSpikeTrapId ||
              s.trapId == 's_$postWarpSpikeTrapId' ||
              (postWarpSpikeTrapId!.startsWith('s_') &&
                  s.trapId == postWarpSpikeTrapId!.substring(2))) {
            postWarpSpikeToActivate = s;
            return s;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (other is Player && _cooldown <= 0) {
      if (other.isInDeathCycle || other.isEnteringDoor) return;

      _cooldown = 0.45;

      final dest = (_useCount >= 1 && secondTargetPosition != null)
          ? secondTargetPosition!
          : targetPosition;

      final invert = (_useCount >= 1 && secondSetControlsInvertedOnWarp != null)
          ? secondSetControlsInvertedOnWarp
          : setControlsInvertedOnWarp;

      other.startWarp(dest, invertControls: invert);

      game.audio.playSfx('trap_trigger.wav');
      game.shakeCamera(intensity: 6.0, duration: 0.18);
      game.controller.onTrapBait(trapId);

      final spike = postWarpSpikeToActivate ?? resolvePostWarpSpike();
      if (spike != null) {
        spike.thrustUp();
      }

      _useCount++;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (_sprites != null && _sprites!.length > _currentFrame) {
      _sprites![_currentFrame].render(canvas, size: size);
    } else {
      // Retro concentric portal visual fallback
      final rect = size.toRect();
      final outerPaint = Paint()
        ..color = AppPalette.brownSolid
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      final innerPaint = Paint()
        ..color = AppPalette.playerBlack
        ..style = PaintingStyle.fill;
      final corePaint = Paint()
        ..color = AppPalette.yellowBackground
        ..style = PaintingStyle.fill;

      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), innerPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), outerPaint);
      canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x * 0.22, corePaint);
    }
  }

  void resetToInitial() {
    position.setFrom(_initialPosition);
    _useCount = 0;
    _hasShiftedPass1 = false;
    _hasShiftedPass2 = false;
    _cooldown = 0.0;
    _shiftStartX = 0.0;
    _shiftTargetX = null;
    _shiftElapsed = 0.0;
  }
}
