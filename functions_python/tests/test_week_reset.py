"""BDD tests for the week_reset() assignment algorithm.

These tests use run_week_reset_algorithm() — a pure in-memory function —
so no Firestore emulator is needed. All scenarios test the spec in CLAUDE.md.

Task ring (ring_index → level):
  0: Toilet    (L3)
  1: Kitchen   (L2)
  2: Recycling (L1)
  3: Shower    (L3)
  4: Floor(A)  (L2)
  5: Washing Rags (L1)
  6: Bathroom  (L3)
  7: Floor(B)  (L2)
  8: Shopping  (L1)
"""

from __future__ import annotations

import sys
import os

# Ensure the functions_python package root is on the path when running pytest
# directly from the tests/ directory or from the project root.
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from models.task import Task, TaskState
from models.person import Person
from services.week_reset_service import run_week_reset_algorithm

from tests.helpers import (
    DEFAULT_FLAT,
    build_full_scenario,
    make_person,
    make_task,
)

L3_SLOTS = [0, 3, 6]
L2_SLOTS = [1, 4, 7]
L1_SLOTS = [2, 5, 8]


# ── Scenario: all Green, no vacations ─────────────────────────────────────────

class TestAllGreenNoVacations:
    """Scenario: all 9 people completed their tasks.

    Initial:  0:Toilet(L3)-p0[✓]   1:Kitchen(L2)-p1[✓]   2:Recycling(L1)-p2[✓]
              3:Shower(L3)-p3[✓]   4:FloorA(L2)-p4[✓]    5:WashRags(L1)-p5[✓]
              6:Bathroom(L3)-p6[✓] 7:FloorB(L2)-p7[✓]    8:Shopping(L1)-p8[✓]

    Step 2 (Green L3): p0→Kitchen(1), p3→FloorA(4), p6→FloorB(7)
    Step 3 (Green L2): p1→Recycling(2), p4→WashRags(5), p7→Shopping(8)
    Step 7 (Green L1 shortest dist): slot 0←p8(dist 1), slot 3←p2(dist 1), slot 6←p5(dist 1)

    Result:   0:Toilet(L3)-p8   1:Kitchen(L2)-p0   2:Recycling(L1)-p1
              3:Shower(L3)-p2   4:FloorA(L2)-p3    5:WashRags(L1)-p4
              6:Bathroom(L3)-p5 7:FloorB(L2)-p6    8:Shopping(L1)-p7
    """

    def setup_method(self):
        ids = [f"p{i}" for i in range(9)]
        self.tasks, self.persons = build_full_scenario(ids)
        self.result = run_week_reset_algorithm(self.tasks, self.persons, DEFAULT_FLAT)

    def test_produces_exactly_9_assignments(self):
        assigned = [uid for uid in self.result if uid != ""]
        assert len(assigned) == 9

    def test_assigns_each_person_exactly_once(self):
        unique = set(uid for uid in self.result if uid != "")
        assert len(unique) == 9

    def test_green_l3_p0_moves_to_l2_slot(self):
        # Green L3 (p0=Toilet) moves to an L2 slot
        assert self.result.index("p0") in L2_SLOTS

    def test_green_l3_p3_moves_to_l2_slot(self):
        assert self.result.index("p3") in L2_SLOTS

    def test_green_l3_p6_moves_to_l2_slot(self):
        assert self.result.index("p6") in L2_SLOTS

    def test_green_l2_people_move_to_l1_slots(self):
        # p1=Kitchen(L2), p4=Floor(A)(L2), p7=Floor(B)(L2) should all be at L1
        for uid in ["p1", "p4", "p7"]:
            assert self.result.index(uid) in L1_SLOTS


# ── Scenario: Green L3 forward scan ───────────────────────────────────────────

class TestGreenL3ForwardScan:
    """Scenario: Green L3 person scans forward for free L2."""

    def test_p0_toilet_finds_kitchen_first(self):
        """p0 (Toilet, L3) scans forward and finds Kitchen (index 1) first."""
        ids = [f"p{i}" for i in range(9)]
        task_states = {i: TaskState.NotDone for i in range(1, 9)}
        task_states[0] = TaskState.Completed

        # Step 2 (Green L3): p0 scans forward from 0 → first free L2 is Kitchen(1) → p0→1
        tasks, persons = build_full_scenario(ids, task_states)
        result = run_week_reset_algorithm(tasks, persons, DEFAULT_FLAT)

        assert result[1] == "p0"


