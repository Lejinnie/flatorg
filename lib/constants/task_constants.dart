import 'package:flatorg/constants/string_constants.dart';

/// Non-string task-related constants: ring order, difficulty levels, and mappings.
class TaskConstants {
  TaskConstants._();

  // ---------------------------------------------------------------------------
  // Task difficulty levels
  // ---------------------------------------------------------------------------
  static const int difficultyLevelHard = 3;
  static const int difficultyLevelMedium = 2;
  static const int difficultyLevelEasy = 1;

  /// All task names in task-ring order, used for sequential processing.
  static const List<String> taskRingOrder = [
    StringConstants.taskToilet,
    StringConstants.taskKitchen,
    StringConstants.taskRecycling,
    StringConstants.taskShower,
    StringConstants.taskFloorA,
    StringConstants.taskWashingRags,
    StringConstants.taskBathroom,
    StringConstants.taskFloorB,
    StringConstants.taskShopping,
  ];

  /// Maps each task name to its difficulty level.
  static const Map<String, int> taskDifficultyMap = {
    StringConstants.taskToilet: difficultyLevelHard,
    StringConstants.taskShower: difficultyLevelHard,
    StringConstants.taskBathroom: difficultyLevelHard,
    StringConstants.taskFloorA: difficultyLevelMedium,
    StringConstants.taskFloorB: difficultyLevelMedium,
    StringConstants.taskKitchen: difficultyLevelMedium,
    StringConstants.taskRecycling: difficultyLevelEasy,
    StringConstants.taskWashingRags: difficultyLevelEasy,
    StringConstants.taskShopping: difficultyLevelEasy,
  };
}
