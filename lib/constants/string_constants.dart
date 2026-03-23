/// Centralized string constants for the FlatOrg app.
///
/// All user-facing and domain-specific strings are defined here
/// to avoid literal strings scattered throughout the codebase.
class StringConstants {
  StringConstants._();

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

  // ---------------------------------------------------------------------------
  // Task difficulty display names
  // ---------------------------------------------------------------------------
  static const String difficultyHard = 'Hard (L3)';
  static const String difficultyMedium = 'Medium (L2)';
  static const String difficultyEasy = 'Easy (L1)';

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

}