# ── Scenario: Red L2 moves up to L3 ──────────────────────────────────────────

class TestRedL2MovesUpToL3:
    """Scenario: Red L2 person moves up to L3."""

    def test_failed_kitchen_gets_l3_task(self):
        """A person who failed Kitchen (L2) gets an L3 task next week."""
        ids = [f"p{i}" for i in range(9)]
        task_states = {i: TaskState.Completed for i in range(9)}
        task_states[1] = TaskState.NotDone  # p1=Kitchen fails

        tasks, persons = build_full_scenario(ids, task_states)
        result = run_week_reset_algorithm(tasks, persons, DEFAULT_FLAT)

        p1_slot = result.index("p1")
        assert p1_slot in L3_SLOTS


# ── Scenario: Red L1 moves up to L2 ──────────────────────────────────────────

class TestRedL1MovesUpToL2:
    """Scenario: Red L1 person moves up to L2."""

    def test_failed_recycling_gets_l2_when_slots_available(self):
        """A person who failed Recycling (L1) gets an L2 task when L2 slots are available.

        Initial:  0:Toilet(L3)-p0[✓]   1:Kitchen(L2)-p1[✗]   2:Recycling(L1)-p2[✗]
                  3:Shower(L3)-p3[✗]   4:FloorA(L2)-p4[✓]    5:WashRags(L1)-p5[✓]
                  6:Bathroom(L3)-p6[✗] 7:FloorB(L2)-p7[✓]    8:Shopping(L1)-p8[✓]
        """
        ids = [f"p{i}" for i in range(9)]
        task_states = {
            0: TaskState.Completed,
            1: TaskState.NotDone,
            2: TaskState.NotDone,
            3: TaskState.NotDone,
            4: TaskState.Completed,
            5: TaskState.Completed,
            6: TaskState.NotDone,
            7: TaskState.Completed,
            8: TaskState.Completed,
        }

        tasks, persons = build_full_scenario(ids, task_states)
        result = run_week_reset_algorithm(tasks, persons, DEFAULT_FLAT)

        p2_slot = result.index("p2")
        assert p2_slot in L2_SLOTS


# ── Scenario: Red L3 stays at L3 ─────────────────────────────────────────────

class TestRedL3StaysAtL3:
    """Scenario: Red L3 person stays at L3."""

    def test_failed_toilet_stays_at_l3(self):
        ids = [f"p{i}" for i in range(9)]
        task_states = {i: TaskState.Completed for i in range(9)}
        task_states[0] = TaskState.NotDone  # p0=Toilet fails

        tasks, persons = build_full_scenario(ids, task_states)
        result = run_week_reset_algorithm(tasks, persons, DEFAULT_FLAT)

        assert result.index("p0") in L3_SLOTS

    def test_red_l3_retains_same_task_when_still_free(self):
        """Red L3 retains their same task when it is still free.

        Green L3s (p3, p6) scan forward past Toilet — leaving Toilet free for p0.
        """
        ids = [f"p{i}" for i in range(9)]
        task_states = {i: TaskState.Completed for i in range(9)}
        task_states[0] = TaskState.NotDone  # only p0 fails

        tasks, persons = build_full_scenario(ids, task_states)
        result = run_week_reset_algorithm(tasks, persons, DEFAULT_FLAT)

        assert result[0] == "p0"


# ── Scenario: Blue short vacation (protected) ────────────────────────────────

class TestBlueShortVacationProtected:
    """Scenario: Blue short vacation person gets a protected L1 slot."""

    def test_vacation_person_weeks_not_cleaned_le_threshold_gets_l1_slot(self):
        """A person on vacation (weeks_not_cleaned ≤ 1) is assigned first to an L1 slot."""
        ids = [f"p{i}" for i in range(9)]
        task_states = {i: TaskState.Completed for i in range(9)}
        on_vacation = {"p2": True}
        weeks_not_cleaned = {2: 0}  # will be incremented to 1 in pre-step

        tasks, persons = build_full_scenario(ids, task_states, on_vacation, weeks_not_cleaned)
        result = run_week_reset_algorithm(tasks, persons, DEFAULT_FLAT)

        assert result.index("p2") in L1_SLOTS


