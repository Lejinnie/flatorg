"""BDD tests for deadline_check_service.compute_deadline_actions().

All tests are pure — no Firestore connection required.  Each scenario
fixes a reference time (``now``) and constructs tasks/flat settings with
known due dates to verify exactly which actions the scheduler should take.

Task ring layout (ring_index → task):
  0 = Toilet (L3), assigned to p0
"""

from __future__ import annotations

import sys
from dataclasses import replace
from datetime import UTC, datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from models.flat import Flat
from models.task import Task, TaskState
from services.deadline_check_service import compute_deadline_actions
from tests.helpers import make_task

# ── Reference time ────────────────────────────────────────────────────────────

# A fixed "now" used across all tests for reproducibility.
_NOW = datetime(2025, 6, 15, 12, 0, tzinfo=UTC)


# ── Helpers ───────────────────────────────────────────────────────────────────


def _flat(
    reminder_hours: int = 1,
    grace_hours: int = 1,
    last_reset_at: datetime | None = None,
) -> Flat:
    return Flat(
        id="f1",
        name="Test Flat",
        admin_uid="admin",
        invite_code="ABC",
        reminder_hours_before_deadline=reminder_hours,
        grace_period_hours=grace_hours,
        last_week_reset_at=last_reset_at,
    )


def _task(
    ring_index: int = 0,
    state: TaskState = TaskState.Pending,
    due_offset_hours: float = 48.0,
    day_before_sent: bool = False,
    hours_before_sent: bool = False,
) -> Task:
    """Create a task with a due date relative to _NOW."""
    base = make_task(ring_index, f"p{ring_index}", state)
    return replace(
        base,
        due_date_time=_NOW + timedelta(hours=due_offset_hours),
        day_before_reminder_sent=day_before_sent,
        hours_before_reminder_sent=hours_before_sent,
    )


# ── Scenario: day-before reminder ─────────────────────────────────────────────


class TestDayBeforeReminder:
    """Situation 15 — day-before reminder fires exactly once per cycle."""

    def test_fires_when_inside_24h_window(self) -> None:
        """Given a pending task due in 20 hours (inside 24h window),
        when check runs, then it is included in day-before reminders.
        """
        task = _task(due_offset_hours=20)
        actions = compute_deadline_actions([task], _flat(), _NOW)
        assert task in actions.tasks_needing_day_before_reminder

    def test_does_not_fire_outside_24h_window(self) -> None:
        """Given a pending task due in 30 hours (outside 24h window),
        when check runs, then it is NOT included in day-before reminders.
        """
        task = _task(due_offset_hours=30)
        actions = compute_deadline_actions([task], _flat(), _NOW)
        assert task not in actions.tasks_needing_day_before_reminder

    def test_does_not_fire_if_already_sent(self) -> None:
        """Given the day-before flag is already True,
        when check runs, then the reminder is NOT sent again.
        """
        task = _task(due_offset_hours=20, day_before_sent=True)
        actions = compute_deadline_actions([task], _flat(), _NOW)
        assert task not in actions.tasks_needing_day_before_reminder

    def test_does_not_fire_for_non_pending_task(self) -> None:
        """Given a completed task inside the 24h window,
        when check runs, then no reminder is sent (task is already done).
        """
        task = _task(due_offset_hours=20, state=TaskState.Completed)
        actions = compute_deadline_actions([task], _flat(), _NOW)
        assert task not in actions.tasks_needing_day_before_reminder


# ── Scenario: hours-before reminder ──────────────────────────────────────────


