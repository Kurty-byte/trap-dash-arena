import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/game/actors/falling_block.dart';
import 'package:trap_dash_arena/game/actors/ground_block.dart';
import 'package:trap_dash_arena/game/actors/player.dart';
import 'package:trap_dash_arena/game/actors/trap_spike.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

enum GauntletChoice { left, right }

class GauntletPortal extends PositionComponent with CollisionCallbacks {
  final GauntletChoice choice;
  final PortalGauntletController controller;
  List<Sprite>? _sprites;
  int _currentFrame = 0;
  double _animTimer = 0.0;

  GauntletPortal({
    required this.choice,
    required this.controller,
    required Vector2 position,
  }) : super(
          position: position,
          size: Vector2(40, 40),
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
      final cachedImg = controller.game.tryGetCachedImage('game/teleport.png');
      if (cachedImg != null) {
        _sprites = [
          Sprite(cachedImg, srcPosition: Vector2(0, 0), srcSize: Vector2(80, 80)),
          Sprite(cachedImg, srcPosition: Vector2(80, 0), srcSize: Vector2(80, 80)),
        ];
      }
    } catch (_) {}
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animTimer += dt;
    if (_animTimer >= 0.18) {
      _animTimer = 0.0;
      _currentFrame = (_currentFrame + 1) % 2;
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      controller.onPortalEntered(choice, this);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_sprites != null && _sprites!.length > _currentFrame) {
      _sprites![_currentFrame].render(canvas, size: size);
    } else {
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
}

class PortalGauntletController extends Component with HasGameReference<TrapDashGame> {
  static const List<GauntletChoice> safePattern = [
    GauntletChoice.left,
    GauntletChoice.right,
    GauntletChoice.right,
    GauntletChoice.left,
    GauntletChoice.right,
  ];
  static const double stepStrideX = 144.0;
  static const double leftDodgeDuration = 0.18;

  int step = 0; // 0: boarding, 1..5: choices, 6: gauntlet cleared
  int activeWrongChoice = 0; // 0: none, 1..5: active wrong-choice hazard
  double _cooldown = 0.0;

  // Moving Compact Square Box Platform (56x56)
  final Vector2 mainBoxInitialPos = Vector2(2780, 400);
  late final GroundBlock mainBox;
  double mainBoxTargetX = 2780.0;

  // Paired Under-Box Portals
  late final GauntletPortal leftPortal;
  late final GauntletPortal rightPortal;
  double _leftPortalDodgeX = 0.0;
  bool _isLeftPortalDodging = false;
  double _leftDodgeElapsed = 0.0;
  double _portalsDropY = 0.0;
  bool _portalsDropping = false;

  // Isolated Square Platform & Hazards (hidden until Wrong Choice 3)
  final Vector2 isolatedBoxInitialPos = Vector2(3180, 250);
  late final GroundBlock isolatedBox;
  late final TrapSpike isolatedDelayedSpike;
  double _isolatedDelayTimer = 0.0;

  // Wrong Choice 1: Door Spike on Exit Ledge (hidden until Wrong Choice 1)
  late final TrapSpike doorTrapSpike;

  // Wrong Choice 4: Ceiling Crush Block (hidden until Wrong Choice 4)
  late final FallingBlock crushBlock;

  // Wrong Choice 5: Rectangular Platform & Rushing Spikes (hidden until Wrong Choice 5)
  final Vector2 step5PlatformPos = Vector2(3100, 240);
  late final GroundBlock step5Platform;
  late final TrapSpike rideSpike1;
  late final TrapSpike rideSpike2;
  bool _step5SpikesRushing = false;

