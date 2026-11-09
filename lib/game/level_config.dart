class LevelConfig {
  final int levelNumber;
  final String tmxFile;
  final String goalText;
  final double timeLimit;
  final int initialHearts;
  final int requiredKeys;
  final int roomCount;

  const LevelConfig({
    required this.levelNumber,
    required this.tmxFile,
    required this.goalText,
    required this.timeLimit,
    required this.initialHearts,
    this.requiredKeys = 0,
    this.roomCount = 1,
  });

  static const List<LevelConfig> _allLevels = [
    LevelConfig(
      levelNumber: 1,
      tmxFile: 'Level01.tmx',
      goalText: 'Cross 3 Platforms & Reach the Exit in 90s',
      timeLimit: 90.0,
      initialHearts: 5,
      requiredKeys: 0,
      roomCount: 3,
    ),
    LevelConfig(
      levelNumber: 2,
      tmxFile: 'Level02.tmx',
      goalText: 'Outsmart the Deceptive Spikes & Exit in 75s',
      timeLimit: 75.0,
      initialHearts: 5,
      requiredKeys: 0,
      roomCount: 3,
    ),
    LevelConfig(
      levelNumber: 3,
      tmxFile: 'Level03.tmx',
      goalText: 'Survive Inverted Controls & Exit in 70s',
      timeLimit: 70.0,
      initialHearts: 4,
      requiredKeys: 0,
      roomCount: 3,
    ),
    LevelConfig(
      levelNumber: 4,
      tmxFile: 'Level04.tmx',
      goalText: 'Dodge the Moving Saws & Exit in 60s',
      timeLimit: 60.0,
      initialHearts: 3,
      requiredKeys: 0,
    ),
    LevelConfig(
      levelNumber: 5,
      tmxFile: 'Level05.tmx',
      goalText: 'Conquer the Master Gauntlet in 60s',
      timeLimit: 60.0,
      initialHearts: 3,
      requiredKeys: 0,
    ),
  ];

  static LevelConfig get(int levelNumber) {
    if (levelNumber < 1 || levelNumber > _allLevels.length) {
      return _allLevels.first;
    }
    return _allLevels[levelNumber - 1];
  }
}
