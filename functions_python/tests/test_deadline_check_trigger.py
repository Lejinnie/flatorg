"""BDD tests for deadline_check_trigger orchestration.

Tests the _run_for_flat helper which dispatches notifications based on
compute_deadline_actions results. Verifies that:
  - Each person receives exactly one notification per type per scheduler tick.
  - The hours_before_reminder_sent flag prevents duplicate sends across ticks.
  - week_reset is invoked when should_run_week_reset is True.

Uses unittest.mock to stub Firestore, repositories, and services.
"""

from __future__ import annotations

from dataclasses import replace
from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock, patch

from models.flat import Flat
from models.task import Task, TaskState
from tests.helpers import make_task

_FLAT_ID = "flat-1"
_NOW = datetime(2025, 6, 15, 12, 0, tzinfo=UTC)


def _flat(reminder_hours: int = 1, grace_hours: int = 1) -> Flat:
    return Flat(
        id=_FLAT_ID,
        name="Test Flat",
        admin_uid="admin",
        invite_code="ABC",
        reminder_hours_before_deadline=reminder_hours,
        grace_period_hours=grace_hours,
    )


def _pending_tasks(count: int, due: datetime) -> list[Task]:
    return [
        replace(
            make_task(i, f"p{i}", TaskState.Pending),
            due_date_time=due,
        )
        for i in range(count)
    ]


