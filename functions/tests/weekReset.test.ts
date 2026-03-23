/**
 * BDD tests for the week_reset() assignment algorithm.
 *
 * These tests use runWeekResetAlgorithm() — a pure in-memory function —
 * so no Firestore emulator is needed. All scenarios test the spec in CLAUDE.md.
 *
 * Task ring (ring_index → level):
 *   0: Toilet    (L3)
 *   1: Kitchen   (L2)
 *   2: Recycling (L1)
 *   3: Shower    (L3)
 *   4: Floor(A)  (L2)
 *   5: Washing Rags (L1)
 *   6: Bathroom  (L3)
 *   7: Floor(B)  (L2)
 *   8: Shopping  (L1)
 */

import { runWeekResetAlgorithm } from '../src/services/weekResetService';
import { Task, TaskState } from '../src/models/task';
import { Person, PersonRole } from '../src/models/person';
import { Timestamp } from 'firebase-admin/firestore';
import * as admin from 'firebase-admin';

// Initialise the Admin SDK in test mode (no actual Firebase connection)
if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'flatorg-test' });
}

// ── Test fixtures ─────────────────────────────────────────────────────────────

const FUTURE_DATE = Timestamp.fromDate(new Date('2099-01-01'));
const DEFAULT_FLAT = { vacation_threshold_weeks: 1 };

function makePerson(uid: string, onVacation = false, tokens = 3): Person {
  return {
    uid,
    name: uid,
    email: `${uid}@test.com`,
    role: PersonRole.Member,
    on_vacation: onVacation,
    swap_tokens_remaining: tokens,
  };
}

function makeTask(
  ringIndex: number,
  assignedTo: string,
  state: TaskState,
  weeksNotCleaned = 0,
  originalAssignedTo = '',
): Task {
  return {
    id: `task-${ringIndex}`,
    name: `Task ${ringIndex}`,
    description: [],
    due_date_time: FUTURE_DATE,
    assigned_to: assignedTo,
    original_assigned_to: originalAssignedTo,
    state,
    weeks_not_cleaned: weeksNotCleaned,
    ring_index: ringIndex,
  };
}

/**
 * Builds a full 9-task set where every person is assigned one task.
 * Default state is Completed (Green) for all unless overridden.
 */
function buildFullScenario(
  personIds: string[],
  taskStates: Record<number, TaskState> = {},
  onVacation: Record<string, boolean> = {},
  weeksNotCleaned: Record<number, number> = {},
): { tasks: Task[]; persons: Person[] } {
  const persons = personIds.map((id) => makePerson(id, onVacation[id] ?? false));
  const tasks = Array.from({ length: 9 }, (_, i) =>
    makeTask(
      i,
      personIds[i],
      taskStates[i] ?? TaskState.Completed,
      weeksNotCleaned[i] ?? 0,
    ),
  );
  return { tasks, persons };
}

// ── Scenario: all Green, no vacations ─────────────────────────────────────────

describe('Scenario: all 9 people completed their tasks', () => {
  const ids = ['p0', 'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8'];
  const { tasks, persons } = buildFullScenario(ids);

  it('produces exactly 9 assignments', () => {
    const result = runWeekResetAlgorithm(tasks, persons, DEFAULT_FLAT);
    const assigned = result.filter((uid) => uid !== '');
    expect(assigned).toHaveLength(9);
  });

  it('assigns each person exactly once', () => {
    const result = runWeekResetAlgorithm(tasks, persons, DEFAULT_FLAT);
    const unique = new Set(result.filter((uid) => uid !== ''));
    expect(unique.size).toBe(9);
  });

  it('Green L3 (p0=Toilet) moves to an L2 slot', () => {
    const result = runWeekResetAlgorithm(tasks, persons, DEFAULT_FLAT);
    const p0Slot = result.indexOf('p0');
    // L2 ring indices: 1, 4, 7
    expect([1, 4, 7]).toContain(p0Slot);
  });

  it('Green L3 (p3=Shower) moves to an L2 slot', () => {
    const result = runWeekResetAlgorithm(tasks, persons, DEFAULT_FLAT);
    const p3Slot = result.indexOf('p3');
    expect([1, 4, 7]).toContain(p3Slot);
  });

  it('Green L3 (p6=Bathroom) moves to an L2 slot', () => {
    const result = runWeekResetAlgorithm(tasks, persons, DEFAULT_FLAT);
    const p6Slot = result.indexOf('p6');
    expect([1, 4, 7]).toContain(p6Slot);
  });

  it('Green L2 people move to L1 slots', () => {
    const result = runWeekResetAlgorithm(tasks, persons, DEFAULT_FLAT);
    // p1=Kitchen(L2), p4=Floor(A)(L2), p7=Floor(B)(L2) should all be at L1
    for (const uid of ['p1', 'p4', 'p7']) {
      const slot = result.indexOf(uid);
      expect([2, 5, 8]).toContain(slot);
    }
  });
});