class TestHoursBeforeReminder:
    """Situation 16 — hours-before reminder respects the per-flat config."""

    def test_fires_when_inside_configured_window(self) -> None:
        """Given reminder_hours=4 and task due in 3 hours (inside window),
        when check runs, then it is included in hours-before reminders.
        """
        task = _task(due_offset_hours=3)
        actions = compute_deadline_actions([task], _flat(reminder_hours=4), _NOW)
        assert task in actions.tasks_needing_hours_before_reminder

    def test_does_not_fire_outside_configured_window(self) -> None:
        """Given reminder_hours=4 and task due in 6 hours (outside window),
        when check runs, then it is NOT included in hours-before reminders.
        """
        task = _task(due_offset_hours=6)
        actions = compute_deadline_actions([task], _flat(reminder_hours=4), _NOW)
        assert task not in actions.tasks_needing_hours_before_reminder

    def test_does_not_fire_if_already_sent(self) -> None:
        """Given the hours-before flag is already True,
        when check runs inside the window, then reminder is NOT sent again.
        """
        task = _task(due_offset_hours=3, hours_before_sent=True)
        actions = compute_deadline_actions([task], _flat(reminder_hours=4), _NOW)
        assert task not in actions.tasks_needing_hours_before_reminder

    def test_fires_independently_of_day_before_flag(self) -> None:
        """Given the day-before reminder was already sent (flag True) but
        hours-before flag is still False, when check runs inside the
        hours-before window, then hours-before reminder still fires.
        """
        task = _task(due_offset_hours=0.5, day_before_sent=True)
        actions = compute_deadline_actions([task], _flat(reminder_hours=1), _NOW)
        assert task in actions.tasks_needing_hours_before_reminder


# ── Scenario: grace period ────────────────────────────────────────────────────


class TestGracePeriod:
    """Situation 17 — grace period triggers when task deadline passes."""

    def test_fires_when_deadline_passed(self) -> None:
        """Given a pending task whose deadline was 2 hours ago,
        when check runs, then it is included in grace period tasks.
        """
        task = _task(due_offset_hours=-2)
        actions = compute_deadline_actions([task], _flat(), _NOW)
        assert task in actions.tasks_needing_grace_period

    def test_does_not_fire_before_deadline(self) -> None:
        """Given a pending task due in 1 hour,
        when check runs, then it is NOT included in grace period tasks.
        """
        task = _task(due_offset_hours=1)
        actions = compute_deadline_actions([task], _flat(), _NOW)
        assert task not in actions.tasks_needing_grace_period

    def test_does_not_fire_for_completed_task(self) -> None:
        """Given a completed task whose deadline has passed,
        when check runs, then grace period is NOT triggered (already done).
        """
        task = _task(due_offset_hours=-2, state=TaskState.Completed)
        actions = compute_deadline_actions([task], _flat(), _NOW)
        assert task not in actions.tasks_needing_grace_period

    def test_does_not_fire_for_already_not_done_task(self) -> None:
        """Given a task already in not_done state,
        when check runs, then grace period is NOT triggered again.
        """
        task = _task(due_offset_hours=-2, state=TaskState.NotDone)
        actions = compute_deadline_actions([task], _flat(), _NOW)
        assert task not in actions.tasks_needing_grace_period


# ── Scenario: week reset ──────────────────────────────────────────────────────