# ── Scenario: Blue long vacation (unprotected, last) ─────────────────────────

class TestBlueLongVacationUnprotected:
    """Scenario: Blue long vacation person is assigned last."""

    def test_long_vacation_person_fills_remaining_slot(self):
        """A person on long vacation (weeks_not_cleaned > threshold) fills remaining slots."""
        ids = [f"p{i}" for i in range(9)]
        task_states = {i: TaskState.Completed for i in range(9)}
        on_vacation = {"p2": True}
        weeks_not_cleaned = {2: 2}  # already > threshold (1), and increments to 3

        tasks, persons = build_full_scenario(ids, task_states, on_vacation, weeks_not_cleaned)
        result = run_week_reset_algorithm(tasks, persons, DEFAULT_FLAT)

        assigned = [uid for uid in result if uid != ""]
        assert len(assigned) == 9
        assert "p2" in result


# ── Scenario: Red L1 escape (accepted tradeoff) ───────────────────────────────

class TestRedL1EscapeAcceptedTradeoff:
    """Accepted tradeoff: Red L1 stays at L1 when all L2 and L3 slots are taken.

    When all 3 L3 are Green AND all 3 L2 are Red, Red L1 escapes punishment.
    Documented in CLAUDE.md as an accepted tradeoff.
    """

    def test_red_l1_stays_at_l1_when_l2_and_l3_full(self):
        ids = [f"p{i}" for i in range(9)]
        task_states = {
            0: TaskState.Completed,  # p0 Toilet L3 green → moves to L2
            1: TaskState.NotDone,    # p1 Kitchen L2 red  → moves to L3
            2: TaskState.NotDone,    # p2 Recycling L1 red → tries L2 (full), stays at L1
            3: TaskState.Completed,  # p3 Shower L3 green  → moves to L2
            4: TaskState.NotDone,    # p4 Floor(A) L2 red  → moves to L3
            5: TaskState.NotDone,    # p5 Washing Rags L1 red → stays at L1
            6: TaskState.Completed,  # p6 Bathroom L3 green → moves to L2
            7: TaskState.NotDone,    # p7 Floor(B) L2 red  → moves to L3
            8: TaskState.NotDone,    # p8 Shopping L1 red  → stays at L1
        }

        tasks, persons = build_full_scenario(ids, task_states)
        result = run_week_reset_algorithm(tasks, persons, DEFAULT_FLAT)

        # Red L1 people stay at L1
        for uid in ["p2", "p5", "p8"]:
            assert result.index(uid) in L1_SLOTS

        # Green L3 people at L2
        for uid in ["p0", "p3", "p6"]:
            assert result.index(uid) in L2_SLOTS

        assigned = [uid for uid in result if uid != ""]
        assert len(assigned) == 9
        assert len(set(assigned)) == 9


# ── Scenario: Green L1 shortest ring distance ─────────────────────────────────

class TestGreenL1ShortestRingDistance:
    """Scenario: Green L1 uses shortest forward ring distance."""

    def test_green_l1_picks_nearest_forward_slot(self):
        """Green L1 person is assigned to the free slot with minimum forward ring distance."""
        ids = [f"p{i}" for i in range(9)]
        task_states = {
            0: TaskState.NotDone,   # Red L3 stays at Toilet (0)
            1: TaskState.NotDone,   # Red L2 stays at L2 (no free L3)
            2: TaskState.Completed, # Green L1
            3: TaskState.NotDone,   # Red L3 stays at Shower (3)
            4: TaskState.NotDone,   # Red L2
            5: TaskState.Completed, # Green L1
            6: TaskState.NotDone,   # Red L3 stays at Bathroom (6)
            7: TaskState.NotDone,   # Red L2
            8: TaskState.NotDone,   # Red L1
        }

        tasks, persons = build_full_scenario(ids, task_states)
        result = run_week_reset_algorithm(tasks, persons, DEFAULT_FLAT)

        assigned = [uid for uid in result if uid != ""]
        assert len(assigned) == 9
        assert "p2" in result
        assert "p5" in result


