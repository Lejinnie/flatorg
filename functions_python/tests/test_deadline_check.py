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
from models.task import TaskState
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
) -> object:
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

    def test_reminder_and_grace_period_both_fire_when_past_deadline(self) -> None:
        """Given a pending task 2 hours past its deadline (reminder unsent),
        when check runs, all three actions fire simultaneously.
        """
        task = _task(due_offset_hours=-2)
        actions = compute_deadline_actions([task], _flat(reminder_hours=1), _NOW)

        # Day-before window entered > 24h ago → reminder due.
        assert task in actions.tasks_needing_day_before_reminder
        # Hours-before window entered > 1h ago → reminder due.
        assert task in actions.tasks_needing_hours_before_reminder
        # Deadline passed → grace period due.
        assert task in actions.tasks_needing_grace_period
