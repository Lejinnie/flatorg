import '../models/task.dart';

/// The canonical ordered ring of all 9 household tasks.
const taskRingNames = [
  'Toilet',
  'Kitchen',
  'Recycling',
  'Shower',
  'Floor(A)',
  'Washing Rags',
  'Bathroom',
  'Floor(B)',
  'Shopping',
];

/// Total number of tasks (and flat members).
const totalTasks = 9;

/// Maps each ring index (0–8) to its difficulty level.
const List<TaskLevel> taskLevelByRingIndex = [
  TaskLevel.l3, // 0: Toilet
  TaskLevel.l2, // 1: Kitchen
  TaskLevel.l1, // 2: Recycling
  TaskLevel.l3, // 3: Shower
  TaskLevel.l2, // 4: Floor(A)
  TaskLevel.l1, // 5: Washing Rags
  TaskLevel.l3, // 6: Bathroom
  TaskLevel.l2, // 7: Floor(B)
  TaskLevel.l1, // 8: Shopping
];

/// Ring indices of all L3 (hard) tasks.
const l3RingIndices = [0, 3, 6];

/// Ring indices of all L2 (medium) tasks.
const l2RingIndices = [1, 4, 7];

/// Ring indices of all L1 (easy) tasks.
const l1RingIndices = [2, 5, 8];

// ── Default admin-configurable settings ──────────────────────────────────────

/// Default short-vacation threshold in weeks.
const defaultVacationThresholdWeeks = 1;

/// Default grace period hours after the last task deadline.
const defaultGracePeriodHours = 1;

/// Default hours before task deadline to send a reminder.
const defaultReminderHoursBeforeDeadline = 1;

/// Default hours before bought shopping items are deleted.
const defaultShoppingCleanupHours = 6;

/// Swap tokens each member receives at the start of every ETH semester.
const swapTokensPerSemester = 3;

/// Cooldown in days before the same issue can be sent to Livit again.
const issueSendCooldownDays = 5;
