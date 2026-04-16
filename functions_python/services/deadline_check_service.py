"""Pure deadline-check logic for the scheduled task lifecycle transitions.

The core function compute_deadline_actions() is side-effect-free and takes
only in-memory data, making it straightforward to unit-test without Firestore.
The trigger module (deadline_check_trigger.py) calls this function and then
executes the returned actions against Firestore.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from typing import Any

from models.flat import Flat
from models.task import Task, TaskState


def _to_utc(ts: Any) -> datetime:
    """Return a timezone-aware UTC datetime from a Firestore Timestamp or datetime."""
    if ts is None:
        # Sentinel — treated as "far future" so no deadline checks fire.
        return datetime.max.replace(tzinfo=UTC)
    # Firestore DatetimeWithNanoseconds is a datetime subclass; plain datetime
    # objects (used in tests) are also accepted.
    dt: datetime = ts
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt


@dataclass
class DeadlineActions:
    """Actions the scheduler should execute for one flat this tick."""

    # Pending tasks whose assignee should receive the 24-hour-before reminder.
    tasks_needing_day_before_reminder: list[Task] = field(default_factory=list)
    # Pending tasks whose assignee should receive the X-hours-before reminder.
    tasks_needing_hours_before_reminder: list[Task] = field(default_factory=list)
    # Pending tasks whose deadline has passed — must transition to not_done.
    tasks_needing_grace_period: list[Task] = field(default_factory=list)
    # True when the grace period after the last task deadline has elapsed and
    # week_reset() has not yet been triggered for this weekly cycle.
    should_run_week_reset: bool = False


def compute_deadline_actions(
    tasks: list[Task],
    flat: Flat,
    now: datetime,
) -> DeadlineActions:
    """Compute which deadline-driven actions are due right now.

    Pure function — reads no Firestore, writes nothing.  All timing is
    relative to ``now`` so tests can supply any reference time.

    Week reset fires at ``max(due_date_times) + grace_period_hours`` and is
    guarded by ``flat.last_week_reset_at`` to prevent double-triggering within
    the same weekly cycle (see guard condition below).
    """
    actions = DeadlineActions()

    if not tasks:
        return actions

    for task in tasks:
        if task.state != TaskState.Pending:
            # Completed and not_done tasks have already moved past pending;
            # reminders and grace-period calls are not needed.
            continue

        due = _to_utc(task.due_date_time)

        # ── Day-before reminder ───────────────────────────────────────────────
        # Fire once when we enter the 24-hour window before the deadline.
        # Upper bound (now < due) prevents stale reminders after the deadline
        # has already passed — the grace-period notification covers that case.
        if not task.day_before_reminder_sent and due - timedelta(hours=24) <= now < due:
            actions.tasks_needing_day_before_reminder.append(task)

        # ── Hours-before reminder ─────────────────────────────────────────────
        # Fire once when we enter the admin-configured reminder window.
        # Same upper bound: no "X hours left" message after the deadline.
        if not task.hours_before_reminder_sent and due - timedelta(hours=flat.reminder_hours_before_deadline) <= now < due:
            actions.tasks_needing_hours_before_reminder.append(task)

        # ── Grace period ──────────────────────────────────────────────────────
        # Trigger the Pending → NotDone transition the moment the deadline passes.
        # enter_grace_period() is idempotent, so calling it twice is harmless.
        if now >= due:
            actions.tasks_needing_grace_period.append(task)

    # ── Week reset ────────────────────────────────────────────────────────────
    # Per spec: fires grace_period_hours after the LATEST task deadline.
    latest_due = max(_to_utc(t.due_date_time) for t in tasks)
    week_reset_time = latest_due + timedelta(hours=flat.grace_period_hours)

    # Guard: skip if week_reset already ran in this cycle.
    # After a reset, last_week_reset_at is set to the moment it ran, which is
    # always >= latest_due (since reset fires after all deadlines pass).
    # When the admin sets new due dates for the next week, those dates will be
    # in the future (> last_week_reset_at), clearing the guard automatically.
    already_reset_this_cycle = flat.last_week_reset_at is not None and _to_utc(flat.last_week_reset_at) >= latest_due

    actions.should_run_week_reset = now >= week_reset_time and not already_reset_this_cycle

    return actions
