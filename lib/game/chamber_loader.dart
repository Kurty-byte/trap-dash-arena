import 'dart:io';
import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/foundation.dart';
import 'package:trap_dash_arena/game/actors/chamber_background.dart';
import 'package:trap_dash_arena/game/actors/checkpoint_flag.dart';
import 'package:trap_dash_arena/game/actors/control_inverter_zone.dart';
import 'package:trap_dash_arena/game/actors/disappearing_platform.dart';
import 'package:trap_dash_arena/game/actors/exit_portal.dart';
import 'package:trap_dash_arena/game/actors/fake_floor.dart';
import 'package:trap_dash_arena/game/actors/falling_block.dart';
import 'package:trap_dash_arena/game/actors/ground_block.dart';
import 'package:trap_dash_arena/game/actors/hint_arrow.dart';
import 'package:trap_dash_arena/game/actors/moving_gap_floor.dart';
import 'package:trap_dash_arena/game/actors/moving_saw.dart';
import 'package:trap_dash_arena/game/actors/pickup_item.dart';
import 'package:trap_dash_arena/game/actors/portal_gauntlet_controller.dart';
import 'package:trap_dash_arena/game/actors/reverse_spring.dart';
import 'package:trap_dash_arena/game/actors/sudden_gap.dart';
import 'package:trap_dash_arena/game/actors/trap_spike.dart';
import 'package:trap_dash_arena/game/actors/warp_portal.dart';
import 'package:trap_dash_arena/game/level_config.dart';
import 'package:trap_dash_arena/game/trap_dash_game.dart';

class ChamberLoadResult {
  final Vector2 spawnPosition;
  final double exitX;

  const ChamberLoadResult({
    required this.spawnPosition,
    required this.exitX,
  });
}

class ChamberLoader {
  static final Map<String, RenderableTiledMap> _tmxCache = {};

  static void clearCache() {
    _tmxCache.clear();
  }

  static bool hasCached(String tmxFile) => _tmxCache.containsKey(tmxFile);

  static Future<ChamberLoadResult> loadIntoWorld(
    TrapDashGame game,
    LevelConfig config,
  ) async {
    // 0. Render yellow room background strictly inside room corridors and passages
    game.world.add(ChamberBackground(roomCount: config.roomCount));

    // 1. Always spawn outer solid enclosure walls with 3000px bleed margins
    _spawnPerimeterShell(game.world, roomCount: config.roomCount);

    // In unit/widget tests, use fast programmatic chamber directly to avoid asset bundle timeouts
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return _loadProgrammaticChamber(game, config.levelNumber);
    }

    // 2. Try loading from cached or fresh Tiled map, fall back to programmatic chamber
    try {
      RenderableTiledMap? map = _tmxCache[config.tmxFile];
      if (map == null) {
        map = await RenderableTiledMap.fromFile(
          config.tmxFile,
          Vector2.all(32),
        );
        _tmxCache[config.tmxFile] = map;
      }
      final tiled = TiledComponent(map);
      final result = loadFromTiled(game, tiled);
      if (result != null) return result;
    } catch (_) {
      // In headless test environments or asset bundle fallbacks
      game.world.removeAll(game.world.children);
      game.world.add(ChamberBackground(roomCount: config.roomCount));
      _spawnPerimeterShell(game.world, roomCount: config.roomCount);
    }

