import { Task, TaskLevel, TaskState, effectiveAssignedTo } from '../models/task';
import { Person } from '../models/person';
import {
  TASK_LEVEL_BY_RING_INDEX,
  L1_RING_INDICES,
  L2_RING_INDICES,
  L3_RING_INDICES,
  TOTAL_TASKS,
} from '../constants/taskConstants';

// ── Shared context ────────────────────────────────────────────────────────────

/**
 * Mutable working state shared across all assignment strategy steps.
 * Tasks and persons are indexed by ring_index (0–8) for O(1) access.
 */
export interface WeekResetContext {
  /** All 9 tasks, sorted by ring_index. Index = ring_index. */
  tasks: Task[];
  /** All flat members. */
  persons: Person[];
  /** vacationThresholdWeeks from flat settings. */
  vacationThresholdWeeks: number;
  /**
   * Maps ring_index → assigned UID for the *next* week.
   * Populated incrementally by each strategy step.
   * -1 sentinel means slot is not yet assigned.
   */
  nextAssignments: string[];
}

/** Creates a blank context with all next-week slots unassigned. */
export function buildWeekResetContext(
  tasks: Task[],
  persons: Person[],
  vacationThresholdWeeks: number,
): WeekResetContext {
  const nextAssignments = new Array<string>(TOTAL_TASKS).fill('');
  return { tasks, persons, vacationThresholdWeeks, nextAssignments };
}

// ── Categorisation helpers ────────────────────────────────────────────────────

/** Colour classification of a person at the end of the week. */
export enum PersonStatus {
  Green = 'green', // completed their task
  Red = 'red',     // did not complete (not_done)
  Blue = 'blue',   // on vacation
}

/** Resolved view of a person and their associated task for this week. */
export interface PersonTaskPair {
  person: Person;
  task: Task;
}

/**
 * Builds a lookup from uid → task using effectiveAssignedTo.
 */
function buildUidToTaskMap(tasks: Task[]): Map<string, Task> {
  const map = new Map<string, Task>();
  for (const task of tasks) {
    const uid = effectiveAssignedTo(task);
    if (uid !== '') {
      map.set(uid, task);
    }
  }
  return map;
}

/**
 * Classifies every person as Green, Red, or Blue.
 * Within each category the list is sorted by ascending ring_index of their
 * current task (i.e. task-ring order as required by the spec).
 */
export function categorisePersons(ctx: WeekResetContext): {
  green: PersonTaskPair[];
  red: PersonTaskPair[];
  blueShort: PersonTaskPair[];
  blueLong: PersonTaskPair[];
} {
  const uidToTask = buildUidToTaskMap(ctx.tasks);
  const green: PersonTaskPair[] = [];
  const red: PersonTaskPair[] = [];
  const blueShort: PersonTaskPair[] = [];
  const blueLong: PersonTaskPair[] = [];

  for (const person of ctx.persons) {
    const task = uidToTask.get(person.uid);
    if (!task) continue; // person has no task this week (should not happen in normal operation)

    if (person.on_vacation) {
      if (task.weeks_not_cleaned <= ctx.vacationThresholdWeeks) {
        blueShort.push({ person, task });
      } else {
        blueLong.push({ person, task });
      }
    } else if (task.state === TaskState.Completed) {
      green.push({ person, task });
    } else {
      // NotDone, Pending-but-past-deadline, or Vacant are all treated as Red
      red.push({ person, task });
    }
  }

  const byRingIndex = (a: PersonTaskPair, b: PersonTaskPair) =>
    a.task.ring_index - b.task.ring_index;

  return {
    green: green.sort(byRingIndex),
    red: red.sort(byRingIndex),
    blueShort: blueShort.sort(byRingIndex),
    blueLong: blueLong.sort(byRingIndex),
  };
}

// ── Slot helpers ──────────────────────────────────────────────────────────────