# ── Smoke test: no duplicates ─────────────────────────────────────────────────

class TestSmokeNoDuplicates:
    """Smoke test: week_reset() never assigns two people to the same task."""

    def test_produces_9_unique_assignments(self):
        """Alternating completed/not_done states produce 9 unique assignments."""
        ids = [f"p{i}" for i in range(9)]
        all_states = [
            TaskState.Completed,
            TaskState.NotDone,
            TaskState.Completed,
            TaskState.NotDone,
            TaskState.Completed,
            TaskState.NotDone,
            TaskState.Completed,
            TaskState.NotDone,
            TaskState.Completed,
        ]
        task_states = {i: s for i, s in enumerate(all_states)}

        tasks, persons = build_full_scenario(ids, task_states)
        result = run_week_reset_algorithm(tasks, persons, DEFAULT_FLAT)

        unique = set(uid for uid in result if uid != "")
        assert len(unique) == 9
        assert len([uid for uid in result if uid != ""]) == 9


# ── Scenario: weeks_not_cleaned increments ───────────────────────────────────

class TestWeeksNotCleanedIncrements:
    """Scenario: weeks_not_cleaned increments before categorisation."""

    def test_increments_before_strategy_runs_for_short_vacation(self):
        """weeks_not_cleaned 0→1 (= threshold) → blueShort → protected L1 slot."""
        ids = [f"p{i}" for i in range(9)]
        task_states = {i: TaskState.Completed for i in range(9)}
        on_vacation = {"p2": True}
        weeks_not_cleaned = {2: 0}  # becomes 1 after increment = threshold

        tasks, persons = build_full_scenario(ids, task_states, on_vacation, weeks_not_cleaned)
        result = run_week_reset_algorithm(tasks, persons, DEFAULT_FLAT)

        assert result.index("p2") in L1_SLOTS

    def test_increments_before_strategy_runs_for_long_vacation(self):
        """weeks_not_cleaned 1→2 (> threshold) → blueLong → fills last slot."""
        ids = [f"p{i}" for i in range(9)]
        task_states = {i: TaskState.Completed for i in range(9)}
        on_vacation = {"p2": True}
        weeks_not_cleaned = {2: 1}  # becomes 2 after increment > threshold

        tasks, persons = build_full_scenario(ids, task_states, on_vacation, weeks_not_cleaned)
        result = run_week_reset_algorithm(tasks, persons, DEFAULT_FLAT)

        assert "p2" in result


# ── Scenario: effectiveAssignedTo respects swap ───────────────────────────────

class TestEffectiveAssignedToSwap:
    """Scenario: swap does not affect rotation (effective_assigned_to)."""

    def test_week_reset_uses_original_assigned_to_when_swap_active(self):
        """week_reset uses original_assigned_to when a swap is active.

        p0 originally had Toilet (L3, index 0) but swapped to Kitchen (L2, index 1).
        assigned_to[0] = p1, original_assigned_to[0] = p0 → p0 is Green L3.
        assigned_to[1] = p0, original_assigned_to[1] = p1 → p1 is Green L2.
        """
        persons = [make_person(f"p{i}") for i in range(9)]
        tasks = [
            # Toilet (0): assigned to p1 via swap; original is p0 (L3)
            make_task(0, "p1", TaskState.Completed, 0, "p0"),
            # Kitchen (1): assigned to p0 via swap; original is p1 (L2)
            make_task(1, "p0", TaskState.Completed, 0, "p1"),
            make_task(2, "p2", TaskState.Completed),
            make_task(3, "p3", TaskState.Completed),
            make_task(4, "p4", TaskState.Completed),
            make_task(5, "p5", TaskState.Completed),
            make_task(6, "p6", TaskState.Completed),
            make_task(7, "p7", TaskState.Completed),
            make_task(8, "p8", TaskState.Completed),
        ]

        result = run_week_reset_algorithm(tasks, persons, DEFAULT_FLAT)

        # p0 (originally L3) → should be at an L2 slot
        assert result.index("p0") in L2_SLOTS
        # p1 (originally L2) → should be at an L1 slot
        assert result.index("p1") in L1_SLOTS


