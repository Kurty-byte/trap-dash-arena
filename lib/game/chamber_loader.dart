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
import 'package:trap_dash_arena/game/actors/moving_saw.dart';
import 'package:trap_dash_arena/game/actors/pickup_item.dart';
import 'package:trap_dash_arena/game/actors/reverse_spring.dart';
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
  static Future<ChamberLoadResult> loadIntoWorld(
    TrapDashGame game,
    LevelConfig config,
  ) async {
    // 1. Always spawn outer solid enclosure walls (+32px bleed margin to prevent camera shake bleed)
    _spawnPerimeterShell(game.world);

    // In unit/widget tests, use fast programmatic chamber directly to avoid asset bundle timeouts
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return _loadProgrammaticChamber(game, config.levelNumber);
    }

    // 2. Try loading from Tiled map, fall back to programmatic chamber
    try {
      final tiled = await TiledComponent.load(
        config.tmxFile,
        Vector2.all(32),
      );
      final result = loadFromTiled(game, tiled);
      if (result != null) return result;
    } catch (_) {
      // In headless test environments or asset bundle fallbacks
      game.world.removeAll(game.world.children);
      _spawnPerimeterShell(game.world);
    }

    return _loadProgrammaticChamber(game, config.levelNumber);
  }

  static void _spawnPerimeterShell(World world) {
    // Left outer wall (inner edge at x = 96)
    world.add(GroundBlock(
      position: Vector2(-32, -32),
      size: Vector2(128, 784),
    ));

    // Right outer wall (inner edge at x = 1184)
    world.add(GroundBlock(
      position: Vector2(1184, -32),
      size: Vector2(128, 784),
    ));

    // Top ceiling wall (inner edge at y = 72)
    world.add(GroundBlock(
      position: Vector2(-32, -32),
      size: Vector2(1344, 104),
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
            game.world.add(TrapSpike(
              trapId: 's_${obj.id}',
              position: pos,
              isStatic: false,
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
    // Overhang ceiling slab (x: 448..1184, y: 72..268, leaving 284px tunnel)
    w.add(GroundBlock(position: Vector2(448, 72), size: Vector2(736, 196)));

    // Floor 1: starting area
    w.add(GroundBlock(position: Vector2(96, 552), size: Vector2(264, 200)));
    w.add(HintArrow(position: Vector2(190, 500)));
    w.add(HintArrow(position: Vector2(220, 500)));
    w.add(TrapSpike(trapId: 's1_1', position: Vector2(268, 552), isStatic: true));

    // Pit 1: crumbling floor bridge
    w.add(FakeFloor(trapId: 'f1_1', position: Vector2(376, 552), size: Vector2(64, 24)));
    w.add(FakeFloor(trapId: 'f1_2', position: Vector2(460, 552), size: Vector2(64, 24)));
    w.add(PickupItem(type: PickupType.coin, position: Vector2(408, 500)));
    w.add(PickupItem(type: PickupType.coin, position: Vector2(492, 500)));

    // Floor 2: checkpoint and trap
    w.add(GroundBlock(position: Vector2(544, 552), size: Vector2(296, 200)));
    w.add(CheckpointFlag(checkpointId: 1, position: Vector2(600, 552)));
    w.add(PickupItem(type: PickupType.coin, position: Vector2(680, 500)));
    w.add(TrapSpike(trapId: 's1_2', position: Vector2(750, 552), isStatic: false));

    // Pit 2: stepping pillar
    w.add(GroundBlock(position: Vector2(876, 496), size: Vector2(52, 256)));
    w.add(PickupItem(type: PickupType.coin, position: Vector2(902, 446)));

    // Floor 3: exit area
    w.add(GroundBlock(position: Vector2(960, 552), size: Vector2(224, 200)));
    w.add(PickupItem(type: PickupType.coin, position: Vector2(1040, 500)));
    w.add(ExitPortal(position: Vector2(1128, 552)));

    return ChamberLoadResult(
      spawnPosition: Vector2(148, 552),
      exitX: 1128.0,
    );
  }

  static ChamberLoadResult _buildLevel2(TrapDashGame game) {
    final w = game.world;
    // Lower floor slab 1
    w.add(GroundBlock(position: Vector2(96, 552), size: Vector2(374, 200)));

    // Stepped block to upper mezzanine
    w.add(GroundBlock(position: Vector2(256, 468), size: Vector2(84, 84)));
    w.add(PickupItem(type: PickupType.key, position: Vector2(298, 418)));

    // Upper Mezzanine
    w.add(GroundBlock(position: Vector2(380, 380), size: Vector2(440, 32)));
    w.add(PickupItem(type: PickupType.key, position: Vector2(460, 330)));
    w.add(TrapSpike(trapId: 's2_2', position: Vector2(560, 380), isStatic: false));
    w.add(PickupItem(type: PickupType.key, position: Vector2(680, 330)));

    // Lower underpass Pit 1
    w.add(FakeFloor(trapId: 'f2_1', position: Vector2(478, 552), size: Vector2(74, 24)));

    // Lower mid floor
    w.add(GroundBlock(position: Vector2(560, 552), size: Vector2(280, 200)));
    w.add(CheckpointFlag(checkpointId: 1, position: Vector2(640, 552)));
    w.add(PickupItem(type: PickupType.key, position: Vector2(750, 502)));

    // Lower underpass Pit 2
    w.add(FakeFloor(trapId: 'f2_2', position: Vector2(852, 552), size: Vector2(72, 24)));

    // Right floor and exit
    w.add(GroundBlock(position: Vector2(936, 552), size: Vector2(248, 200)));
    w.add(TrapSpike(trapId: 's2_1', position: Vector2(216, 552), isStatic: false));
    w.add(TrapSpike(trapId: 's2_3', position: Vector2(1010, 552), isStatic: false));
    w.add(PickupItem(type: PickupType.key, position: Vector2(1055, 502)));
    w.add(ExitPortal(position: Vector2(1132, 552)));

    return ChamberLoadResult(
      spawnPosition: Vector2(144, 552),
      exitX: 1132.0,
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