/** Returns the TaskLevel of a slot by its ring index. */
export function levelOfSlot(ringIndex: number): TaskLevel {
  return TASK_LEVEL_BY_RING_INDEX[ringIndex];
}

/** Returns all ring indices for the given level that are still unassigned. */
export function freeSlotsByLevel(ctx: WeekResetContext, level: TaskLevel): number[] {
  const indices = level === TaskLevel.L3
    ? L3_RING_INDICES
    : level === TaskLevel.L2
    ? L2_RING_INDICES
    : L1_RING_INDICES;
  return indices.filter((i) => ctx.nextAssignments[i] === '').slice();
}

/** Assigns a person to a specific ring-index slot in the context. */
export function assignSlot(ctx: WeekResetContext, ringIndex: number, uid: string): void {
  ctx.nextAssignments[ringIndex] = uid;
}

/**
 * Scans forward in the task ring from `startRingIndex` looking for the
 * next unassigned slot at the given level.
 * Returns the ring index of the found slot, or -1 if none exist.
 */
export function scanForwardForFreeSlot(
  ctx: WeekResetContext,
  startRingIndex: number,
  level: TaskLevel,
): number {
  for (let offset = 1; offset <= TOTAL_TASKS; offset++) {
    const candidate = (startRingIndex + offset) % TOTAL_TASKS;
    if (
      levelOfSlot(candidate) === level &&
      ctx.nextAssignments[candidate] === ''
    ) {
      return candidate;
    }
  }
  return -1; // no free slot of this level exists
}

/**
 * Returns the shortest forward ring distance from `fromIndex` to `toIndex`.
 * Always returns 1–TOTAL_TASKS.
 */
export function forwardRingDistance(fromIndex: number, toIndex: number): number {
  return ((toIndex - fromIndex + TOTAL_TASKS) % TOTAL_TASKS) || TOTAL_TASKS;
}

// ── Strategy interface ────────────────────────────────────────────────────────

/**
 * Strategy pattern: each step in week_reset() implements this interface.
 * execute() modifies ctx.nextAssignments in place.
 */
export interface AssignmentStrategy {
  execute(ctx: WeekResetContext): void;
}

// ── Step 1: Blue short vacation ───────────────────────────────────────────────

/**
 * Assigns short-vacation people (weeks_not_cleaned ≤ threshold) to protected slots.
 * Fills L1 first, then L2, then L3 when there are more vacation people than L1 slots.
 * Among vacation people, those who had harder tasks get the harder available slots.
 */
export class BlueShortVacationStrategy implements AssignmentStrategy {
  execute(ctx: WeekResetContext): void {
    const { blueShort } = categorisePersons(ctx);
    if (blueShort.length === 0) return;

    // Sort by original task level descending so harder-task people pick first
    const sorted = blueShort.slice().sort(
      (a, b) => levelWeight(levelOfSlot(b.task.ring_index)) - levelWeight(levelOfSlot(a.task.ring_index)),
    );

    // Preferred fill order: L1 → L2 → L3
    const preferredLevels = [TaskLevel.L1, TaskLevel.L2, TaskLevel.L3];

    for (const { person } of sorted) {
      let assigned = false;
      for (const level of preferredLevels) {
        const freeSlots = freeSlotsByLevel(ctx, level);
        if (freeSlots.length > 0) {
          assignSlot(ctx, freeSlots[0], person.uid);
          assigned = true;
          break;
        }
      }
      if (!assigned) {
        // All 9 slots taken — edge case for malformed data; skip.
      }
    }
  }
}

// ── Step 2: Green L3 ──────────────────────────────────────────────────────────

/**
 * Green L3 people scan forward for the next free L2 slot.
 * If no L2 slot is available, they stay at L3.
 */
