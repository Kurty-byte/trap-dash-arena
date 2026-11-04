import 'dart:io';
import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/foundation.dart';
import 'package:trap_dash_arena/game/actors/checkpoint_flag.dart';
import 'package:trap_dash_arena/game/actors/disappearing_platform.dart';
import 'package:trap_dash_arena/game/actors/exit_portal.dart';
import 'package:trap_dash_arena/game/actors/fake_floor.dart';
import 'package:trap_dash_arena/game/actors/falling_block.dart';
import 'package:trap_dash_arena/game/actors/ground_block.dart';
import 'package:trap_dash_arena/game/actors/hint_arrow.dart';
import 'package:trap_dash_arena/game/actors/moving_gap_floor.dart';
import 'package:trap_dash_arena/game/actors/moving_saw.dart';
import 'package:trap_dash_arena/game/actors/pickup_item.dart';
import 'package:trap_dash_arena/game/actors/reverse_spring.dart';
import 'package:trap_dash_arena/game/actors/sudden_gap.dart';
import 'package:trap_dash_arena/game/actors/trap_spike.dart';
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
    // 1. Always spawn outer solid enclosure walls (+32px bleed margin to prevent camera shake bleed)
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
      _spawnPerimeterShell(game.world, roomCount: config.roomCount);
    }

    return _loadProgrammaticChamber(game, config.levelNumber);
  }

  static void _spawnPerimeterShell(World world, {int roomCount = 1}) {
    // Left outer wall (inner edge at x = 96)
    world.add(GroundBlock(
      position: Vector2(-32, -32),
      size: Vector2(128, 784),
    ));

    // Right outer wall (inner edge at x = roomCount * 1280 - 96)
    final rightWallX = roomCount * 1280.0 - 96.0;
    world.add(GroundBlock(
      position: Vector2(rightWallX, -32),
      size: Vector2(128, 784),
    ));

    // Top ceiling wall (inner edge at y = 72)
    final ceilingW = roomCount * 1280.0 + 64.0;
    world.add(GroundBlock(
      position: Vector2(-32, -32),
      size: Vector2(ceilingW, 104),
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
    w.add(GroundBlock(position: Vector2(1184, 72), size: Vector2(192, 384)));
    w.add(GroundBlock(position: Vector2(2464, 72), size: Vector2(192, 384)));

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
    w.add(GroundBlock(position: Vector2(1184, 72), size: Vector2(192, 384)));
    w.add(GroundBlock(position: Vector2(2464, 72), size: Vector2(192, 384)));

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
    // Solid ceiling overhang slab down to y = 200
    w.add(GroundBlock(position: Vector2(96, 72), size: Vector2(924, 128)));

    // Floor 1
    w.add(GroundBlock(position: Vector2(96, 552), size: Vector2(334, 200)));
    w.add(FallingBlock(trapId: 'fb3_1', position: Vector2(240, 200), groundY: 552));
    w.add(FallingBlock(trapId: 'fb3_2', position: Vector2(350, 200), groundY: 552));

    // Pit 1
    w.add(FakeFloor(trapId: 'f3_1', position: Vector2(438, 552), size: Vector2(80, 24)));

    // Mid floor
    w.add(GroundBlock(position: Vector2(526, 552), size: Vector2(264, 200)));
    w.add(CheckpointFlag(checkpointId: 1, position: Vector2(590, 552)));
    w.add(PickupItem(type: PickupType.coin, position: Vector2(590, 500)));
    w.add(FallingBlock(trapId: 'fb3_3', position: Vector2(700, 200), groundY: 552));

    // Pit 2
    w.add(DisappearingPlatform(position: Vector2(802, 524), size: Vector2(72, 20)));

    // Floor 3
    w.add(GroundBlock(position: Vector2(886, 552), size: Vector2(174, 200)));
    w.add(FallingBlock(trapId: 'fb3_4', position: Vector2(930, 200), groundY: 552));

    // Elevated right alcove ledge
    w.add(GroundBlock(position: Vector2(1060, 464), size: Vector2(124, 288)));

    // Decoy exit portal
    w.add(ExitPortal(
      position: Vector2(995, 552),
      isFakeFirst: true,
      realTargetPosition: Vector2(1132, 464),
    ));

    return ChamberLoadResult(
      spawnPosition: Vector2(144, 552),
      exitX: 1132.0,
    );
  }

  static ChamberLoadResult _buildLevel4(TrapDashGame game) {
    final w = game.world;
    // Central ceiling baffle
    w.add(GroundBlock(position: Vector2(570, 72), size: Vector2(190, 168)));

    // Entry floor
    w.add(GroundBlock(position: Vector2(96, 552), size: Vector2(194, 200)));
    w.add(MovingSaw(
      pathStart: Vector2(195, 534),
      pathEnd: Vector2(270, 534),
      speed: 100,
    ));

    // Gap 1
    w.add(DisappearingPlatform(position: Vector2(320, 520), size: Vector2(80, 20)));
    w.add(PickupItem(type: PickupType.coin, position: Vector2(360, 470)));

    // Pillar 1
    w.add(GroundBlock(position: Vector2(430, 552), size: Vector2(140, 200)));
    w.add(CheckpointFlag(checkpointId: 1, position: Vector2(490, 552)));

    // Gap 2
    w.add(DisappearingPlatform(position: Vector2(595, 496), size: Vector2(72, 20)));
    w.add(MovingSaw(
      pathStart: Vector2(712, 420),
      pathEnd: Vector2(712, 560),
      speed: 110,
    ));
    w.add(PickupItem(type: PickupType.coin, position: Vector2(631, 444)));

    // Pillar 2
    w.add(GroundBlock(position: Vector2(760, 520), size: Vector2(150, 232)));
    w.add(MovingSaw(
      pathStart: Vector2(785, 502),
      pathEnd: Vector2(885, 502),
      speed: 120,
    ));

    // Gap 3
    w.add(DisappearingPlatform(position: Vector2(938, 520), size: Vector2(72, 20)));
    w.add(PickupItem(type: PickupType.coin, position: Vector2(974, 468)));

    // Exit floor
    w.add(GroundBlock(position: Vector2(1040, 552), size: Vector2(144, 200)));
    w.add(ExitPortal(position: Vector2(1128, 552)));

    return ChamberLoadResult(
      spawnPosition: Vector2(144, 552),
      exitX: 1128.0,
    );
  }

  static ChamberLoadResult _buildLevel5(TrapDashGame game) {
    final w = game.world;
    // Low ceiling overhang
    w.add(GroundBlock(position: Vector2(96, 72), size: Vector2(824, 116)));

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