@patch("triggers.deadline_check_trigger.WeekResetService")
@patch("triggers.deadline_check_trigger.NotificationService")
@patch("triggers.deadline_check_trigger.TaskRepository")
@patch("triggers.deadline_check_trigger.FlatRepository")
class TestRunForFlatOrchestration:
    """Tests for _run_for_flat — the dispatch loop inside the scheduler."""

    def test_given_9_tasks_in_hours_window_then_each_assignee_gets_exactly_one_notification(
        self,
        mock_flat_repo_cls: MagicMock,
        mock_task_repo_cls: MagicMock,
        mock_notif_svc_cls: MagicMock,
        mock_week_reset_cls: MagicMock,
    ) -> None:
        """Given 9 pending tasks all due in 30 minutes (inside 1h window),
        when _run_for_flat fires, then send_hours_before_reminder is called
        exactly 9 times — once per task."""
        from triggers.deadline_check_trigger import _run_for_flat

        due = _NOW + timedelta(minutes=30)
        tasks = _pending_tasks(9, due)
        flat = _flat(reminder_hours=1)

        mock_flat_repo_cls.return_value.get_flat.return_value = flat
        mock_task_repo_cls.return_value.get_all_tasks.return_value = tasks

        _run_for_flat(_FLAT_ID, _NOW, MagicMock())

        svc = mock_notif_svc_cls.return_value
        assert svc.send_hours_before_reminder.call_count == 9
        assert svc.send_day_before_reminder.call_count == 9

        notified_uids = {
            c.args[1] for c in svc.send_hours_before_reminder.call_args_list
        }
        assert notified_uids == {f"p{i}" for i in range(9)}

    def test_given_deadline_passed_then_no_stale_reminders_only_grace_period(
        self,
        mock_flat_repo_cls: MagicMock,
        mock_task_repo_cls: MagicMock,
        mock_notif_svc_cls: MagicMock,
        mock_week_reset_cls: MagicMock,
    ) -> None:
        """Given 9 tasks all past deadline (reminders unsent), when _run_for_flat
        fires, then NO reminder notifications are sent — only grace period."""
        from triggers.deadline_check_trigger import _run_for_flat

        due = _NOW - timedelta(minutes=30)
        tasks = _pending_tasks(9, due)
        flat = _flat(reminder_hours=1)

        mock_flat_repo_cls.return_value.get_flat.return_value = flat
        mock_task_repo_cls.return_value.get_all_tasks.return_value = tasks

        _run_for_flat(_FLAT_ID, _NOW, MagicMock())

        svc = mock_notif_svc_cls.return_value
        assert svc.send_day_before_reminder.call_count == 0
        assert svc.send_hours_before_reminder.call_count == 0
        assert svc.send_grace_period_notification.call_count == 9

    def test_given_flags_set_from_previous_tick_then_no_duplicate_reminders(
        self,
        mock_flat_repo_cls: MagicMock,
        mock_task_repo_cls: MagicMock,
        mock_notif_svc_cls: MagicMock,
        mock_week_reset_cls: MagicMock,
    ) -> None:
        """Given tasks with hours_before_reminder_sent=True (set by previous tick),
        when _run_for_flat fires again, then no hours-before reminders are sent."""
        from triggers.deadline_check_trigger import _run_for_flat

        due = _NOW + timedelta(minutes=30)
        tasks = [
            replace(t, hours_before_reminder_sent=True, day_before_reminder_sent=True)
            for t in _pending_tasks(9, due)
        ]
        flat = _flat(reminder_hours=1)

        mock_flat_repo_cls.return_value.get_flat.return_value = flat
        mock_task_repo_cls.return_value.get_all_tasks.return_value = tasks

        _run_for_flat(_FLAT_ID, _NOW, MagicMock())

        svc = mock_notif_svc_cls.return_value
        assert svc.send_day_before_reminder.call_count == 0
        assert svc.send_hours_before_reminder.call_count == 0

    def test_given_grace_period_elapsed_then_week_reset_fires(
        self,
        mock_flat_repo_cls: MagicMock,
        mock_task_repo_cls: MagicMock,
        mock_notif_svc_cls: MagicMock,
        mock_week_reset_cls: MagicMock,
    ) -> None:
        """Given all 9 tasks past deadline and grace_period=1h elapsed,
        when _run_for_flat fires, then WeekResetService.week_reset is called."""
        from triggers.deadline_check_trigger import _run_for_flat

        due = _NOW - timedelta(hours=3)
        tasks = _pending_tasks(9, due)
        flat = _flat(grace_hours=1)

        mock_flat_repo_cls.return_value.get_flat.return_value = flat
        mock_task_repo_cls.return_value.get_all_tasks.return_value = tasks

        _run_for_flat(_FLAT_ID, _NOW, MagicMock())

        mock_week_reset_cls.return_value.week_reset.assert_called_once_with(_FLAT_ID)

    def test_given_grace_period_not_elapsed_then_week_reset_does_not_fire(
        self,
        mock_flat_repo_cls: MagicMock,
        mock_task_repo_cls: MagicMock,
        mock_notif_svc_cls: MagicMock,
        mock_week_reset_cls: MagicMock,
    ) -> None:
        """Given all tasks past deadline but only 30 minutes into a 1h grace period,
        when _run_for_flat fires, then week_reset is NOT called."""
        from triggers.deadline_check_trigger import _run_for_flat

        due = _NOW - timedelta(minutes=30)
        tasks = _pending_tasks(9, due)
        flat = _flat(grace_hours=1)

        mock_flat_repo_cls.return_value.get_flat.return_value = flat
        mock_task_repo_cls.return_value.get_all_tasks.return_value = tasks

        _run_for_flat(_FLAT_ID, _NOW, MagicMock())

        mock_week_reset_cls.return_value.week_reset.assert_not_called()

    def test_given_reminder_sent_flag_update_called_per_task(
        self,
        mock_flat_repo_cls: MagicMock,
        mock_task_repo_cls: MagicMock,
        mock_notif_svc_cls: MagicMock,
        mock_week_reset_cls: MagicMock,
    ) -> None:
        """Given 9 tasks needing hours-before reminder, when _run_for_flat fires,
        then update_task is called 9 times to set the hours_before_reminder_sent flag,
        preventing duplicate notifications on the next tick."""
        from triggers.deadline_check_trigger import _run_for_flat

        due = _NOW + timedelta(minutes=30)
        tasks = _pending_tasks(9, due)
        flat = _flat(reminder_hours=1)

        mock_flat_repo_cls.return_value.get_flat.return_value = flat
        mock_task_repo_cls.return_value.get_all_tasks.return_value = tasks

        _run_for_flat(_FLAT_ID, _NOW, MagicMock())

        task_repo = mock_task_repo_cls.return_value
        # 9 updates for day-before flag + 9 updates for hours-before flag = 18 total
        assert task_repo.update_task.call_count == 18

        updated_task_ids = {c.args[1] for c in task_repo.update_task.call_args_list}
        assert updated_task_ids == {f"task-{i}" for i in range(9)}
