/// Centralized string constants for the FlatOrg app.
///
/// All user-facing and domain-specific strings are defined here
/// to avoid literal strings scattered throughout the codebase.
class Strings {
  Strings._();

  // ---------------------------------------------------------------------------
  // Task names (in sequential task-ring order)
  // ---------------------------------------------------------------------------
  static const String taskToilet = 'Toilet';
  static const String taskKitchen = 'Kitchen';
  static const String taskRecycling = 'Recycling';
  static const String taskShower = 'Shower';
  static const String taskFloorA = 'Floor (A)';
  static const String taskWashingRags = 'Washing Rags';
  static const String taskBathroom = 'Bathroom';
  static const String taskFloorB = 'Floor (B)';
  static const String taskShopping = 'Shopping & report to @Livit';

  /// All task names in task-ring order, used for sequential processing.
  static const List<String> taskRingOrder = [
    taskToilet,
    taskKitchen,
    taskRecycling,
    taskShower,
    taskFloorA,
    taskWashingRags,
    taskBathroom,
    taskFloorB,
    taskShopping,
  ];

  // ---------------------------------------------------------------------------
  // Task difficulty levels
  // ---------------------------------------------------------------------------
  static const String difficultyHard = 'Hard (L3)';
  static const String difficultyMedium = 'Medium (L2)';
  static const String difficultyEasy = 'Easy (L1)';

  static const int difficultyLevelHard = 3;
  static const int difficultyLevelMedium = 2;
  static const int difficultyLevelEasy = 1;

  /// Maps each task name to its difficulty level.
  static const Map<String, int> taskDifficultyMap = {
    taskToilet: difficultyLevelHard,
    taskShower: difficultyLevelHard,
    taskBathroom: difficultyLevelHard,
    taskFloorA: difficultyLevelMedium,
    taskFloorB: difficultyLevelMedium,
    taskKitchen: difficultyLevelMedium,
    taskRecycling: difficultyLevelEasy,
    taskWashingRags: difficultyLevelEasy,
    taskShopping: difficultyLevelEasy,
  };

  // ---------------------------------------------------------------------------
  // Firestore collection and field names
  // ---------------------------------------------------------------------------
  static const String collectionFlats = 'flats';
  static const String collectionTasks = 'tasks';
  static const String collectionPersons = 'persons';
  static const String collectionIssues = 'issues';
  static const String collectionShoppingItems = 'shoppingItems';

  static const String fieldName = 'name';
  static const String fieldDescription = 'description';
  static const String fieldDueDateTime = 'due_date_time';
  static const String fieldAssignedTo = 'assigned_to';
  static const String fieldOriginalAssignedTo = 'original_assigned_to';
  static const String fieldState = 'state';
  static const String fieldWeeksNotCleaned = 'weeks_not_cleaned';
  static const String fieldUid = 'uid';
  static const String fieldEmail = 'email';
  static const String fieldRole = 'role';
  static const String fieldOnVacation = 'on_vacation';
  static const String fieldSwapTokensRemaining = 'swap_tokens_remaining';
  static const String fieldVacationThresholdWeeks = 'vacation_threshold_weeks';

  // ---------------------------------------------------------------------------
  // Default configuration values
  // ---------------------------------------------------------------------------
  static const int defaultVacationThresholdWeeks = 1;
  static const int defaultGracePeriodHours = 1;
  static const int defaultReminderHoursBeforeDeadline = 1;
  static const int defaultShoppingCleanupHours = 6;
  static const int defaultSwapTokensPerSemester = 3;
  static const int issueCooldownDays = 5;
}
