import { TaskLevel } from '../models/task';

/** The canonical ordered ring of all 9 household tasks. */
export const TASK_RING_NAMES: readonly string[] = [
  'Toilet',
  'Kitchen',
  'Recycling',
  'Shower',
  'Floor(A)',
  'Washing Rags',
  'Bathroom',
  'Floor(B)',
  'Shopping',
] as const;

/** Total number of tasks (and flat members) in the system. */
export const TOTAL_TASKS = 9;

/**
 * Maps each ring index (0–8) to its difficulty level.
 * L3 = hard, L2 = medium, L1 = easy.
 */
export const TASK_LEVEL_BY_RING_INDEX: readonly TaskLevel[] = [
  TaskLevel.L3, // 0: Toilet
  TaskLevel.L2, // 1: Kitchen
  TaskLevel.L1, // 2: Recycling
  TaskLevel.L3, // 3: Shower
  TaskLevel.L2, // 4: Floor(A)
  TaskLevel.L1, // 5: Washing Rags
  TaskLevel.L3, // 6: Bathroom
  TaskLevel.L2, // 7: Floor(B)
  TaskLevel.L1, // 8: Shopping
];

/** Ring indices of all L3 (hard) tasks. */
export const L3_RING_INDICES: readonly number[] = [0, 3, 6];

/** Ring indices of all L2 (medium) tasks. */
export const L2_RING_INDICES: readonly number[] = [1, 4, 7];

/** Ring indices of all L1 (easy) tasks. */
export const L1_RING_INDICES: readonly number[] = [2, 5, 8];

// ── Default admin-configurable settings ─────────────────────────────────────

/** Default number of weeks a person can be on short vacation before long vacation treatment applies. */
export const DEFAULT_VACATION_THRESHOLD_WEEKS = 1;

/** Default hours after the last task deadline before week_reset() fires. */
export const DEFAULT_GRACE_PERIOD_HOURS = 1;

/** Default hours before a task deadline to send a reminder notification. */
export const DEFAULT_REMINDER_HOURS_BEFORE_DEADLINE = 1;

/** Default hours before bought shopping items are auto-deleted. */
export const DEFAULT_SHOPPING_CLEANUP_HOURS = 6;

/** Swap tokens each member receives at the start of every ETH semester. */
export const SWAP_TOKENS_PER_SEMESTER = 3;

/** Cooldown in days before the same issue can be sent to Livit again. */
export const ISSUE_SEND_COOLDOWN_DAYS = 5;

/** Number of pre-written German email templates for Livit issue reporting. */
export const EMAIL_TEMPLATE_COUNT = 3;