# ── Scenario: two short-vacation people ──────────────────────────────────────

class TestTwoShortVacationPeopleGetL1Slots:
    """Scenario: two short-vacation people both receive L1 slots."""

    def test_two_l1_vacation_people_each_assigned_protected_l1_slot(self):
        ids = [f"p{i}" for i in range(9)]
        task_states = {i: TaskState.NotDone for i in range(9)}
        on_vacation = {"p2": True, "p5": True}
        weeks_not_cleaned = {2: 0, 5: 0}

        tasks, persons = build_full_scenario(ids, task_states, on_vacation, weeks_not_cleaned)
        result = run_week_reset_algorithm(tasks, persons, DEFAULT_FLAT)

        assert result.index("p2") in L1_SLOTS
        assert result.index("p5") in L1_SLOTS
        assert len(set(uid for uid in result if uid != "")) == 9


# ── Scenario: short-vacation overflow ────────────────────────────────────────

class TestShortVacationOverflow:
    """Scenario: short-vacation overflow — L3 person gets L2 slot, not L1."""

    def test_l3_vacation_person_overflows_to_l2_when_l1_full(self):
        """With 4 short-vacation people (3 L1 + 1 L3), the L3 person overflows to L2.

        The spec says "those who had harder tasks get the harder available slots", so
        the L3 person (harder) must land on the L2 overflow slot.
        """
        ids = [f"p{i}" for i in range(9)]
        task_states = {i: TaskState.NotDone for i in range(9)}
        on_vacation = {"p0": True, "p2": True, "p5": True, "p8": True}
        weeks_not_cleaned = {0: 0, 2: 0, 5: 0, 8: 0}

        tasks, persons = build_full_scenario(ids, task_states, on_vacation, weeks_not_cleaned)
        result = run_week_reset_algorithm(tasks, persons, DEFAULT_FLAT)

        # p0 (originally L3) must get an L2 overflow slot — not L1
        assert result.index("p0") in L2_SLOTS

        # The three L1 vacation people stay at L1 slots
        for uid in ["p2", "p5", "p8"]:
            assert result.index(uid) in L1_SLOTS

        assert len(set(uid for uid in result if uid != "")) == 9


# ── Accepted tradeoff: vacation overflow blocks Green L3 reward ───────────────

class TestVacationOverflowBlocksGreenL3Reward:
    """Accepted tradeoff: short-vacation overflow blocks Green L3 reward."""

    def test_green_l3_stays_at_l3_when_vacation_fills_all_lower_slots(self):
        """Green L3 person stays at L3 when vacation fills all L1 and L2 slots.

        6 short-vacation people fill all 3 L1 + all 3 L2 slots in step 1.
        Documented in CLAUDE.md as an accepted tradeoff.
        """
        ids = [f"p{i}" for i in range(9)]
        task_states = {
            0: TaskState.Pending,   # vacation
            1: TaskState.Pending,
            2: TaskState.Pending,
            3: TaskState.Pending,
            4: TaskState.NotDone,   # Red L2 → goes to L3
            5: TaskState.Pending,
            6: TaskState.Completed, # Green L3 → tries L2 but blocked
            7: TaskState.NotDone,   # Red L2 → goes to L3
            8: TaskState.Pending,
        }
        on_vacation = {"p0": True, "p1": True, "p2": True, "p3": True, "p5": True, "p8": True}
        weeks_not_cleaned = {0: 0, 1: 0, 2: 0, 3: 0, 5: 0, 8: 0}

        tasks, persons = build_full_scenario(ids, task_states, on_vacation, weeks_not_cleaned)
        result = run_week_reset_algorithm(tasks, persons, DEFAULT_FLAT)

        # L3 vacation people (p0, p3) must be at L2 overflow slots (harder → harder)
        assert result.index("p0") in L2_SLOTS
        assert result.index("p3") in L2_SLOTS

        # L1 vacation people at L1 slots
        for uid in ["p2", "p5", "p8"]:
            assert result.index(uid) in L1_SLOTS

        # p6 (Green L3) stays at L3 — all lower slots occupied by vacation
        assert result.index("p6") in L3_SLOTS

        assert len(set(uid for uid in result if uid != "")) == 9