class TestWeekReset:
    """Situation 18 — week reset fires once after grace_period_hours elapse."""

    def test_fires_after_grace_period_elapsed(self) -> None:
        """Given all task deadlines passed and grace_period_hours elapsed,
        when check runs, then should_run_week_reset is True.
        """
        # Task due 3 hours ago, grace_period = 2 hours → reset time = 1h ago.
        task = _task(due_offset_hours=-3)
        actions = compute_deadline_actions([task], _flat(grace_hours=2), _NOW)
        assert actions.should_run_week_reset is True

    def test_does_not_fire_before_grace_period_elapsed(self) -> None:
        """Given all deadlines passed but grace_period_hours NOT yet elapsed,
        when check runs, then should_run_week_reset is False.
        """
        # Task due 1 hour ago, grace_period = 2 hours → reset time = 1h from now.
        task = _task(due_offset_hours=-1)
        actions = compute_deadline_actions([task], _flat(grace_hours=2), _NOW)
        assert actions.should_run_week_reset is False

    def test_does_not_fire_if_already_reset_this_cycle(self) -> None:
        """Given week_reset already ran after the latest deadline,
        when check runs, then should_run_week_reset is False (guard active).
        """
        task = _task(due_offset_hours=-3)
        # last_week_reset_at is AFTER the task's due date → guard prevents re-run.
        last_reset = _NOW - timedelta(hours=2)
        actions = compute_deadline_actions([task], _flat(grace_hours=2, last_reset_at=last_reset), _NOW)
        assert actions.should_run_week_reset is False

    def test_fires_again_after_new_due_dates_set(self) -> None:
        """Given last_week_reset_at is BEFORE the current task's due date,
        when check runs after grace period elapses, then reset fires (new cycle).
        """
        # last_week_reset_at happened before the new due date was set.
        last_reset = _NOW - timedelta(days=7)
        # New task due 3 hours ago → reset time = 2h ago.
        task = _task(due_offset_hours=-3)
        actions = compute_deadline_actions([task], _flat(grace_hours=2, last_reset_at=last_reset), _NOW)
        assert actions.should_run_week_reset is True

    def test_uses_latest_due_date_across_all_tasks(self) -> None:
        """Given 3 tasks with different deadlines, week reset uses the latest
        deadline + grace_period to determine the reset time.
        """
        task_early = _task(ring_index=0, due_offset_hours=-5)  # due 5h ago
        task_late = _task(ring_index=1, due_offset_hours=-1)  # due 1h ago (latest)
        task_mid = _task(ring_index=2, due_offset_hours=-3)

        # grace_period = 2h, latest deadline = 1h ago → reset at 1h ago (elapsed)
        actions = compute_deadline_actions([task_early, task_late, task_mid], _flat(grace_hours=2), _NOW)
        assert actions.should_run_week_reset is False  # latest due - 1h, grace = 2h → not yet

        # With grace_period = 0.5h → reset at 0.5h ago → fires
        actions2 = compute_deadline_actions([task_early, task_late, task_mid], _flat(grace_hours=0), _NOW)
        assert actions2.should_run_week_reset is True

    def test_does_not_fire_for_empty_task_list(self) -> None:
        """Given no tasks, when check runs, then should_run_week_reset is False."""
        actions = compute_deadline_actions([], _flat(), _NOW)
        assert actions.should_run_week_reset is False


# ── Scenario: multiple actions in one tick ────────────────────────────────────


class TestMultipleActionsPerTick:
    """Situation 19 — multiple actions can fire in the same scheduler tick."""

    def test_only_grace_period_fires_when_past_deadline_with_unsent_reminders(self) -> None:
        """Given a pending task 2 hours past its deadline (reminders unsent),
        when check runs, only grace period fires — reminders are suppressed
        because they are meaningless after the deadline.
        """
        task = _task(due_offset_hours=-2)
        actions = compute_deadline_actions([task], _flat(reminder_hours=1), _NOW)

        # Reminders must NOT fire after the deadline — they'd show stale content.
        assert task not in actions.tasks_needing_day_before_reminder
        assert task not in actions.tasks_needing_hours_before_reminder
        # Deadline passed → grace period fires.
        assert task in actions.tasks_needing_grace_period

    def test_hours_before_and_day_before_both_fire_inside_window(self) -> None:
        """Given a pending task 30 minutes before deadline (inside both windows),
        when check runs, both reminders fire but NOT the grace period.
        """
        task = _task(due_offset_hours=0.5)
        actions = compute_deadline_actions([task], _flat(reminder_hours=1), _NOW)

        assert task in actions.tasks_needing_day_before_reminder
        assert task in actions.tasks_needing_hours_before_reminder
        assert task not in actions.tasks_needing_grace_period


# ═══════════════════════════════════════════════════════════════════════════════
# All tasks share the same due date (real-world scenario)
# ═══════════════════════════════════════════════════════════════════════════════