  PortalGauntletController() : super(priority: 5) {
    mainBox = GroundBlock(
      position: mainBoxInitialPos.clone(),
      size: Vector2(56, 56),
    );
    leftPortal = GauntletPortal(
      choice: GauntletChoice.left,
      controller: this,
      position: Vector2(mainBox.position.x - 12, mainBox.position.y + 110),
    );
    rightPortal = GauntletPortal(
      choice: GauntletChoice.right,
      controller: this,
      position: Vector2(mainBox.position.x + 68, mainBox.position.y + 110),
    );
    isolatedBox = GroundBlock(
      position: isolatedBoxInitialPos.clone(),
      size: Vector2(56, 56),
      isActive: false,
    );
    isolatedDelayedSpike = TrapSpike(
      trapId: 'l4_p3_isolated_spike',
      position: Vector2(isolatedBoxInitialPos.x + 28, isolatedBoxInitialPos.y),
      behavior: SpikeBehavior.proximityPopUp,
      hideCompletelyWhenIdle: true,
      triggerDistance: 0.0,
      isActive: false,
    );
    doorTrapSpike = TrapSpike(
      trapId: 'l4_p3_door_spike',
      position: Vector2(3580, 400),
      behavior: SpikeBehavior.proximityPopUp,
      hideCompletelyWhenIdle: true,
      triggerDistance: 0.0,
      isActive: false,
    );
    crushBlock = FallingBlock(
      trapId: 'l4_p3_crush_block',
      position: Vector2(mainBoxInitialPos.x - 4, 104),
      groundY: mainBoxInitialPos.y,
      size: Vector2(64, 48),
      manualTriggerOnly: true,
      shouldHoldFall: () {
        try {
          return game.player.isWarping;
        } catch (_) {
          return false;
        }
      },
    );
    step5Platform = GroundBlock(
      position: step5PlatformPos.clone(),
      size: Vector2(280, 32),
      isActive: false,
    );
    rideSpike1 = TrapSpike(
      trapId: 'l4_p3_ride_spike_1',
      position: Vector2(3300, 240),
      behavior: SpikeBehavior.proximityPopUp,
      hideCompletelyWhenIdle: true,
      triggerDistance: 0.0,
      isActive: false,
    );
    rideSpike2 = TrapSpike(
      trapId: 'l4_p3_ride_spike_2',
      position: Vector2(3348, 240),
      behavior: SpikeBehavior.proximityPopUp,
      hideCompletelyWhenIdle: true,
      triggerDistance: 0.0,
      isActive: false,
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    add(mainBox);
    add(leftPortal);
    add(rightPortal);
    add(isolatedBox);
    add(isolatedDelayedSpike);
    add(doorTrapSpike);
    add(crushBlock);
    add(step5Platform);
    add(rideSpike1);
    add(rideSpike2);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_cooldown > 0) {
      _cooldown -= dt;
    }

    try {
      final player = game.player;

      // Smoothly glide mainBox toward target X
      if (mainBox.position.x < mainBoxTargetX) {
        final diff = mainBoxTargetX - mainBox.position.x;
        final moveDx = min(diff, 220.0 * dt);

        // Check if player is standing on the platform before advancing mainBox position
        final isStandingOnPlatform = player.velocity.y >= 0 &&
            (player.position.y - mainBox.position.y).abs() <= 16.0 &&
            player.position.x >= mainBox.position.x - 16.0 &&
            player.position.x <= mainBox.position.x + mainBox.size.x + 16.0;

        mainBox.position.x += moveDx;

        if (isStandingOnPlatform) {
          player.position.x += moveDx;
          player.position.y = mainBox.position.y;
          player.velocity.setZero();
          player.isOnGround = true;
        }
      }

      // Step 2 Wrong Trap: If player falls towards Left Portal, portal dodges away into void!
      if (step == 2) {
        if (!player.isOnGround &&
            player.position.y > mainBox.position.y &&
            player.position.x < mainBox.position.x + 28.0) {
          activeWrongChoice = 2;
          if (!_isLeftPortalDodging) {
            _isLeftPortalDodging = true;
            _leftDodgeElapsed = 0.0;
            game.audio.playSfx('trap_trigger.wav');
          }
        }
      } else {
        // Left portal returns to under-box position on all other steps
        _leftPortalDodgeX = 0.0;
        _isLeftPortalDodging = false;
        _leftDodgeElapsed = 0.0;
      }

      if (_isLeftPortalDodging) {
        _leftDodgeElapsed += dt;
        final t = Curves.easeOutCubic.transform(
          (_leftDodgeElapsed / leftDodgeDuration).clamp(0.0, 1.0),
        );
        _leftPortalDodgeX = -240.0 * t;
      }

      // Portals drop into the void (Step 4 wrong)
      if (_portalsDropping) {
        _portalsDropY += 360.0 * dt;
      }

      // Keep portals aligned beneath mainBox
      _updatePortalPositions();

      // Delayed spike timer on isolated platform (Step 3 wrong)
      if (_isolatedDelayTimer > 0) {
        _isolatedDelayTimer -= dt;
        if (_isolatedDelayTimer <= 0) {
          isolatedDelayedSpike.thrustUp();
          game.audio.playSfx('trap_trigger.wav');
          game.shakeCamera(intensity: 8.0, duration: 0.20);
        }
      }

      // Rushing spikes on step 5 rectangular platform
      if (_step5SpikesRushing && !player.isWarping) {
        final moveDx = 420.0 * dt;
        rideSpike1.position.x -= moveDx;
        rideSpike2.position.x -= moveDx;
        if (rideSpike1.position.x <= 3116.0) {
          _step5SpikesRushing = false;
        }
      }
    } catch (_) {}
  }