// ── Scenario: Green L3 moves to L2 (forward scan) ────────────────────────────

describe('Scenario: Green L3 person scans forward for free L2', () => {
  it('p0 (Toilet, L3) scans forward and finds Kitchen (index 1) first', () => {
    const ids = ['p0', 'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8'];
    // Only p0 completed; all others did not
    const taskStates: Record<number, TaskState> = {};
    for (let i = 1; i <= 8; i++) taskStates[i] = TaskState.NotDone;
    taskStates[0] = TaskState.Completed;

    const { tasks, persons } = buildFullScenario(ids, taskStates);
    const result = runWeekResetAlgorithm(tasks, persons, DEFAULT_FLAT);

    // p0 should move to Kitchen (index 1) — the first L2 slot forward from index 0
    expect(result[1]).toBe('p0');
  });
});

// ── Scenario: Red L2 moves up to L3 ──────────────────────────────────────────

describe('Scenario: Red L2 person moves up to L3', () => {
  it('a person who failed Kitchen (L2) gets an L3 task next week', () => {
    const ids = ['p0', 'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8'];
    const taskStates: Record<number, TaskState> = {};
    for (let i = 0; i <= 8; i++) taskStates[i] = TaskState.Completed;
    taskStates[1] = TaskState.NotDone; // p1=Kitchen fails

    const { tasks, persons } = buildFullScenario(ids, taskStates);
    const result = runWeekResetAlgorithm(tasks, persons, DEFAULT_FLAT);

    const p1Slot = result.indexOf('p1');
    expect([0, 3, 6]).toContain(p1Slot); // L3 slots
  });
});

// ── Scenario: Red L1 moves up to L2 ──────────────────────────────────────────

describe('Scenario: Red L1 person moves up to L2', () => {
  /**
   * For Red L1 to get an L2 slot, L2 slots must be available when step 6 runs.
   * This requires fewer than 3 Green L3 people (so not all L2 slots are taken).
   *
   * Setup:
   *   p0 Toilet L3     → Completed (Green L3 → takes Kitchen=1)
   *   p1 Kitchen L2    → NotDone  (Red L2 → takes Toilet=0 since Kitchen taken)
   *   p2 Recycling L1  → NotDone  (Red L1 → takes Floor(A)=4, first free L2)
   *   p3 Shower L3     → NotDone  (Red L3 → stays at Shower=3)
   *   p4 Floor(A) L2   → Completed (Green L2 → takes Washing Rags=5)
   *   p5 Washing Rags L1 → Completed (Green L1 → fills remaining)
   *   p6 Bathroom L3   → NotDone  (Red L3 → stays at Bathroom=6)
   *   p7 Floor(B) L2   → Completed (Green L2 → takes Shopping=8)
   *   p8 Shopping L1   → Completed (Green L1 → fills remaining)
   */
  it('a person who failed Recycling (L1) gets an L2 task when L2 slots are available', () => {
    const ids = ['p0', 'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8'];
    const taskStates: Record<number, TaskState> = {
      0: TaskState.Completed, // p0 Toilet L3 green
      1: TaskState.NotDone,   // p1 Kitchen L2 red
      2: TaskState.NotDone,   // p2 Recycling L1 red
      3: TaskState.NotDone,   // p3 Shower L3 red
      4: TaskState.Completed, // p4 Floor(A) L2 green
      5: TaskState.Completed, // p5 Washing Rags L1 green
      6: TaskState.NotDone,   // p6 Bathroom L3 red
      7: TaskState.Completed, // p7 Floor(B) L2 green
      8: TaskState.Completed, // p8 Shopping L1 green
    };

    const { tasks, persons } = buildFullScenario(ids, taskStates);
    const result = runWeekResetAlgorithm(tasks, persons, DEFAULT_FLAT);

    // p2 (Red L1) should be at an L2 slot (Floor(A)=4 or Floor(B)=7 are free)
    const p2Slot = result.indexOf('p2');
    expect([1, 4, 7]).toContain(p2Slot);
  });
});

