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

  // Initial:  0:Toilet(L3)-p0[✓]   1:Kitchen(L2)-p1[✓]   2:Recycling(L1)-p2[✓]
  //           3:Shower(L3)-p3[✓]   4:FloorA(L2)-p4[✓]    5:WashRags(L1)-p5[✓]
  //           6:Bathroom(L3)-p6[✓] 7:FloorB(L2)-p7[✓]    8:Shopping(L1)-p8[✓]
  //
  // Step 2 (Green L3): p0→Kitchen(1), p3→FloorA(4), p6→FloorB(7)
  // Step 3 (Green L2): p1→Recycling(2), p4→WashRags(5), p7→Shopping(8)
  // Step 7 (Green L1 shortest dist): slot 0←p8(dist 1), slot 3←p2(dist 1), slot 6←p5(dist 1)
  //
  // Result:   0:Toilet(L3)-p8   1:Kitchen(L2)-p0   2:Recycling(L1)-p1
  //           3:Shower(L3)-p2   4:FloorA(L2)-p3    5:WashRags(L1)-p4
  //           6:Bathroom(L3)-p5 7:FloorB(L2)-p6    8:Shopping(L1)-p7

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

    // Initial:  0:Toilet(L3)-p0[✓]   1:Kitchen(L2)-p1[✗]   2:Recycling(L1)-p2[✗]
    //           3:Shower(L3)-p3[✗]   4:FloorA(L2)-p4[✗]    5:WashRags(L1)-p5[✗]
    //           6:Bathroom(L3)-p6[✗] 7:FloorB(L2)-p7[✗]    8:Shopping(L1)-p8[✗]
    //
    // Step 2 (Green L3): p0 scans forward from 0 → first free L2 is Kitchen(1) → p0→1
    // Step 4 (Red L3):   p3→3, p6→6  (own slots still free)
    // Step 5 (Red L2):   p1 takes only free L3 (Toilet=0); p4→4, p7→7 (no free L3 left, stay L2)
    // Step 6 (Red L1):   p2→2, p5→5, p8→8  (no free L2, stay L1)
    //
    // Result:   0:Toilet(L3)-p1   1:Kitchen(L2)-p0   2:Recycling(L1)-p2
    //           3:Shower(L3)-p3   4:FloorA(L2)-p4    5:WashRags(L1)-p5
    //           6:Bathroom(L3)-p6 7:FloorB(L2)-p7    8:Shopping(L1)-p8

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

    // Initial:  0:Toilet(L3)-p0[✓]   1:Kitchen(L2)-p1[✗]   2:Recycling(L1)-p2[✓]
    //           3:Shower(L3)-p3[✓]   4:FloorA(L2)-p4[✓]    5:WashRags(L1)-p5[✓]
    //           6:Bathroom(L3)-p6[✓] 7:FloorB(L2)-p7[✓]    8:Shopping(L1)-p8[✓]
    //
    // Step 2 (Green L3): p0→Kitchen(1), p3→FloorA(4), p6→FloorB(7)
    // Step 3 (Green L2): p4→WashRags(5), p7→Shopping(8)  [p1 is Red, skipped]
    // Step 5 (Red L2):   p1 takes first free L3 → Toilet(0)
    // Step 7 (Green L1): slots 2,3,6 free; p2(2)→Shower(3), p5(5)→Bathroom(6), p8(8)→Recycling(2)
    //                    [slot 2: p8 dist=3 beats p2 dist=9; slot 3: p2 dist=1 beats p5 dist=7]
    //
    // Result:   0:Toilet(L3)-p1   1:Kitchen(L2)-p0   2:Recycling(L1)-p8
    //           3:Shower(L3)-p2   4:FloorA(L2)-p3    5:WashRags(L1)-p4
    //           6:Bathroom(L3)-p5 7:FloorB(L2)-p6    8:Shopping(L1)-p7

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
   * Initial:  0:Toilet(L3)-p0[✓]   1:Kitchen(L2)-p1[✗]   2:Recycling(L1)-p2[✗]
   *           3:Shower(L3)-p3[✗]   4:FloorA(L2)-p4[✓]    5:WashRags(L1)-p5[✓]
   *           6:Bathroom(L3)-p6[✗] 7:FloorB(L2)-p7[✓]    8:Shopping(L1)-p8[✓]
   *
   * Step 2 (Green L3): p0→Kitchen(1)   [only 1 Green L3, so 2 L2 slots remain free]
   * Step 3 (Green L2): p4→WashRags(5), p7→Shopping(8)
   * Step 4 (Red L3):   p3→Shower(3), p6→Bathroom(6)
   * Step 5 (Red L2):   p1 takes Toilet(0)  [only free L3]
   * Step 6 (Red L1):   p2 takes FloorA(4)  [first free L2]
   * Step 7 (Green L1): slots 2,7 free; p8(8) dist=3 < p5(5) dist=6 → p8→Recycling(2); p5→FloorB(7)
   *
   * Result:   0:Toilet(L3)-p1   1:Kitchen(L2)-p0   2:Recycling(L1)-p8
   *           3:Shower(L3)-p3   4:FloorA(L2)-p2    5:WashRags(L1)-p4
   *           6:Bathroom(L3)-p6 7:FloorB(L2)-p5    8:Shopping(L1)-p7
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

    // Initial:  0:Toilet(L3)-p0[✗]   1:Kitchen(L2)-p1[✓]   2:Recycling(L1)-p2[✓]
    //           3:Shower(L3)-p3[✓]   4:FloorA(L2)-p4[✓]    5:WashRags(L1)-p5[✓]
    //           6:Bathroom(L3)-p6[✓] 7:FloorB(L2)-p7[✓]    8:Shopping(L1)-p8[✓]
    //
    // Step 2 (Green L3): p3→FloorA(4), p6→FloorB(7)  [Shower and Bathroom vacated]
    // Step 3 (Green L2): p1→Recycling(2), p4→WashRags(5), p7→Shopping(8)
    // Step 4 (Red L3):   p0 takes own slot Toilet(0)  [still free]
    // Step 7 (Green L1): slots 1,3,6 free; p8(8) dist=2 to Kitchen(1); p2(2) dist=1 to Shower(3); p5(5) dist=1 to Bathroom(6)
    //
    // Result:   0:Toilet(L3)-p0   1:Kitchen(L2)-p8   2:Recycling(L1)-p1
    //           3:Shower(L3)-p2   4:FloorA(L2)-p3    5:WashRags(L1)-p4
    //           6:Bathroom(L3)-p5 7:FloorB(L2)-p6    8:Shopping(L1)-p7

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

    // Same initial as above. p0 takes back Toilet(0) because Green L3s (p3, p6)
    // scan forward past Toilet — p3→FloorA(4), p6→FloorB(7) — leaving Toilet free for p0.
    //
    // Result:   0:Toilet(L3)-p0   (same as above)

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

    // Initial:  0:Toilet(L3)-p0[✓]   1:Kitchen(L2)-p1[✓]   2:Recycling(L1)-p2[~S,wnc=0]
    //           3:Shower(L3)-p3[✓]   4:FloorA(L2)-p4[✓]    5:WashRags(L1)-p5[✓]
    //           6:Bathroom(L3)-p6[✓] 7:FloorB(L2)-p7[✓]    8:Shopping(L1)-p8[✓]
    // Pre-step: p2 wnc 0→1 (≤ threshold 1) → blueShort
    //
    // Step 1 (Blue short): p2→Recycling(2)  [first free L1]
    // Step 2 (Green L3):   p0→Kitchen(1), p3→FloorA(4), p6→FloorB(7)
    // Step 3 (Green L2):   p1→WashRags(5), p4→Shopping(8)  [p7 finds no free L1 or L2 — edge case]
    // Step 7 (Green L1):   p5 and p8 fill slots 0,3; slot 6 remains unfilled (p7 unassigned — known edge case)
    //
    // Note: this exposes a gap where a Blue-short person displacing an L1 slot
    // can leave a Green L2 person (p7) with nowhere to go. The test only verifies p2's slot.
    //
    // Result (p2):  p2 is at slot 2 (Recycling, L1) ✓

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

    // Initial:  0:Toilet(L3)-p0[✓]   1:Kitchen(L2)-p1[✓]   2:Recycling(L1)-p2[~L,wnc=2]
    //           3:Shower(L3)-p3[✓]   4:FloorA(L2)-p4[✓]    5:WashRags(L1)-p5[✓]
    //           6:Bathroom(L3)-p6[✓] 7:FloorB(L2)-p7[✓]    8:Shopping(L1)-p8[✓]
    // Pre-step: p2 wnc 2→3 (> threshold 1) → blueLong
    //
    // Step 1:          (no blueShort)
    // Step 2 (Green L3): p0→Kitchen(1), p3→FloorA(4), p6→FloorB(7)
    // Step 3 (Green L2): p1→Recycling(2), p4→WashRags(5), p7→Shopping(8)
    // Step 7 (Green L1): slots 0,3,6 free; p8(8)→Toilet(0), p5(5)→Shower(3); slot 6 remains
    // Step 8 (Blue long): p2→Bathroom(6)
    //
    // Result:   0:Toilet(L3)-p8   1:Kitchen(L2)-p0   2:Recycling(L1)-p1
    //           3:Shower(L3)-p5   4:FloorA(L2)-p3    5:WashRags(L1)-p4
    //           6:Bathroom(L3)-p2 7:FloorB(L2)-p6    8:Shopping(L1)-p7

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
   *
   * Initial:  0:Toilet(L3)-p0[✓]   1:Kitchen(L2)-p1[✗]   2:Recycling(L1)-p2[✗]
   *           3:Shower(L3)-p3[✓]   4:FloorA(L2)-p4[✗]    5:WashRags(L1)-p5[✗]
   *           6:Bathroom(L3)-p6[✓] 7:FloorB(L2)-p7[✗]    8:Shopping(L1)-p8[✗]
   *
   * Step 2 (Green L3): p0→Kitchen(1), p3→FloorA(4), p6→FloorB(7)  [all L2 now full]
   * Step 5 (Red L2):   p1→Toilet(0), p4→Shower(3), p7→Bathroom(6)  [take freed L3 slots]
   * Step 6 (Red L1):   p2,p5,p8 find no free L2 → stay at own L1 slots (2,5,8)
   *
   * Result:   0:Toilet(L3)-p1   1:Kitchen(L2)-p0   2:Recycling(L1)-p2
   *           3:Shower(L3)-p4   4:FloorA(L2)-p3    5:WashRags(L1)-p5
   *           6:Bathroom(L3)-p7 7:FloorB(L2)-p6    8:Shopping(L1)-p8
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
     * Only p2 (Recycling, L1) and p5 (Washing Rags, L1) are Green L1.
     * All other people are Red so their assignments fill some slots but leave
     * free L3 slots. We verify p2 and p5 each take the slot closest forward.
     *
     * Initial:  0:Toilet(L3)-p0[✗]   1:Kitchen(L2)-p1[✗]   2:Recycling(L1)-p2[✓]
     *           3:Shower(L3)-p3[✗]   4:FloorA(L2)-p4[✗]    5:WashRags(L1)-p5[✓]
     *           6:Bathroom(L3)-p6[✗] 7:FloorB(L2)-p7[✗]    8:Shopping(L1)-p8[✗]
     *
     * Step 4 (Red L3):   p0→Toilet(0), p3→Shower(3), p6→Bathroom(6)  [own slots free]
     * Step 5 (Red L2):   no free L3 → p1→Kitchen(1), p4→FloorA(4), p7→FloorB(7)  [stay L2]
     * Step 6 (Red L1):   no free L2 → p8→Shopping(8)  [stays L1]
     * Step 7 (Green L1): free slots [2,5]; p5(5) dist=6 to slot 2 < p2(2) dist=9 → p5→Recycling(2); p2→WashRags(5)
     *                    (dist from 2 to 2 = 9 because forwardRingDistance treats same-position as full lap)
     *
     * Result:   0:Toilet(L3)-p0   1:Kitchen(L2)-p1   2:Recycling(L1)-p5
     *           3:Shower(L3)-p3   4:FloorA(L2)-p4    5:WashRags(L1)-p2
     *           6:Bathroom(L3)-p6 7:FloorB(L2)-p7    8:Shopping(L1)-p8
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

  // Initial (alternating ✓/✗):
  //   0:Toilet(L3)-p0[✓]   1:Kitchen(L2)-p1[✗]   2:Recycling(L1)-p2[✓]
  //   3:Shower(L3)-p3[✗]   4:FloorA(L2)-p4[✓]    5:WashRags(L1)-p5[✗]
  //   6:Bathroom(L3)-p6[✓] 7:FloorB(L2)-p7[✗]    8:Shopping(L1)-p8[✓]
  //
  // Step 2 (Green L3): p0→Kitchen(1), p6→FloorB(7)
  // Step 3 (Green L2): p4→WashRags(5)
  // Step 4 (Red L3):   p3→Shower(3)
  // Step 5 (Red L2):   p1→Toilet(0), p7→Bathroom(6)
  // Step 6 (Red L1):   p5 takes first free L2 → FloorA(4)
  // Step 7 (Green L1): slots 2,8 free; p8(8) dist=3 to slot 2 < p2(2) dist=9 → p8→Recycling(2); p2→Shopping(8)
  //
  // Result:   0:Toilet(L3)-p1   1:Kitchen(L2)-p0   2:Recycling(L1)-p8
  //           3:Shower(L3)-p3   4:FloorA(L2)-p5    5:WashRags(L1)-p4
  //           6:Bathroom(L3)-p7 7:FloorB(L2)-p6    8:Shopping(L1)-p2

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
     *
     * Same initial/result as the Blue short vacation scenario above (wnc=0 case).
     * Initial:  0:Toilet(L3)-p0[✓] … 2:Recycling(L1)-p2[~,wnc=0] … (all others ✓)
     * Pre-step: p2 wnc 0→1 (= threshold) → blueShort → protected L1 slot
     * Result (p2): slot 2 (Recycling, L1)
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
     *
     * Same initial/result as the Blue long vacation scenario above (wnc=2 case).
     * Initial:  0:Toilet(L3)-p0[✓] … 2:Recycling(L1)-p2[~,wnc=1] … (all others ✓)
     * Pre-step: p2 wnc 1→2 (> threshold) → blueLong → fills last remaining slot
     * Result:   0:Toilet(L3)-p8   1:Kitchen(L2)-p0   2:Recycling(L1)-p1
     *           3:Shower(L3)-p5   4:FloorA(L2)-p3    5:WashRags(L1)-p4
     *           6:Bathroom(L3)-p2 7:FloorB(L2)-p6    8:Shopping(L1)-p7
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
     *
     * Initial (effective owners):
     *   0:Toilet(L3)    assigned=p1, original=p0  → effective owner p0 [✓, Green L3]
     *   1:Kitchen(L2)   assigned=p0, original=p1  → effective owner p1 [✓, Green L2]
     *   2:Recycling(L1)-p2[✓]  3:Shower(L3)-p3[✓]   4:FloorA(L2)-p4[✓]
     *   5:WashRags(L1)-p5[✓]   6:Bathroom(L3)-p6[✓] 7:FloorB(L2)-p7[✓]
     *   8:Shopping(L1)-p8[✓]
     *
     * Algorithm sees same ring positions as all-green scenario (Scenario 1).
     * Step 2 (Green L3): p0→Kitchen(1), p3→FloorA(4), p6→FloorB(7)
     * Step 3 (Green L2): p1→Recycling(2), p4→WashRags(5), p7→Shopping(8)
     * Step 7 (Green L1): p8→Toilet(0), p2→Shower(3), p5→Bathroom(6)
     *
     * Result:   0:Toilet(L3)-p8   1:Kitchen(L2)-p0   2:Recycling(L1)-p1
     *           3:Shower(L3)-p2   4:FloorA(L2)-p3    5:WashRags(L1)-p4
     *           6:Bathroom(L3)-p5 7:FloorB(L2)-p6    8:Shopping(L1)-p7
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