class TestAllTasksSameDueDate:
    """Scenarios matching the 9-task flat where every task has the same deadline.

    These tests reproduce the real-world observation where a user received 3
    notifications for a single hours-before trigger tick.
    """

    def _nine_tasks_same_deadline(
        self,
        due_offset_hours: float,
        day_before_sent: bool = False,
        hours_before_sent: bool = False,
    ) -> list[Task]:
        return [
            _task(
                ring_index=i,
                due_offset_hours=due_offset_hours,
                day_before_sent=day_before_sent,
                hours_before_sent=hours_before_sent,
            )
            for i in range(9)
        ]

    def test_given_all_same_due_date_when_hours_reminder_fires_then_each_task_gets_exactly_one(
        self,
    ) -> None:
        """Given 9 tasks all due in 30 minutes (inside 1h reminder window),
        when check runs, then exactly 9 tasks appear in hours_before list
        — one per task, no duplicates.
        """
        tasks = self._nine_tasks_same_deadline(due_offset_hours=0.5)
        actions = compute_deadline_actions(tasks, _flat(reminder_hours=1), _NOW)

        assert len(actions.tasks_needing_hours_before_reminder) == 9
        ids = [t.id for t in actions.tasks_needing_hours_before_reminder]
        assert len(set(ids)) == 9

    def test_given_all_same_due_date_when_deadline_passes_then_only_grace_period_no_reminders(
        self,
    ) -> None:
        """Given 9 tasks all due 30 minutes ago (deadline passed, reminders unsent),
        when check runs, then ONLY grace period fires — no stale reminders.
        This was the root cause of the '3 notifications' bug.
        """
        tasks = self._nine_tasks_same_deadline(due_offset_hours=-0.5)
        actions = compute_deadline_actions(tasks, _flat(reminder_hours=1), _NOW)

        assert len(actions.tasks_needing_day_before_reminder) == 0
        assert len(actions.tasks_needing_hours_before_reminder) == 0
        assert len(actions.tasks_needing_grace_period) == 9

    def test_given_all_same_due_date_when_flags_already_set_then_no_duplicate_reminders(
        self,
    ) -> None:
        """Given 9 tasks inside the hours-before window but with the sent flag
        already True, when check runs, then no hours-before reminders fire.
        """
        tasks = self._nine_tasks_same_deadline(
            due_offset_hours=0.5,
            hours_before_sent=True,
        )
        actions = compute_deadline_actions(tasks, _flat(reminder_hours=1), _NOW)

        assert len(actions.tasks_needing_hours_before_reminder) == 0

    def test_given_all_same_due_date_and_grace_period_elapsed_then_week_reset_fires(
        self,
    ) -> None:
        """Given 9 tasks all due 3 hours ago and grace_period=1h,
        when check runs, then should_run_week_reset is True.
        """
        tasks = self._nine_tasks_same_deadline(due_offset_hours=-3)
        actions = compute_deadline_actions(tasks, _flat(grace_hours=1), _NOW)

        assert actions.should_run_week_reset is True

    def test_given_all_same_due_date_and_grace_period_not_elapsed_then_no_week_reset(
        self,
    ) -> None:
        """Given 9 tasks all due 30 minutes ago and grace_period=1h,
        when check runs, then should_run_week_reset is False (still in grace period).
        """
        tasks = self._nine_tasks_same_deadline(due_offset_hours=-0.5)
        actions = compute_deadline_actions(tasks, _flat(grace_hours=1), _NOW)

        assert actions.should_run_week_reset is False

    def test_given_stale_last_reset_blocking_new_cycle_then_week_reset_still_fires(
        self,
    ) -> None:
        """Given last_week_reset_at is from the PREVIOUS cycle (before current
        due dates), when grace period elapses, then week_reset fires because
        the guard only blocks within the same cycle.
        """
        tasks = self._nine_tasks_same_deadline(due_offset_hours=-3)
        # Last reset was 7 days ago — well before the current due dates.
        last_reset = _NOW - timedelta(days=7)
        actions = compute_deadline_actions(tasks, _flat(grace_hours=1, last_reset_at=last_reset), _NOW)

        assert actions.should_run_week_reset is True

    def test_given_last_reset_after_current_due_dates_then_week_reset_blocked(
        self,
    ) -> None:
        """Given last_week_reset_at is AFTER the current task due dates,
        when check runs, then week_reset is blocked (already ran this cycle).

        This reproduces the scenario where a user sets task deadlines to a
        date BEFORE the previous week_reset timestamp — the guard incorrectly
        blocks the reset.
        """
        tasks = self._nine_tasks_same_deadline(due_offset_hours=-3)
        # Deadline was 3h ago (_NOW - 3h), but last_reset was only 1h ago.
        # last_reset (_NOW - 1h) > latest_due (_NOW - 3h) → guard blocks.
        last_reset = _NOW - timedelta(hours=1)
        actions = compute_deadline_actions(tasks, _flat(grace_hours=1, last_reset_at=last_reset), _NOW)

        assert actions.should_run_week_reset is False