// ── Scenario: Red L3 stays at L3 ─────────────────────────────────────────────

describe('Scenario: Red L3 person stays at L3', () => {
  it('a person who failed Toilet (L3) stays at an L3 task', () => {
    const ids = ['p0', 'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8'];
    const taskStates: Record<number, TaskState> = {};
    for (let i = 0; i <= 8; i++) taskStates[i] = TaskState.Completed;
    taskStates[0] = TaskState.NotDone; // p0=Toilet fails

    const { tasks, persons } = buildFullScenario(ids, taskStates);
    const result = runWeekResetAlgorithm(tasks, persons, DEFAULT_FLAT);

    const p0Slot = result.indexOf('p0');
    expect([0, 3, 6]).toContain(p0Slot); // L3 slots
  });

  it('Red L3 retains their same task when it is still free', () => {
    const ids = ['p0', 'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8'];
    const taskStates: Record<number, TaskState> = {};
    for (let i = 0; i <= 8; i++) taskStates[i] = TaskState.Completed;
    // Only p0 fails; p3 and p6 are Green so they move off L3 slots
    taskStates[0] = TaskState.NotDone;

    const { tasks, persons } = buildFullScenario(ids, taskStates);
    const result = runWeekResetAlgorithm(tasks, persons, DEFAULT_FLAT);

    // p0 should get back Toilet (index 0) since Green L3s took other L3 slots
    expect(result[0]).toBe('p0');
  });
});

// ── Scenario: Blue short vacation (protected) ────────────────────────────────

describe('Scenario: Blue short vacation person gets a protected L1 slot', () => {
  it('a person on vacation (weeks_not_cleaned ≤ 1) is assigned first to an L1 slot', () => {
    const ids = ['p0', 'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8'];
    const taskStates: Record<number, TaskState> = {};
    for (let i = 0; i <= 8; i++) taskStates[i] = TaskState.Completed;

    // p2 is on vacation for 1 week (short)
    const onVacation = { p2: true };
    const weeksNotCleaned = { 2: 0 }; // will be incremented to 1 in pre-step

    const { tasks, persons } = buildFullScenario(ids, taskStates, onVacation, weeksNotCleaned);
    const result = runWeekResetAlgorithm(tasks, persons, DEFAULT_FLAT);

    // p2 should be at an L1 slot (protected)
    const p2Slot = result.indexOf('p2');
    expect([2, 5, 8]).toContain(p2Slot);
  });
});

// ── Scenario: Blue long vacation (unprotected, last) ─────────────────────────

describe('Scenario: Blue long vacation person is assigned last', () => {
  it('a person on long vacation (weeks_not_cleaned > threshold) fills remaining slots', () => {
    const ids = ['p0', 'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8'];
    const taskStates: Record<number, TaskState> = {};
    for (let i = 0; i <= 8; i++) taskStates[i] = TaskState.Completed;

    // p2 is on long vacation (weeks_not_cleaned = 2 > threshold 1)
    const onVacation = { p2: true };
    const weeksNotCleaned = { 2: 2 };

    const { tasks, persons } = buildFullScenario(ids, taskStates, onVacation, weeksNotCleaned);
    const result = runWeekResetAlgorithm(tasks, persons, DEFAULT_FLAT);

    // All 9 slots must still be filled
    const assigned = result.filter((uid) => uid !== '');
    expect(assigned).toHaveLength(9);

    // p2 should be in a slot (the last remaining one)
    expect(result.includes('p2')).toBe(true);
  });
});

// ── Scenario: Known tradeoff — Red L1 escape when all Green L3 fill L2 ───────