export class GreenL3Strategy implements AssignmentStrategy {
  execute(ctx: WeekResetContext): void {
    const { green } = categorisePersons(ctx);
    const greenL3 = green.filter((p) => levelOfSlot(p.task.ring_index) === TaskLevel.L3);

    for (const { person, task } of greenL3) {
      const targetSlot = scanForwardForFreeSlot(ctx, task.ring_index, TaskLevel.L2);
      if (targetSlot !== -1) {
        assignSlot(ctx, targetSlot, person.uid);
      } else {
        // No free L2 — stay at L3 (same or another free L3)
        const freeL3 = freeSlotsByLevel(ctx, TaskLevel.L3);
        if (freeL3.length > 0) {
          assignSlot(ctx, freeL3[0], person.uid);
        }
      }
    }
  }
}

// ── Step 3: Green L2 ──────────────────────────────────────────────────────────

/**
 * Green L2 people scan forward for the next free L1 slot.
 * If no L1 slot is available, they stay at L2.
 */
export class GreenL2Strategy implements AssignmentStrategy {
  execute(ctx: WeekResetContext): void {
    const { green } = categorisePersons(ctx);
    const greenL2 = green.filter((p) => levelOfSlot(p.task.ring_index) === TaskLevel.L2);

    for (const { person, task } of greenL2) {
      const targetSlot = scanForwardForFreeSlot(ctx, task.ring_index, TaskLevel.L1);
      if (targetSlot !== -1) {
        assignSlot(ctx, targetSlot, person.uid);
      } else {
        const freeL2 = freeSlotsByLevel(ctx, TaskLevel.L2);
        if (freeL2.length > 0) {
          assignSlot(ctx, freeL2[0], person.uid);
        }
      }
    }
  }
}

// ── Step 4: Red L3 ────────────────────────────────────────────────────────────

/**
 * Red L3 people stay at L3.
 * They take their same task if unassigned; otherwise any other free L3.
 */
export class RedL3Strategy implements AssignmentStrategy {
  execute(ctx: WeekResetContext): void {
    const { red } = categorisePersons(ctx);
    const redL3 = red.filter((p) => levelOfSlot(p.task.ring_index) === TaskLevel.L3);

    for (const { person, task } of redL3) {
      if (ctx.nextAssignments[task.ring_index] === '') {
        assignSlot(ctx, task.ring_index, person.uid);
      } else {
        const freeL3 = freeSlotsByLevel(ctx, TaskLevel.L3);
        if (freeL3.length > 0) {
          assignSlot(ctx, freeL3[0], person.uid);
        }
        // If no free L3 (all taken by Blue), the Red L3 person is left unassigned;
        // a later catch-all step handles that edge case.
      }
    }
  }
}

// ── Step 5: Red L2 ────────────────────────────────────────────────────────────

/**
 * Red L2 people move up to any free L3.
 * If all L3 slots are full, they stay at their current L2 task.
 */
export class RedL2Strategy implements AssignmentStrategy {
  execute(ctx: WeekResetContext): void {
    const { red } = categorisePersons(ctx);
    const redL2 = red.filter((p) => levelOfSlot(p.task.ring_index) === TaskLevel.L2);

    for (const { person, task } of redL2) {
      const freeL3 = freeSlotsByLevel(ctx, TaskLevel.L3);
      if (freeL3.length > 0) {
        assignSlot(ctx, freeL3[0], person.uid);
      } else {
        // Stay at L2 — re-use same slot if free, else any free L2
        if (ctx.nextAssignments[task.ring_index] === '') {
          assignSlot(ctx, task.ring_index, person.uid);
        } else {
          const freeL2 = freeSlotsByLevel(ctx, TaskLevel.L2);
          if (freeL2.length > 0) {
            assignSlot(ctx, freeL2[0], person.uid);
          }
        }
      }
    }
  }
}

// ── Step 6: Red L1 ────────────────────────────────────────────────────────────

/**
 * Red L1 people move up to any free L2.
 * If all L2 slots are full, they stay at their current L1 task.
 * Edge case: if L1 is also full (e.g. all Green L2 took L1 slots), the person
 * falls through to whichever slot remains — ensuring no one is left unassigned.
 */