  void _updatePortalPositions() {
    leftPortal.position.setValues(
      mainBox.position.x - 12 + _leftPortalDodgeX,
      mainBox.position.y + 110 + _portalsDropY,
    );
    rightPortal.position.setValues(
      mainBox.position.x + 68,
      mainBox.position.y + 110 + _portalsDropY,
    );
  }

  void onPortalEntered(GauntletChoice choice, GauntletPortal portal) {
    if (_cooldown > 0) return;

    try {
      final player = game.player;
      if (player.isInDeathCycle || player.isEnteringDoor) return;

      _cooldown = 0.50;

      // Step 0: Boarding from Passage 2 via Left Portal
      if (step == 0) {
        if (choice == GauntletChoice.left) {
          step = 1;
          _leftPortalDodgeX = 0.0;
          _isLeftPortalDodging = false;
          _leftDodgeElapsed = 0.0;
          activeWrongChoice = 0;
          player.startWarp(
            Vector2(mainBox.position.x + 28.0, mainBox.position.y),
            landOnGround: true,
          );
          game.audio.playSfx('trap_trigger.wav');
          game.shakeCamera(intensity: 5.0, duration: 0.15);
          game.controller.onTrapBait('l4_p3_board');
        }
        return;
      }

      // Steps 1..5: Trial sequence
      if (step >= 1 && step <= 5) {
        final expected = safePattern[step - 1];

        if (choice == expected) {
          // CORRECT CHOICE!
          step++;
          _leftPortalDodgeX = 0.0;
          _isLeftPortalDodging = false;
          _leftDodgeElapsed = 0.0;
          activeWrongChoice = 0;
          _updatePortalPositions();
          player.startWarp(
            Vector2(mainBox.position.x + 28.0, mainBox.position.y),
            landOnGround: true,
          );
          mainBoxTargetX = mainBoxInitialPos.x + (step - 1) * stepStrideX;
          game.audio.playSfx('trap_trigger.wav');
          game.shakeCamera(intensity: 5.0, duration: 0.15);
          game.controller.onTrapBait('l4_p3_step_$step');
        } else {
          // WRONG CHOICE DECEPTIVE DEATHS
          _handleWrongChoice(step, player);
        }
      }
    } catch (_) {}
  }