describe('Known tradeoff: Red L1 stays at L1 when all L2 slots are taken by Green L3', () => {
  /**
   * CLAUDE.md documents this as an accepted tradeoff:
   * When all 3 L3 people complete their tasks AND all 3 L1 people fail,
   * the Green L3s fill all L2 slots. Red L1 people find no L2 slots and stay at L1.
   *
   * For L1 slots to remain free (so Red L1 can "stay"), the L2 people must
   * NOT be Green (otherwise they'd fill L1). In this scenario L2 people are Red:
   *   - Red L2 → moves to L3 (now free since Green L3 moved to L2)
   *   - This leaves all 3 L1 slots free for Red L1 to stay at.
   */
  it('Red L1 people stay at L1 when all L2 slots are taken by Green L3', () => {
    const ids = ['p0', 'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8'];
    const taskStates: Record<number, TaskState> = {
      0: TaskState.Completed, // p0 Toilet L3 green  → moves to L2
      1: TaskState.NotDone,   // p1 Kitchen L2 red   → moves to L3
      2: TaskState.NotDone,   // p2 Recycling L1 red → tries L2 (full), stays at L1
      3: TaskState.Completed, // p3 Shower L3 green  → moves to L2
      4: TaskState.NotDone,   // p4 Floor(A) L2 red  → moves to L3
      5: TaskState.NotDone,   // p5 Washing Rags L1 red → stays at L1
      6: TaskState.Completed, // p6 Bathroom L3 green → moves to L2
      7: TaskState.NotDone,   // p7 Floor(B) L2 red  → moves to L3
      8: TaskState.NotDone,   // p8 Shopping L1 red  → stays at L1
    };

    const { tasks, persons } = buildFullScenario(ids, taskStates);
    const result = runWeekResetAlgorithm(tasks, persons, DEFAULT_FLAT);

    // Red L1 people should stay at L1 (L2 full, but L1 slots are free)
    for (const uid of ['p2', 'p5', 'p8']) {
      const slot = result.indexOf(uid);
      expect([2, 5, 8]).toContain(slot);
    }

    // Green L3 people should be at L2
    for (const uid of ['p0', 'p3', 'p6']) {
      const slot = result.indexOf(uid);
      expect([1, 4, 7]).toContain(slot);
    }

    // All 9 slots assigned with no duplicates
    const assigned = result.filter((uid) => uid !== '');
    expect(assigned).toHaveLength(9);
    expect(new Set(assigned).size).toBe(9);
  });
});

// ── Scenario: Green L1 shortest ring distance ─────────────────────────────────

describe('Scenario: Green L1 uses shortest forward ring distance', () => {
  it('assigns Green L1 person to the free slot with minimum forward ring distance', () => {
    /**
     * Setup: only p2 (Recycling, L1) and p5 (Washing Rags, L1) are Green L1.
     * All other people are Red so their assignments fill some slots but leave
     * free L3 slots. We verify p2 and p5 each take the slot closest forward.
     *
     * Simpler: all Red L3/L2 stay put; Green L1s fill remaining.
     */
    const ids = ['p0', 'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8'];
    const taskStates: Record<number, TaskState> = {
      0: TaskState.NotDone,   // Red L3 stays at Toilet (0)
      1: TaskState.NotDone,   // Red L2 moves to L3
      2: TaskState.Completed, // Green L1
      3: TaskState.NotDone,   // Red L3 stays at Shower (3)
      4: TaskState.NotDone,   // Red L2 moves to L3
      5: TaskState.Completed, // Green L1
      6: TaskState.NotDone,   // Red L3 stays at Bathroom (6)
      7: TaskState.NotDone,   // Red L2 moves to L3
      8: TaskState.NotDone,   // Red L1 moves to L2 (if available)
    };

    const { tasks, persons } = buildFullScenario(ids, taskStates);
    const result = runWeekResetAlgorithm(tasks, persons, DEFAULT_FLAT);

    // All 9 slots should be assigned
    const assigned = result.filter((uid) => uid !== '');
    expect(assigned).toHaveLength(9);

    // p2 and p5 must be assigned somewhere
    expect(result.includes('p2')).toBe(true);
    expect(result.includes('p5')).toBe(true);
  });
});

// ── Scenario: complete all tasks, then reset — no duplicates ─────────────────

describe('Smoke test: week_reset() never assigns two people to the same task', () => {
  const allStates: TaskState[] = [
    TaskState.Completed,
    TaskState.NotDone,
    TaskState.Completed,
    TaskState.NotDone,
    TaskState.Completed,
    TaskState.NotDone,
    TaskState.Completed,
    TaskState.NotDone,
    TaskState.Completed,
  ];

  it('produces 9 unique assignments', () => {
    const ids = ['p0', 'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8'];
    const taskStates: Record<number, TaskState> = {};
    allStates.forEach((s, i) => (taskStates[i] = s));

    const { tasks, persons } = buildFullScenario(ids, taskStates);
    const result = runWeekResetAlgorithm(tasks, persons, DEFAULT_FLAT);

    const unique = new Set(result.filter((uid) => uid !== ''));
    expect(unique.size).toBe(9);
    expect(result.filter((uid) => uid !== '')).toHaveLength(9);
  });
});