export class RedL1Strategy implements AssignmentStrategy {
  execute(ctx: WeekResetContext): void {
    const { red } = categorisePersons(ctx);
    const redL1 = red.filter((p) => levelOfSlot(p.task.ring_index) === TaskLevel.L1);

    for (const { person, task } of redL1) {
      const freeL2 = freeSlotsByLevel(ctx, TaskLevel.L2);
      if (freeL2.length > 0) {
        assignSlot(ctx, freeL2[0], person.uid);
      } else {
        // Stay at L1: prefer same task, then any other L1
        if (ctx.nextAssignments[task.ring_index] === '') {
          assignSlot(ctx, task.ring_index, person.uid);
        } else {
          const freeL1 = freeSlotsByLevel(ctx, TaskLevel.L1);
          if (freeL1.length > 0) {
            assignSlot(ctx, freeL1[0], person.uid);
          } else {
            // L1 also full (edge case: Green L2 filled all L1 slots).
            // Fall through to any free slot so no one is left unassigned.
            const anyFree = ctx.nextAssignments.findIndex((uid) => uid === '');
            if (anyFree !== -1) {
              assignSlot(ctx, anyFree, person.uid);
            }
          }
        }
      }
    }
  }
}

// ── Step 7: Green L1 ─────────────────────────────────────────────────────────

/**
 * Green L1 people fill remaining slots using shortest forward ring distance.
 * For each free slot, find the unassigned Green L1 person closest forward in the ring.
 */
export class GreenL1Strategy implements AssignmentStrategy {
  execute(ctx: WeekResetContext): void {
    const { green } = categorisePersons(ctx);
    const unassignedGreenL1 = green
      .filter((p) => levelOfSlot(p.task.ring_index) === TaskLevel.L1)
      .filter((p) => !ctx.nextAssignments.includes(p.person.uid));

    if (unassignedGreenL1.length === 0) return;

    // Collect all currently free slots
    const freeSlots = ctx.nextAssignments
      .map((uid, index) => (uid === '' ? index : -1))
      .filter((i) => i !== -1);

    // Greedy: for each free slot, assign the Green L1 person with shortest forward distance
    const remainingPersons = unassignedGreenL1.slice();

    for (const slotIndex of freeSlots) {
      if (remainingPersons.length === 0) break;

      let bestPersonIndex = 0;
      let bestDistance = forwardRingDistance(
        remainingPersons[0].task.ring_index,
        slotIndex,
      );

      for (let i = 1; i < remainingPersons.length; i++) {
        const dist = forwardRingDistance(remainingPersons[i].task.ring_index, slotIndex);
        if (dist < bestDistance) {
          bestDistance = dist;
          bestPersonIndex = i;
        }
      }

      assignSlot(ctx, slotIndex, remainingPersons[bestPersonIndex].person.uid);
      remainingPersons.splice(bestPersonIndex, 1);
    }
  }
}

// ── Step 8: Blue long vacation ────────────────────────────────────────────────

/**
 * Long-vacation people fill whatever slots remain last.
 * Their slots are unprotected — Green people can take them.
 */
export class BlueLongVacationStrategy implements AssignmentStrategy {
  execute(ctx: WeekResetContext): void {
    const { blueLong } = categorisePersons(ctx);
    if (blueLong.length === 0) return;

    const freeSlots = ctx.nextAssignments
      .map((uid, index) => (uid === '' ? index : -1))
      .filter((i) => i !== -1);

    let slotCursor = 0;
    for (const { person } of blueLong) {
      if (slotCursor >= freeSlots.length) break;
      assignSlot(ctx, freeSlots[slotCursor], person.uid);
      slotCursor++;
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Numeric weight of a level (higher = harder) for sorting comparisons. */
function levelWeight(level: TaskLevel): number {
  switch (level) {
    case TaskLevel.L3: return 3;
    case TaskLevel.L2: return 2;
    case TaskLevel.L1: return 1;
  }
}
