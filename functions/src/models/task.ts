import { Timestamp } from 'firebase-admin/firestore';

/**
 * Difficulty level of a task in the rotation ring.
 * Determines reward/punishment direction during week_reset().
 */
export enum TaskLevel {
  L1 = 'L1', // easy: Recycling, Washing Rags, Shopping
  L2 = 'L2', // medium: Kitchen, Floor(A), Floor(B)
  L3 = 'L3', // hard: Toilet, Shower, Bathroom
}

/**
 * Lifecycle state of a task within a single week.
 * Drives UI color coding and week_reset() categorisation.
 */
export enum TaskState {
  /** Set by week_reset(). Task not yet done — shown in yellow. */
  Pending = 'pending',
  /** Assignee marked done before deadline — shown in green. */
  Completed = 'completed',
  /** Deadline passed without completion (grace period) — shown in red. */
  NotDone = 'not_done',
  /** Assignee was removed mid-week by admin. Treated like short/long vacation in reset. */
  Vacant = 'vacant',
}

/**
 * A single household task stored as a Firestore document.
 * Acts as a state machine; transitions are driven by Cloud Function events.
 */
export interface Task {
  /** Firestore document ID. */
  id: string;
  /** Display name (e.g. 'Toilet', 'Kitchen'). */
  name: string;
  /** Ordered list of subtask instructions shown to the assignee. */
  description: string[];
  /** When the task must be completed. Cloud Functions schedule against this. */
  due_date_time: Timestamp;
  /** UID of the currently assigned person. Empty string when vacant. */
  assigned_to: string;
  /**
   * UID of the pre-swap assignee. Non-empty only while a swap is active.
   * week_reset() always reads this field (via effectiveAssignedTo) to determine
   * green/red status, so swap outcomes do not affect the rotation.
   * Cleared after each weekly reset.
   */
  original_assigned_to: string;
  /** Current lifecycle state. */
  state: TaskState;
  /**
   * Increments each reset cycle while the assignee is on vacation or the task
   * is vacant. Resets to 0 when the task is completed normally.
   * Compared against flat.vacation_threshold_weeks to determine short vs. long vacation.
   */
  weeks_not_cleaned: number;
  /** Position in the canonical task ring (0–8). Used for forward-scan and ring-distance calculations. */
  ring_index: number;
}

/**
 * Returns the effective assigned UID, respecting active swap overrides.
 * week_reset() must use this to determine green/red status — never assigned_to directly.
 */
export function effectiveAssignedTo(task: Task): string {
  return task.original_assigned_to !== '' ? task.original_assigned_to : task.assigned_to;
}

/** Plain-object representation for Firestore writes (omits the id). */
export type TaskData = Omit<Task, 'id'>;

/** Converts a Firestore document snapshot to a typed Task. */
export function taskFromFirestore(
  id: string,
  data: FirebaseFirestore.DocumentData,
): Task {
  return {
    id,
    name: data['name'] ?? '',
    description: data['description'] ?? [],
    due_date_time: data['due_date_time'] as Timestamp,
    assigned_to: data['assigned_to'] ?? '',
    original_assigned_to: data['original_assigned_to'] ?? '',
    state: (data['state'] as TaskState) ?? TaskState.Pending,
    weeks_not_cleaned: data['weeks_not_cleaned'] ?? 0,
    ring_index: data['ring_index'] ?? -1,
  };
}

/** Converts a Task to a plain Firestore-compatible object (excludes id). */
export function taskToFirestore(task: Task): TaskData {
  return {
    name: task.name,
    description: task.description,
    due_date_time: task.due_date_time,
    assigned_to: task.assigned_to,
    original_assigned_to: task.original_assigned_to,
    state: task.state,
    weeks_not_cleaned: task.weeks_not_cleaned,
    ring_index: task.ring_index,
  };
}