  void _handleWrongChoice(int currentStep, Player player) {
    activeWrongChoice = currentStep;
    switch (currentStep) {
      case 1:
        // Wrong 1: Reveal spike beside exit door on Exit Ledge and teleport player onto it!
        doorTrapSpike.isActive = true;
        doorTrapSpike.thrustUp();
        player.startWarp(Vector2(3580.0, 400.0));
        game.audio.playSfx('trap_trigger.wav');
        game.shakeCamera(intensity: 8.0, duration: 0.25);
        break;

      case 2:
        // Wrong 2: Left portal dodges away and player falls into void pit!
        _isLeftPortalDodging = true;
        _leftDodgeElapsed = 0.0;
        _leftPortalDodgeX = -240.0;
        player.takeDamage(ignoreInvulnerability: true, isPitFall: true);
        break;

      case 3:
        // Wrong 3: Reveal isolated box & delayed spike; 0.45s later spike pops!
        isolatedBox.isActive = true;
        isolatedDelayedSpike.isActive = true;
        player.startWarp(
          Vector2(isolatedBox.position.x + 28.0, isolatedBox.position.y),
          landOnGround: true,
        );
        _isolatedDelayTimer = 0.45;
        game.audio.playSfx('trap_trigger.wav');
        game.shakeCamera(intensity: 6.0, duration: 0.18);
        break;

      case 4:
        // Wrong 4: Teleport back to mainBox; reveal & drop ceiling crush block and plunge portals down!
        player.startWarp(
          Vector2(mainBox.position.x + 28.0, mainBox.position.y),
          landOnGround: true,
        );
        crushBlock.position.setValues(mainBox.position.x - 4.0, 104.0);
        crushBlock.triggerFall();
        _portalsDropping = true;
        game.audio.playSfx('trap_trigger.wav');
        game.shakeCamera(intensity: 10.0, duration: 0.30);
        break;

      case 5:
        // Wrong 5: Reveal rectangular platform & 2 spikes rushing left at player
        step5Platform.isActive = true;
        rideSpike1.position.setValues(3300.0, 240.0);
        rideSpike1.isActive = true;
        rideSpike1.thrustUp();
        rideSpike2.position.setValues(3348.0, 240.0);
        rideSpike2.isActive = true;
        rideSpike2.thrustUp();
        player.startWarp(
          Vector2(3148.0, 240.0),
          landOnGround: true,
        );
        _step5SpikesRushing = true;
        game.audio.playSfx('trap_trigger.wav');
        game.shakeCamera(intensity: 6.0, duration: 0.18);
        break;
    }
  }

  void resetToInitial() {
    step = 0;
    activeWrongChoice = 0;
    _cooldown = 0.0;
    mainBox.position.setFrom(mainBoxInitialPos);
    mainBoxTargetX = mainBoxInitialPos.x;

    _leftPortalDodgeX = 0.0;
    _isLeftPortalDodging = false;
    _leftDodgeElapsed = 0.0;
    _portalsDropY = 0.0;
    _portalsDropping = false;
    _updatePortalPositions();

    isolatedBox.position.setFrom(isolatedBoxInitialPos);
    isolatedBox.isActive = false;
    isolatedDelayedSpike.position.setValues(isolatedBoxInitialPos.x + 28, isolatedBoxInitialPos.y);
    isolatedDelayedSpike.retract();
    isolatedDelayedSpike.isActive = false;
    _isolatedDelayTimer = 0.0;

    doorTrapSpike.retract();
    doorTrapSpike.isActive = false;
    crushBlock.resetToCeiling();

    step5Platform.isActive = false;
    _step5SpikesRushing = false;
    rideSpike1.position.setValues(3300.0, 240.0);
    rideSpike1.retract();
    rideSpike1.isActive = false;
    rideSpike2.position.setValues(3348.0, 240.0);
    rideSpike2.retract();
    rideSpike2.isActive = false;
  }
}