# ═══════════════════════════════════════════════════════════════════════════════
# Scheduler tick sequence — simulate consecutive 5-minute ticks
# ═══════════════════════════════════════════════════════════════════════════════


class TestSchedulerTickSequence:
    """Simulate the real lifecycle of a flat across multiple scheduler ticks
    to verify that no duplicate notifications occur and week_reset fires
    at the right time.
    """

    def test_full_lifecycle_9_tasks_same_deadline(self) -> None:
        """Given 9 tasks all due at the same time, simulate the scheduler
        ticking through the full lifecycle:
          tick 1: 20h before → day-before reminder fires
          tick 2: 20h before → day-before flag set, no duplicate
          tick 3: 45min before → hours-before reminder fires
          tick 4: 45min before → hours-before flag set, no duplicate
          tick 5: 30min after deadline → grace period fires, NO reminders
          tick 6: 2h after deadline (grace=1h) → week_reset fires
        """
        due = _NOW + timedelta(hours=20)

        def tasks(day_sent: bool = False, hours_sent: bool = False) -> list[Task]:
            return [
                replace(
                    make_task(i, f"p{i}", TaskState.Pending),
                    due_date_time=due,
                    day_before_reminder_sent=day_sent,
                    hours_before_reminder_sent=hours_sent,
                )
                for i in range(9)
            ]

        flat = _flat(reminder_hours=1, grace_hours=1)

        # Tick 1: 20h before deadline → inside 24h window.
        t1 = due - timedelta(hours=20)
        a1 = compute_deadline_actions(tasks(), flat, t1)
        assert len(a1.tasks_needing_day_before_reminder) == 9
        assert len(a1.tasks_needing_hours_before_reminder) == 0
        assert len(a1.tasks_needing_grace_period) == 0
        assert a1.should_run_week_reset is False

        # Tick 2: same time, flags now set → no duplicates.
        a2 = compute_deadline_actions(tasks(day_sent=True), flat, t1)
        assert len(a2.tasks_needing_day_before_reminder) == 0

        # Tick 3: 45min before deadline → inside 1h window.
        t3 = due - timedelta(minutes=45)
        a3 = compute_deadline_actions(tasks(day_sent=True), flat, t3)
        assert len(a3.tasks_needing_hours_before_reminder) == 9
        assert len(a3.tasks_needing_grace_period) == 0

        # Tick 4: same time, hours flag now set → no duplicates.
        a4 = compute_deadline_actions(tasks(day_sent=True, hours_sent=True), flat, t3)
        assert len(a4.tasks_needing_hours_before_reminder) == 0

        # Tick 5: 30min after deadline → grace period fires, NO stale reminders.
        t5 = due + timedelta(minutes=30)
        a5 = compute_deadline_actions(tasks(day_sent=True, hours_sent=True), flat, t5)
        assert len(a5.tasks_needing_day_before_reminder) == 0
        assert len(a5.tasks_needing_hours_before_reminder) == 0
        assert len(a5.tasks_needing_grace_period) == 9
        assert a5.should_run_week_reset is False

        # Tick 6: 2h after deadline (grace=1h elapsed) → week_reset fires.
        t6 = due + timedelta(hours=2)
        a6 = compute_deadline_actions(tasks(day_sent=True, hours_sent=True), flat, t6)
        assert a6.should_run_week_reset is True
