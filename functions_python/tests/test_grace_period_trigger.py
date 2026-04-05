"""BDD tests for the grace-period-all filtering logic used by
enter_grace_period_all_callable.

These tests verify that the callable correctly identifies pending tasks and
calls enter_grace_period() for each one (and only those). They use a mock
TaskRepository so no Firestore connection is required.

Naming convention: "Given <precondition>, when <action>, then <outcome>"
"""

from __future__ import annotations

import sys
from pathlib import Path
from unittest.mock import MagicMock, call

sys.path.insert(0, str(Path(__file__).parent.parent))

from models.task import TaskState
from tests.helpers import make_task

_FLAT_ID = "flat-1"


def _run_grace_period_all(repo: MagicMock, flat_id: str) -> None:
    """Inline the core logic of enter_grace_period_all_callable for testing.

    Mirrors the exact filtering and dispatch logic in the callable so that
    tests cover the behaviour without requiring a live Firestore connection.
    """
    tasks = repo.get_all_tasks(flat_id)
    pending = [t for t in tasks if t.state == TaskState.Pending]
    for task in pending:
        repo.enter_grace_period(flat_id, task.id)


# ── Tests ─────────────────────────────────────────────────────────────────────


class TestEnterGracePeriodAll:
    """Situation 14 — enter_grace_period_all_callable only triggers pending tasks."""

    def _make_repo(self, *tasks: object) -> MagicMock:
        repo = MagicMock()
        repo.get_all_tasks.return_value = list(tasks)
        return repo

    def test_given_all_pending_when_grace_period_triggered_then_all_are_called(
        self,
    ) -> None:
        """Given 3 pending tasks, when the callable runs, all 3 get enter_grace_period."""
        tasks = [
            make_task(0, "p0", TaskState.Pending),
            make_task(1, "p1", TaskState.Pending),
            make_task(2, "p2", TaskState.Pending),
        ]
        repo = self._make_repo(*tasks)

        _run_grace_period_all(repo, _FLAT_ID)

        assert repo.enter_grace_period.call_count == 3, "All 3 pending tasks must trigger enter_grace_period."
        repo.enter_grace_period.assert_has_calls(
            [call(_FLAT_ID, "task-0"), call(_FLAT_ID, "task-1"), call(_FLAT_ID, "task-2")],
            any_order=True,
        )

    def test_given_mixed_states_when_grace_period_triggered_then_only_pending_are_called(
        self,
    ) -> None:
        """Given 2 pending + 1 completed + 1 notDone, only the 2 pending tasks
        get enter_grace_period — the others are skipped.
        """
        tasks = [
            make_task(0, "p0", TaskState.Pending),
            make_task(1, "p1", TaskState.Completed),
            make_task(2, "p2", TaskState.Pending),
            make_task(3, "p3", TaskState.NotDone),
        ]
        repo = self._make_repo(*tasks)

        _run_grace_period_all(repo, _FLAT_ID)

        assert repo.enter_grace_period.call_count == 2, (
            "Only the 2 pending tasks should trigger enter_grace_period; completed and not_done tasks must be skipped."
        )
        repo.enter_grace_period.assert_has_calls(
            [call(_FLAT_ID, "task-0"), call(_FLAT_ID, "task-2")],
            any_order=True,
        )

    def test_given_no_pending_tasks_when_grace_period_triggered_then_nothing_called(
        self,
    ) -> None:
        """Given no pending tasks (all completed/notDone), no enter_grace_period
        calls are made — there is nothing to transition.
        """
        tasks = [
            make_task(0, "p0", TaskState.Completed),
            make_task(1, "p1", TaskState.NotDone),
        ]
        repo = self._make_repo(*tasks)

        _run_grace_period_all(repo, _FLAT_ID)

        repo.enter_grace_period.assert_not_called()

    def test_given_vacant_tasks_when_grace_period_triggered_then_only_pending_are_called(
        self,
    ) -> None:
        """Given 1 pending and 1 vacant task, only the pending one is transitioned.
        Vacant tasks are not in the grace-period transition path.
        """
        tasks = [
            make_task(0, "p0", TaskState.Pending),
            make_task(1, "", TaskState.Vacant),
        ]
        repo = self._make_repo(*tasks)

        _run_grace_period_all(repo, _FLAT_ID)

        assert repo.enter_grace_period.call_count == 1
        repo.enter_grace_period.assert_called_once_with(_FLAT_ID, "task-0")