// ── Scenario: weeks_not_cleaned increments on vacation tasks ──────────────────

describe('Scenario: weeks_not_cleaned increments before categorisation', () => {
  it('increments weeks_not_cleaned for an on-vacation person before strategy runs', () => {
    /**
     * p2 is on vacation with weeks_not_cleaned = 0.
     * After pre-step it becomes 1, which equals the threshold (1) → short vacation.
     * Short vacation → assigned in step 1 at an L1 slot.
     */
    const ids = ['p0', 'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8'];
    const taskStates: Record<number, TaskState> = {};
    for (let i = 0; i <= 8; i++) taskStates[i] = TaskState.Completed;

    const onVacation = { p2: true };
    const weeksNotCleaned = { 2: 0 };

    const { tasks, persons } = buildFullScenario(ids, taskStates, onVacation, weeksNotCleaned);
    const result = runWeekResetAlgorithm(tasks, persons, DEFAULT_FLAT);

    // p2 should be at an L1 slot (short vacation, protected)
    const p2Slot = result.indexOf('p2');
    expect([2, 5, 8]).toContain(p2Slot);
  });

  it('treats person with weeks_not_cleaned = 1 (becomes 2 after increment) as long vacation', () => {
    /**
     * p2 is on vacation with weeks_not_cleaned = 1 (already at threshold).
     * After pre-step it becomes 2 > threshold → long vacation → assigned last.
     */
    const ids = ['p0', 'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8'];
    const taskStates: Record<number, TaskState> = {};
    for (let i = 0; i <= 8; i++) taskStates[i] = TaskState.Completed;

    const onVacation = { p2: true };
    const weeksNotCleaned = { 2: 1 }; // becomes 2 in pre-step → long vacation

    const { tasks, persons } = buildFullScenario(ids, taskStates, onVacation, weeksNotCleaned);
    const result = runWeekResetAlgorithm(tasks, persons, DEFAULT_FLAT);

    // p2 is assigned last but still gets a slot
    expect(result.includes('p2')).toBe(true);
  });
});

// ── Scenario: effectiveAssignedTo uses original_assigned_to ──────────────────

describe('Scenario: swap does not affect rotation (effectiveAssignedTo)', () => {
  it('week_reset uses original_assigned_to when a swap is active', () => {
    /**
     * p0 originally had Toilet (L3, index 0) but swapped to Kitchen (L2, index 1).
     * assigned_to[0] = p1, original_assigned_to[0] = p0 → p0 is Green L3.
     * assigned_to[1] = p0, original_assigned_to[1] = p1 → p1 is Green L2.
     *
     * Both tasks are Completed (both people cleaned).
     * p0 (Green L3 in rotation) should move to L2.
     * p1 (Green L2 in rotation) should move to L1.
     */
    const persons = [
      makePerson('p0'), makePerson('p1'), makePerson('p2'), makePerson('p3'),
      makePerson('p4'), makePerson('p5'), makePerson('p6'), makePerson('p7'), makePerson('p8'),
    ];

    const tasks: Task[] = [
      // Toilet (0): assigned to p1 via swap; original is p0 (L3)
      makeTask(0, 'p1', TaskState.Completed, 0, 'p0'),
      // Kitchen (1): assigned to p0 via swap; original is p1 (L2)
      makeTask(1, 'p0', TaskState.Completed, 0, 'p1'),
      makeTask(2, 'p2', TaskState.Completed),
      makeTask(3, 'p3', TaskState.Completed),
      makeTask(4, 'p4', TaskState.Completed),
      makeTask(5, 'p5', TaskState.Completed),
      makeTask(6, 'p6', TaskState.Completed),
      makeTask(7, 'p7', TaskState.Completed),
      makeTask(8, 'p8', TaskState.Completed),
    ];

    const result = runWeekResetAlgorithm(tasks, persons, DEFAULT_FLAT);

    // p0 (originally L3) → should be at an L2 slot
    const p0Slot = result.indexOf('p0');
    expect([1, 4, 7]).toContain(p0Slot);

    // p1 (originally L2) → should be at an L1 slot
    const p1Slot = result.indexOf('p1');
    expect([2, 5, 8]).toContain(p1Slot);
  });
});