    return _loadProgrammaticChamber(game, config.levelNumber);
  }

  static void _spawnPerimeterShell(World world, {int roomCount = 1}) {
    // Left outer wall (inner edge at x = 96, extends 3000px left and 3000px up/down)
    world.add(GroundBlock(
      position: Vector2(-3000, -3000),
      size: Vector2(3096, 6720),
    ));

    // Right outer wall (inner edge at x = roomCount * 1280 - 96, extends 3000px right)
    final rightWallX = roomCount * 1280.0 - 96.0;
    world.add(GroundBlock(
      position: Vector2(rightWallX, -3000),
      size: Vector2(3096, 6720),
    ));

    // Top ceiling wall (inner edge at y = 104, extends 3000px up)
    final ceilingW = roomCount * 1280.0 + 6000.0;
    world.add(GroundBlock(
      position: Vector2(-3000, -3000),
      size: Vector2(ceilingW, 3104),
    ));

    // Deep sub-floor base below pit depth (y: 780..3780)
    world.add(GroundBlock(
      position: Vector2(-3000, 780),
      size: Vector2(ceilingW, 3000),
    ));
  }

  static ChamberLoadResult? loadFromTiled(
    TrapDashGame game,
    TiledComponent tiled,
  ) {
    final wallsGroup = tiled.tileMap.getLayer<ObjectGroup>('Walls');
    final objectsGroup = tiled.tileMap.getLayer<ObjectGroup>('Objects');

    if (wallsGroup == null && objectsGroup == null) return null;

    if (wallsGroup != null) {
      for (final obj in wallsGroup.objects) {
        game.world.add(GroundBlock(
          position: Vector2(obj.x, obj.y),
          size: Vector2(obj.width, obj.height),
        ));
      }
    }

    Vector2? spawn;
    double exitX = 1128.0;

    if (objectsGroup != null) {
      for (final obj in objectsGroup.objects) {
        final pos = Vector2(obj.x, obj.y);
        final size = Vector2(obj.width, obj.height);

        switch (obj.name) {
          case 'Spawn':
            spawn = pos;
            break;
          case 'StaticSpike':
            game.world.add(TrapSpike(
              trapId: 's_${obj.id}',
              position: pos,
              isStatic: true,
            ));
            break;
          case 'TrapSpike':
            final behStr = obj.properties.getValue<String>('behavior');
            SpikeBehavior? beh;
            if (behStr != null) {
              switch (behStr) {
                case 'stationary':
                  beh = SpikeBehavior.stationary;
                  break;
                case 'proximityPopUp':
                  beh = SpikeBehavior.proximityPopUp;
                  break;
                case 'slideRightOnJump':
                  beh = SpikeBehavior.slideRightOnJump;
                  break;
                case 'riseOnProximity':
                  beh = SpikeBehavior.riseOnProximity;
                  break;
                case 'doubleSlideTrap':
                  beh = SpikeBehavior.doubleSlideTrap;
                  break;
                case 'remotePopUp':
                  beh = SpikeBehavior.remotePopUp;
                  break;
                case 'oscillateTwice':
                  beh = SpikeBehavior.oscillateTwice;
                  break;
              }
            }
            final isStat = obj.properties.getValue<bool>('isStatic') ?? false;
            final trigDist = obj.properties.getValue<double>('triggerDistance') ?? 48.0;
            final jitDur = obj.properties.getValue<double>('jitterDuration') ?? 0.30;
            final hideIdle = obj.properties.getValue<bool>('hideCompletelyWhenIdle') ?? false;
            final slideRight = obj.properties.getValue<double>('slideRightDistance') ?? 96.0;
            final slideLeft = obj.properties.getValue<double>('slideLeftDistance') ?? 80.0;
            final slideSpd = obj.properties.getValue<double>('slideSpeed') ?? 460.0;
            final retSlideSpd = obj.properties.getValue<double>('returnSlideSpeed') ?? 480.0;
            final riseH = obj.properties.getValue<double>('riseHeight') ?? 88.0;
            final riseSpd = obj.properties.getValue<double>('riseSpeed') ?? 680.0;
            final remoteX = obj.properties.getValue<double>('remoteTriggerX') ?? 0.0;
            final remoteMaxX = obj.properties.getValue<double>('remoteTriggerMaxX') ?? double.infinity;
            final remoteMaxY = obj.properties.getValue<double>('remoteTriggerMaxY') ?? double.infinity;
            final remoteGrounded = obj.properties.getValue<bool>('remoteRequireGrounded') ?? false;
            game.world.add(TrapSpike(
              trapId: 's_${obj.id}',
              position: pos,
              isStatic: isStat,
              behavior: beh,
              triggerDistance: trigDist,
              jitterDuration: jitDur,
              hideCompletelyWhenIdle: hideIdle,
              slideRightDistance: slideRight,
              slideLeftDistance: slideLeft,
              slideSpeed: slideSpd,
              returnSlideSpeed: retSlideSpd,
              riseHeight: riseH,
              riseSpeed: riseSpd,
              remoteTriggerX: remoteX,
              remoteTriggerMaxX: remoteMaxX,
              remoteTriggerMaxY: remoteMaxY,
              remoteRequireGrounded: remoteGrounded,
            ));
            break;
          case 'ControlInverterZone':
            final targetInv = obj.properties.getValue<bool>('targetInverted') ?? true;
            final reqGrounded = obj.properties.getValue<bool>('requireGrounded') ?? false;
            final fullHeight = obj.properties.getValue<bool>('triggerFullHeight');
            game.world.add(ControlInverterZone(
              trapId: 'ciz_${obj.id}',
              position: pos,
              size: size,
              targetInverted: targetInv,
              requireGrounded: reqGrounded,
              triggerFullHeight: fullHeight,
            ));
            break;
          case 'FakeFloor':
            game.world.add(FakeFloor(
              trapId: 'f_${obj.id}',
              position: pos,
              size: size,
            ));
            break;
          case 'FallingBlock':
            final groundY = obj.properties.getValue<double>('groundY') ?? 552.0;
            game.world.add(FallingBlock(
              trapId: 'fb_${obj.id}',
              position: pos,
              groundY: groundY,
              size: size,
            ));
            break;
          case 'MovingSaw':
            final endX = obj.properties.getValue<double>('endX') ?? pos.x + 80;
            final endY = obj.properties.getValue<double>('endY') ?? pos.y;
            final speed = obj.properties.getValue<double>('speed') ?? 100.0;
            game.world.add(MovingSaw(
              pathStart: pos,
              pathEnd: Vector2(endX, endY),
              speed: speed,
            ));
            break;
          case 'DisappearingPlatform':
            game.world.add(DisappearingPlatform(
              position: pos,
              size: size,
            ));
            break;
          case 'ReverseSpring':
            game.world.add(ReverseSpring(
              trapId: 'rs_${obj.id}',
              position: pos,
            ));
            break;
          case 'Checkpoint':
            final cid = obj.properties.getValue<int>('checkpointId') ?? 1;
            game.world.add(CheckpointFlag(
              checkpointId: cid,
              position: pos,
            ));
            break;
          case 'Coin':
            game.world.add(PickupItem(
              type: PickupType.coin,
              position: pos,
            ));
            break;
          case 'Key':
            game.world.add(PickupItem(
              type: PickupType.key,
              position: pos,
            ));
            break;
          case 'HintArrow':
            game.world.add(HintArrow(position: pos));
            break;
          case 'SuddenGap':
            final lead = obj.properties.getValue<double>('triggerLeadPx') ?? 46.0;
            game.world.add(SuddenGap(
              trapId: 'sg_${obj.id}',
              position: pos,
              size: size,
              triggerLeadPx: lead,
            ));
            break;
          case 'MovingGapFloor':
            final modeStr = obj.properties.getValue<String>('mode') ?? 'chase';
            final mode = modeStr == 'hesitation'
                ? MovingGapMode.hesitation
                : MovingGapMode.chase;
            final gapW = obj.properties.getValue<double>('gapWidth') ?? 88.0;
            final triggerX = obj.properties.getValue<double>('triggerPlayerX') ?? 0.0;
            final chaseStartX = obj.properties.getValue<double>('chaseStartPlayerX') ?? 0.0;
            final speed = obj.properties.getValue<double>('chaseSpeed') ?? 205.0;
            final stopX = obj.properties.getValue<double>('stopGapX') ?? 512.0;
            final actRoomX = obj.properties.getValue<double>('activateRoomX') ?? 0.0;
            final initGapX = obj.properties.getValue<double>('initialGapLocalX') ?? 300.0;
            final anchorGapX = obj.properties.getValue<double>('anchorGapLocalX') ?? 420.0;
            final proxRange = obj.properties.getValue<double>('proximityRangePx') ?? 140.0;
            final punishSpd = obj.properties.getValue<double>('punishSpeed') ?? 950.0;
            game.world.add(MovingGapFloor(
              trapId: 'mgf_${obj.id}',
              position: pos,
              size: size,
              mode: mode,
              gapWidth: gapW,
              triggerPlayerX: triggerX,
              chaseStartPlayerX: chaseStartX,
              chaseSpeed: speed,
              stopGapX: stopX,
              activateRoomX: actRoomX,
              initialGapLocalX: initGapX,
              anchorGapLocalX: anchorGapX,
              proximityRangePx: proxRange,
              punishSpeed: punishSpd,
            ));
            break;
          case 'ExitPortal':
            exitX = pos.x;
            final isFake = obj.properties.getValue<bool>('isFakeFirst') ?? false;
            final realX = obj.properties.getValue<double>('realX');
            final realY = obj.properties.getValue<double>('realY');
            Vector2? realTarget;
            if (realX != null && realY != null) {
              realTarget = Vector2(realX, realY);
              exitX = realX;
            }
            game.world.add(ExitPortal(
              position: pos,
              isFakeFirst: isFake,
              realTargetPosition: realTarget,
            ));
            break;
          case 'WarpPortal':
            final targetX = obj.properties.getValue<double>('targetX') ?? pos.x;
            final targetY = obj.properties.getValue<double>('targetY') ?? pos.y;
            final invert = obj.properties.getValue<bool>('setControlsInverted');
            final secTargetX = obj.properties.getValue<double>('secondTargetX');
            final secTargetY = obj.properties.getValue<double>('secondTargetY');
            final secInvert = obj.properties.getValue<bool>('secondSetControlsInverted');
            final pass1Shift = obj.properties.getValue<double>('pass1JumpShiftX') ?? 0.0;
            final pass2Shift = obj.properties.getValue<double>('pass2JumpShiftX') ?? 0.0;
            final fleeX = obj.properties.getValue<double>('fleeTargetX');
            final fleeY = obj.properties.getValue<double>('fleeTargetY');
            final fleeSpd = obj.properties.getValue<double>('fleeSpeed') ?? 480.0;
            final fleeTrigX = obj.properties.getValue<double>('fleeTriggerX') ?? 1764.0;
            game.world.add(WarpPortal(
              trapId: 'wp_${obj.id}',
              position: pos,
              targetPosition: Vector2(targetX, targetY),
              setControlsInvertedOnWarp: invert,
              secondTargetPosition: secTargetX != null && secTargetY != null ? Vector2(secTargetX, secTargetY) : null,
              secondSetControlsInvertedOnWarp: secInvert,
              pass1JumpShiftX: pass1Shift,
              pass2JumpShiftX: pass2Shift,
              fleeTargetPosition: fleeX != null && fleeY != null ? Vector2(fleeX, fleeY) : null,
              fleeSpeed: fleeSpd,
              fleeTriggerX: fleeTrigX,
            ));
            break;
          case 'PortalGauntletController':
            game.world.add(PortalGauntletController());
            break;
        }
      }
    }

    if (spawn != null) {
      return ChamberLoadResult(spawnPosition: spawn, exitX: exitX);
    }
    return null;
  }

  static ChamberLoadResult _loadProgrammaticChamber(
    TrapDashGame game,
    int level,
  ) {
    switch (level) {
      case 1:
        return _buildLevel1(game);
      case 2:
        return _buildLevel2(game);
      case 3:
        return _buildLevel3(game);
      case 4:
        return _buildLevel4(game);
      case 5:
        return _buildLevel5(game);
      default:
        return _buildLevel1(game);
    }
  }

  static ChamberLoadResult _buildLevel1(TrapDashGame game) {
    final w = game.world;

    // Partition upper wall roofs between rooms leaving 96px high passage tunnels (y: 456..552)
    w.add(GroundBlock(position: Vector2(1184, 104), size: Vector2(192, 352)));
    w.add(GroundBlock(position: Vector2(2464, 104), size: Vector2(192, 352)));

    // Room 1 / Platform 1 (x: 96..1184) + Passage 1 (x: 1184..1376)
    // Starting floor slab
    w.add(GroundBlock(position: Vector2(96, 552), size: Vector2(480, 200)));
    // Platform 1: Sudden gap
    w.add(SuddenGap(
      trapId: 'l1_p1_gap1',
      position: Vector2(576, 552),
      size: Vector2(92, 200),
      triggerLeadPx: 46.0,
    ));
    // Landing floor extending into Passage 1 and up to Room 2 first gap
    w.add(GroundBlock(position: Vector2(668, 552), size: Vector2(892, 200)));
    // Passage 1: Checkpoint 1
    w.add(CheckpointFlag(checkpointId: 1, position: Vector2(1312, 552)));

    // Room 2 / Platform 2 (x: 1376..2464) + Passage 2 (x: 2464..2656)
    // Deceptive sudden gap 2A
    w.add(SuddenGap(
      trapId: 'l1_p2_gap1',
      position: Vector2(1560, 552),
      size: Vector2(88, 200),
      triggerLeadPx: 44.0,
    ));
    // Stepping island
    w.add(GroundBlock(position: Vector2(1648, 552), size: Vector2(104, 200)));
    // Deceptive sudden gap 2B
    w.add(SuddenGap(
      trapId: 'l1_p2_gap2',
      position: Vector2(1752, 552),
      size: Vector2(88, 200),
      triggerLeadPx: 44.0,
    ));
    // Chasing gap floor
    w.add(MovingGapFloor(
      trapId: 'l1_p2_chase',
      position: Vector2(1840, 552),
      size: Vector2(624, 200),
      mode: MovingGapMode.chase,
      gapWidth: 88.0,
      triggerPlayerX: 1888.0,
      chaseSpeed: 205.0,
      stopGapX: 512.0,
    ));
    // Floor bridging into Passage 2 and Platform 3 entry safe zone
    w.add(GroundBlock(position: Vector2(2464, 552), size: Vector2(296, 200)));
    // Passage 2: Checkpoint 2
    w.add(CheckpointFlag(checkpointId: 2, position: Vector2(2592, 552)));

    // Room 3 / Platform 3 (x: 2656..3744)
    // Proximity hesitation anti-second-guessing gap floor
    w.add(MovingGapFloor(
      trapId: 'l1_p3_hesitation',
      position: Vector2(2760, 552),
      size: Vector2(824, 200),
      mode: MovingGapMode.hesitation,
      gapWidth: 92.0,
      activateRoomX: 2560.0,
      initialGapLocalX: 300.0,
      anchorGapLocalX: 420.0,
      proximityRangePx: 140.0,
    ));
    // Final exit landing slab
    w.add(GroundBlock(position: Vector2(3584, 552), size: Vector2(160, 200)));
    // Exit Portal door
    w.add(ExitPortal(position: Vector2(3688, 552)));

    return ChamberLoadResult(
      spawnPosition: Vector2(148, 552),
      exitX: 3688.0,
    );
  }

  static ChamberLoadResult _buildLevel2(TrapDashGame game) {
    final w = game.world;

    // Partition upper wall roofs between rooms leaving 96px high passage tunnels (y: 456..552)
    w.add(GroundBlock(position: Vector2(1184, 104), size: Vector2(192, 352)));
    w.add(GroundBlock(position: Vector2(2464, 104), size: Vector2(192, 352)));

    // Room 1 / Platform 1 (x: 96..1184) + Passage 1 (x: 1184..1376)
    // Starting floor runway
    w.add(GroundBlock(position: Vector2(96, 552), size: Vector2(368, 200)));
    // Stationary spike 1
    w.add(TrapSpike(
      trapId: 'l2_p1_stat_spike',
      position: Vector2(332, 552),
      isStatic: true,
      behavior: SpikeBehavior.stationary,
    ));
    // Platform 1: Proximity open gap that starts chasing right only after player crosses (x >= 568)
    w.add(MovingGapFloor(
      trapId: 'l2_p1_chase_gap',
      position: Vector2(464, 552),
      size: Vector2(720, 200),
      mode: MovingGapMode.chase,
      gapWidth: 88.0,
      triggerPlayerX: 418.0,
      chaseStartPlayerX: 568.0,
      chaseSpeed: 215.0,
      stopGapX: 624.0,
    ));

    // Continuous solid floor bridging Passage 1, all of Platform 2, Passage 2, and Platform 3 entry
    w.add(GroundBlock(position: Vector2(1184, 552), size: Vector2(1816, 200)));
    // Passage 1: Checkpoint 1
    w.add(CheckpointFlag(checkpointId: 1, position: Vector2(1312, 552)));

    // Room 2 / Platform 2 (x: 1376..2464, Zero Gaps)
    // Spike 2A: Slide right on jump to trap forward landing
    w.add(TrapSpike(
      trapId: 'l2_p2_slide_spike',
      position: Vector2(1780, 552),
      behavior: SpikeBehavior.slideRightOnJump,
      slideRightDistance: 96.0,
      slideSpeed: 460.0,
    ));
    // Spike 2B: Close-trigger flush pop-up spike right next to Passage 2
    w.add(TrapSpike(
      trapId: 'l2_p2_popup_spike',
      position: Vector2(2376, 552),
      behavior: SpikeBehavior.proximityPopUp,
      triggerDistance: 36.0,
      jitterDuration: 0.08,
      hideCompletelyWhenIdle: true,
    ));
    // Passage 2: Checkpoint 2
    w.add(CheckpointFlag(checkpointId: 2, position: Vector2(2592, 552)));

    // Room 3 / Platform 3 (x: 2656..3744)
    // Spike 3A: Rising anti-jump spike (launches up to catch jumpers, walk underneath!)
    w.add(TrapSpike(
      trapId: 'l2_p3_rise_spike',
      position: Vector2(2864, 552),
      behavior: SpikeBehavior.riseOnProximity,
      triggerDistance: 76.0,
      riseHeight: 88.0,
      riseSpeed: 680.0,
    ));
    // Platform 3: Hesitation gap
    w.add(MovingGapFloor(
      trapId: 'l2_p3_hesitation_gap',
      position: Vector2(3000, 552),
      size: Vector2(360, 200),
      mode: MovingGapMode.hesitation,
      gapWidth: 88.0,
      activateRoomX: 2560.0,
      initialGapLocalX: 180.0,
      anchorGapLocalX: 180.0,
      proximityRangePx: 120.0,
    ));
    // Platform 3: Exit landing floor
    w.add(GroundBlock(position: Vector2(3360, 552), size: Vector2(384, 200)));
    // Spike 3B: Double-slide boomerang spike (slides right on approach, then slides back left after player lands)
    w.add(TrapSpike(
      trapId: 'l2_p3_double_spike',
      position: Vector2(3484, 552),
      behavior: SpikeBehavior.doubleSlideTrap,
      triggerDistance: 56.0,
      slideRightDistance: 96.0,
      slideLeftDistance: 80.0,
      slideSpeed: 460.0,
      returnSlideSpeed: 480.0,
    ));
    // Exit Portal door
    w.add(ExitPortal(position: Vector2(3688, 552)));

    return ChamberLoadResult(
      spawnPosition: Vector2(148, 552),
      exitX: 3688.0,
    );
  }

  static ChamberLoadResult _buildLevel3(TrapDashGame game) {
    final w = game.world;

    // Partition upper wall roofs between rooms leaving 96px high passage tunnels (y: 456..552)
    w.add(GroundBlock(position: Vector2(1184, 104), size: Vector2(192, 352)));
    w.add(GroundBlock(position: Vector2(2464, 104), size: Vector2(192, 352)));

    // Passage checkpoints
    w.add(CheckpointFlag(checkpointId: 1, position: Vector2(1312, 552)));
    w.add(CheckpointFlag(checkpointId: 2, position: Vector2(2592, 552)));

    // ==========================================
    // Room 1 / Platform 1 (x: 96..1184)
    // ==========================================
    // Starting floor runway (x: 96..340)
    w.add(GroundBlock(position: Vector2(96, 552), size: Vector2(244, 200)));

    // Walk Inverter 0: mid-walk trigger inverts controls before Gap 1
    w.add(ControlInverterZone(
      trapId: 'l3_p1_inv_0',
      position: Vector2(268, 520),
      size: Vector2(40, 40),
      targetInverted: true,
      requireGrounded: false,
      triggerFullHeight: true,
    ));

    // Gap 1 (x: 340..424, width 84)
    w.add(SuddenGap(
      trapId: 'l3_p1_gap1',
      position: Vector2(340, 552),
      size: Vector2(84, 200),
      triggerLeadPx: 76.0,
    ));

    // Island 1 (x: 424..604, width 180)
    w.add(GroundBlock(position: Vector2(424, 552), size: Vector2(180, 200)));
    // Island 1 Inverter: grounded landing flips to Normal
    w.add(ControlInverterZone(
      trapId: 'l3_p1_inv_1',
      position: Vector2(434, 520),
      size: Vector2(150, 40),
      targetInverted: false,
      requireGrounded: true,
    ));

    // Gap 2 (x: 604..688, width 84)
    w.add(SuddenGap(
      trapId: 'l3_p1_gap2',
      position: Vector2(604, 552),
      size: Vector2(84, 200),
      triggerLeadPx: 52.0,
    ));

    // Island 2 (x: 688..868, width 180)
    w.add(GroundBlock(position: Vector2(688, 552), size: Vector2(180, 200)));
    // Island 2 Inverter: grounded landing flips to Inverted
    w.add(ControlInverterZone(
      trapId: 'l3_p1_inv_2',
      position: Vector2(698, 520),
      size: Vector2(150, 40),
      targetInverted: true,
      requireGrounded: true,
    ));

    // Gap 3 (x: 868..952, width 84)
    w.add(SuddenGap(
      trapId: 'l3_p1_gap3',
      position: Vector2(868, 552),
      size: Vector2(84, 200),
      triggerLeadPx: 52.0,
    ));

    // Landing floor extending into Passage 1 (x: 952..1720)
    w.add(GroundBlock(position: Vector2(952, 552), size: Vector2(768, 200)));
    // Landing Inverter: grounded landing flips back to Normal
    w.add(ControlInverterZone(
      trapId: 'l3_p1_inv_3',
      position: Vector2(962, 520),
      size: Vector2(150, 40),
      targetInverted: false,
      requireGrounded: true,
    ));

    // ==========================================
    // Room 2 / Platform 2 (x: 1376..2464)
    // ==========================================
    // Rear spike pops up behind player at x = 1468
    w.add(TrapSpike(
      trapId: 'l3_p2_rear_spike',
      position: Vector2(1468, 552),
      behavior: SpikeBehavior.remotePopUp,
      remoteTriggerX: 1548.0,
      remoteTriggerMaxX: 1700.0,
      hideCompletelyWhenIdle: true,
    ));

    // Invert trigger right after spike appearance: punishes holding Right!
    w.add(ControlInverterZone(
      trapId: 'l3_p2_inv_on',
      position: Vector2(1568, 520),
      size: Vector2(40, 40),
      targetInverted: true,
      requireGrounded: false,
      triggerFullHeight: true,
    ));

    // Gap 2A (x: 1720..1804, width 84)
    w.add(SuddenGap(
      trapId: 'l3_p2_gap1',
      position: Vector2(1720, 552),
      size: Vector2(84, 200),
      triggerLeadPx: 52.0,
    ));

    // Mid Island (x: 1804..1964, width 160) - stays inverted!
    w.add(GroundBlock(position: Vector2(1804, 552), size: Vector2(160, 200)));

    // Gap 2B (x: 1964..2048, width 84)
    w.add(SuddenGap(
      trapId: 'l3_p2_gap2',
      position: Vector2(1964, 552),
      size: Vector2(84, 200),
      triggerLeadPx: 52.0,
    ));

    // Post-gap runway extending through Passage 2 (x: 2048..2748)
    w.add(GroundBlock(position: Vector2(2048, 552), size: Vector2(700, 200)));

    // Grounded un-invert zone after landing from last gap
    w.add(ControlInverterZone(
      trapId: 'l3_p2_inv_off',
      position: Vector2(2100, 520),
      size: Vector2(120, 40),
      targetInverted: false,
      requireGrounded: true,
    ));

    // Cheap proximity pop-up spike right beside Passage 2
    w.add(TrapSpike(
      trapId: 'l3_p2_passage_spike',
      position: Vector2(2376, 552),
      behavior: SpikeBehavior.proximityPopUp,
      triggerDistance: 36.0,
      jitterDuration: 0.08,
      hideCompletelyWhenIdle: true,
    ));

    // ==========================================
    // Room 3 / Platform 3 (x: 2656..3744)
    // ==========================================
    // Starts as Inverted at room entry
    w.add(ControlInverterZone(
      trapId: 'l3_p3_entry_inv',
      position: Vector2(2668, 520),
      size: Vector2(50, 40),
      targetInverted: true,
      requireGrounded: false,
      triggerFullHeight: true,
    ));

    // Staircase steps (each 92px wide, 52px rise):
    // Step 1: y = 500 (rise 52 from 552)
    w.add(GroundBlock(position: Vector2(2748, 500), size: Vector2(92, 252)));
    w.add(ControlInverterZone(
      trapId: 'l3_p3_step1_inv',
      position: Vector2(2752, 470),
      size: Vector2(84, 30),
      targetInverted: false,
      requireGrounded: true,
    ));

    // Step 2: y = 448 (rise 52 from 500)
    w.add(GroundBlock(position: Vector2(2840, 448), size: Vector2(92, 304)));
    w.add(ControlInverterZone(
      trapId: 'l3_p3_step2_inv',
      position: Vector2(2844, 418),
      size: Vector2(84, 30),
      targetInverted: true,
      requireGrounded: true,
    ));

    // Step 3: y = 396 (rise 52 from 448)
    w.add(GroundBlock(position: Vector2(2932, 396), size: Vector2(92, 356)));
    w.add(ControlInverterZone(
      trapId: 'l3_p3_step3_inv',
      position: Vector2(2936, 366),
      size: Vector2(84, 30),
      targetInverted: false,
      requireGrounded: true,
    ));
    // Step 3 rear-ambush spike catches player if jumping backward from Step 4
    w.add(TrapSpike(
      trapId: 'l3_p3_step3_spike',
      position: Vector2(2978, 396),
      behavior: SpikeBehavior.remotePopUp,
      remoteTriggerX: 3028.0,
      remoteTriggerMaxX: 3104.0,
      remoteTriggerMaxY: 348.0,
      remoteRequireGrounded: true,
      hideCompletelyWhenIdle: true,
    ));

    // Step 4 & Top Plateau starter: y = 344 (x: 3024..3164)
    w.add(GroundBlock(position: Vector2(3024, 344), size: Vector2(140, 408)));
    // Step 4 Inverter: grounded landing flips to Inverted
    w.add(ControlInverterZone(
      trapId: 'l3_p3_step4_inv',
      position: Vector2(3028, 314),
      size: Vector2(56, 30),
      targetInverted: true,
      requireGrounded: true,
    ));
    // Plateau normalizer: resets to Normal before hesitation gap!
    w.add(ControlInverterZone(
      trapId: 'l3_p3_plateau_norm',
      position: Vector2(3096, 314),
      size: Vector2(68, 30),
      targetInverted: false,
      requireGrounded: true,
    ));

    // Hesitation Gap on plateau (x: 3164..3468, width 304, gapWidth 86)
    w.add(MovingGapFloor(
      trapId: 'l3_p3_hesitation',
      position: Vector2(3164, 344),
      size: Vector2(304, 408),
      mode: MovingGapMode.hesitation,
      gapWidth: 86.0,
      activateRoomX: 2560.0,
      initialGapLocalX: 96.0,
      anchorGapLocalX: 160.0,
      proximityRangePx: 108.0,
    ));

    // Final plateau runway (x: 3468..3744, width 276)
    w.add(GroundBlock(position: Vector2(3468, 344), size: Vector2(276, 408)));

    // Surprise pop-up spike before exit portal (does not move)
    w.add(TrapSpike(
      trapId: 'l3_p3_surprise_spike',
      position: Vector2(3588, 344),
      behavior: SpikeBehavior.proximityPopUp,
      hideCompletelyWhenIdle: true,
      triggerDistance: 44.0,
      jitterDuration: 0.08,
    ));

    // Exit Portal door on plateau
    w.add(ExitPortal(position: Vector2(3698, 344)));

    return ChamberLoadResult(
      spawnPosition: Vector2(148, 552),
      exitX: 3698.0,
    );
  }

  static ChamberLoadResult _buildLevel4(TrapDashGame game) {
    final w = game.world;

    // Partition upper wall roofs between rooms leaving 96px high passage tunnels (y: 456..552)
    w.add(GroundBlock(position: Vector2(1184, 104), size: Vector2(192, 352)));
    w.add(GroundBlock(position: Vector2(2464, 104), size: Vector2(192, 352)));

    // ==========================================
    // Room 1 / Platform 1 (x: 96..1184): 4 Slender High Pillars & Betrayal Warps
    // ==========================================
    // Pillar 1: x = 100..180 (w: 80, h: 332, top y: 420)
    w.add(GroundBlock(position: Vector2(100, 420), size: Vector2(80, 332)));
    final p1Spike = TrapSpike(
      trapId: 'l4_p1_pillar1_spike',
      position: Vector2(140, 420),
      behavior: SpikeBehavior.proximityPopUp,
      hideCompletelyWhenIdle: true,
      triggerDistance: 0.0, // Activated by Warp 1 or betrayal
    );
    w.add(p1Spike);

    // Gap 1: x = 180..360 (w: 180)
    // Warp 1: at bottom of Gap 1, warps to Pillar 2 and raises spike on Pillar 1
    w.add(WarpPortal(
      trapId: 'l4_p1_warp1',
      position: Vector2(270, 624),
      targetPosition: Vector2(400, 420),
      postWarpSpikeToActivate: p1Spike,
    ));

    // Pillar 2: x = 360..440 (w: 80, h: 332, top y: 420)
    w.add(GroundBlock(position: Vector2(360, 420), size: Vector2(80, 332)));
    final p2Spike = TrapSpike(
      trapId: 'l4_p1_pillar2_spike',
      position: Vector2(400, 420),
      behavior: SpikeBehavior.proximityPopUp,
      hideCompletelyWhenIdle: true,
      triggerDistance: 0.0, // Activated by Warp 2
    );
    w.add(p2Spike);

    // Gap 2: x = 440..620 (w: 180)
    // Warp 2: at bottom of Gap 2, warps to Pillar 3 and raises spike on Pillar 2
    w.add(WarpPortal(
      trapId: 'l4_p1_warp2',
      position: Vector2(530, 624),
      targetPosition: Vector2(660, 420),
      postWarpSpikeToActivate: p2Spike,
    ));

    // Pillar 3: x = 620..700 (w: 80, h: 332, top y: 420)
    w.add(GroundBlock(position: Vector2(620, 420), size: Vector2(80, 332)));

    // Gap 3: x = 700..790 (w: 90, jumpable gap!)
    // Betrayal Warp 3: warps player back to Pillar 1 directly onto the extended spike!
    w.add(WarpPortal(
      trapId: 'l4_p1_warp3_trap',
      position: Vector2(745, 624),
      targetPosition: Vector2(140, 420),
    ));

    // Pillar 4: x = 790..870 (w: 80, h: 332, top y: 420)
    w.add(GroundBlock(position: Vector2(790, 420), size: Vector2(80, 332)));

    // Step down transition into Passage 1:
    w.add(GroundBlock(position: Vector2(870, 486), size: Vector2(90, 266)));
    w.add(GroundBlock(position: Vector2(960, 552), size: Vector2(416, 200)));
    w.add(CheckpointFlag(checkpointId: 1, position: Vector2(1312, 552)));

    // ==========================================
    // Room 2 / Platform 2 (x: 1376..2464): Void Bridge & Upper Platform
    // ==========================================
    // Left Bridge: x = 1376..1696 (w: 320, h: 36) - lower part is void pit!
    w.add(GroundBlock(position: Vector2(1376, 552), size: Vector2(320, 36)));

    // Bridge Gap: x = 1696..1844 (w: 148)
    // Multi-pass Bridge Warp:
    // Pass 1: player jumps off left bridge, warp shifts left -38px; entering teleports to Right Bridge (1910, 552)
    // Pass 2: player jumps off right bridge, warp shifts right +38px; entering teleports to Upper Platform (1740, 340) and inverts controls!
    w.add(WarpPortal(
      trapId: 'l4_p2_bridge_warp',
      position: Vector2(1770, 616),
      targetPosition: Vector2(1910, 552),
      pass1JumpShiftX: -38.0,
      secondTargetPosition: Vector2(1740, 340),
      secondSetControlsInvertedOnWarp: true,
      pass2JumpShiftX: 38.0,
    ));

    // Right Bridge: x = 1844..2100 (w: 256, h: 36)
    w.add(GroundBlock(position: Vector2(1844, 552), size: Vector2(256, 36)));

    // Right Blocker Wall: x = 2100..2132 (y = 340..588, h: 248) prevents rightward escape
    w.add(GroundBlock(position: Vector2(2100, 340), size: Vector2(32, 248)));

    // Close-proximity spike on Right Bridge (x = 1976)
    w.add(TrapSpike(
      trapId: 'l4_p2_bridge_spike',
      position: Vector2(1976, 552),
      behavior: SpikeBehavior.proximityPopUp,
      triggerDistance: 36.0,
      jitterDuration: 0.08,
      hideCompletelyWhenIdle: true,
    ));

    // Upper Inner Platform: x = 1640..1900 (w = 260, h = 28)
    w.add(GroundBlock(position: Vector2(1640, 340), size: Vector2(260, 28)));

    // Close-proximity spike on Upper Platform (x = 1828)
    w.add(TrapSpike(
      trapId: 'l4_p2_upper_spike',
      position: Vector2(1828, 340),
      behavior: SpikeBehavior.proximityPopUp,
      triggerDistance: 36.0,
      jitterDuration: 0.08,
      hideCompletelyWhenIdle: true,
    ));

    // Deceptive Fleeing Warp: starts at right (1868, 316), instantly moves to left (1668, 316) upon approaching right
    // Entering teleports to Passage 2 floor (2360, 552) and restores controls to normal!
    w.add(WarpPortal(
      trapId: 'l4_p2_upper_warp',
      position: Vector2(1868, 316),
      fleeTargetPosition: Vector2(1668, 316),
      fleeTriggerX: 1764.0,
      targetPosition: Vector2(2360, 552),
      setControlsInvertedOnWarp: false,
    ));

    // Passage 2 floor runway (x = 2300..2656, ends right at Room 3 entrance)
    w.add(GroundBlock(position: Vector2(2300, 552), size: Vector2(356, 200)));
    w.add(CheckpointFlag(checkpointId: 2, position: Vector2(2592, 552)));

    // ==========================================
    // Room 3 / Platform 3 (x: 2656..3744): Portal Gauntlet & Exit Ledge
    // ==========================================
    // Gauntlet controller managing compact square box, paired portals, and on-demand wrong-choice hazards
    w.add(PortalGauntletController());

    // Solid Exit Ledge (x: 3556..3668, y: 400): front ledge (3556..3598) hosts Step 1 doorTrapSpike, rear hosts ExitPortal
    w.add(GroundBlock(position: Vector2(3556, 400), size: Vector2(112, 36)));
    w.add(ExitPortal(position: Vector2(3620, 400)));

    return ChamberLoadResult(
      spawnPosition: Vector2(140, 420),
      exitX: 3620.0,
    );
  }

  static ChamberLoadResult _buildLevel5(TrapDashGame game) {
    final w = game.world;
    // Low ceiling overhang
    w.add(GroundBlock(position: Vector2(96, 104), size: Vector2(824, 84)));

    // Slab 1
    w.add(GroundBlock(position: Vector2(96, 552), size: Vector2(180, 200)));
    w.add(ReverseSpring(trapId: 'rs5_1', position: Vector2(228, 552)));

    // Pit 1
    w.add(FakeFloor(trapId: 'f5_1', position: Vector2(292, 552), size: Vector2(68, 24)));

    // Slab 2
    w.add(GroundBlock(position: Vector2(376, 552), size: Vector2(200, 200)));
    w.add(FallingBlock(trapId: 'fb5_1', position: Vector2(396, 188), groundY: 552));
    w.add(MovingSaw(
      pathStart: Vector2(460, 534),
      pathEnd: Vector2(556, 534),
      speed: 120,
    ));

    // Slab 3
    w.add(GroundBlock(position: Vector2(604, 552), size: Vector2(192, 200)));
    w.add(CheckpointFlag(checkpointId: 1, position: Vector2(644, 552)));
    w.add(PickupItem(type: PickupType.coin, position: Vector2(700, 500)));
    w.add(ReverseSpring(trapId: 'rs5_2', position: Vector2(756, 552)));

    // Pit 2
    w.add(DisappearingPlatform(position: Vector2(824, 512), size: Vector2(72, 20)));
    w.add(FallingBlock(trapId: 'fb5_2', position: Vector2(840, 188), groundY: 512));
    w.add(MovingSaw(
      pathStart: Vector2(932, 430),
      pathEnd: Vector2(932, 555),
      speed: 110,
    ));
    w.add(FakeFloor(trapId: 'f5_2', position: Vector2(960, 552), size: Vector2(64, 24)));

    // Elevated exit altar
    w.add(GroundBlock(position: Vector2(1036, 516), size: Vector2(148, 236)));
    w.add(PickupItem(type: PickupType.coin, position: Vector2(1072, 466)));
    w.add(ExitPortal(position: Vector2(1136, 516)));

    return ChamberLoadResult(
      spawnPosition: Vector2(136, 552),
      exitX: 1136.0,
    );
  }
}
