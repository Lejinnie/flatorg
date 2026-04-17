"""BDD tests for notification trigger Cloud Functions:
  - reminder triggers (day-before and hours-before)
  - notify_task_completed_callable
  - notify_swap_request_callable

Scenarios are named:
  "Given <precondition>, when <action>, then <outcome>"

Uses unittest.mock to stub Firestore, TaskRepository, PersonRepository,
FlatRepository, and NotificationService.

The @https_fn.on_call() decorator wraps callables in Flask/cross_origin layers
that require a full HTTP request context. Tests bypass this by calling the
original unwrapped function via ``fn.__wrapped__.__wrapped__``.
"""

from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, datetime
from typing import Any
from unittest.mock import MagicMock, patch

import pytest

from models.person import Person, PersonRole
from models.task import Task, TaskState


def _unwrap_callable(fn: Callable[..., Any]) -> Callable[..., Any]:
    """Bypass @https_fn.on_call() + @cross_origin decorators to get the
    original function that accepts a CallableRequest-like object.
    """
    return fn.__wrapped__.__wrapped__  # type: ignore[attr-defined, no-any-return]


# ── Fixtures ──────────────────────────────────────────────────────────────────

_FLAT_ID = "flat-1"
_TASK_ID = "task-0"
_ALICE_UID = "alice-uid"
_BOB_UID = "bob-uid"
_SWAP_REQUEST_ID = "swap-1"
_FUTURE = datetime(2099, 1, 1, tzinfo=UTC)


def _make_task(
    task_id: str = _TASK_ID,
    name: str = "Toilet",
    assigned_to: str = _ALICE_UID,
    original_assigned_to: str = "",
) -> Task:
    return Task(
        id=task_id,
        name=name,
        description=[],
        due_date_time=_FUTURE,
        assigned_to=assigned_to,
        original_assigned_to=original_assigned_to,
        state=TaskState.Pending,
        weeks_not_cleaned=0,
        ring_index=0,
    )


def _make_person(uid: str = _ALICE_UID, name: str = "Alice", tokens: int = 3) -> Person:
    return Person(
        uid=uid,
        name=name,
        email=f"{uid}@test.com",
        role=PersonRole.Member,
        on_vacation=False,
        swap_tokens_remaining=tokens,
    )


def _make_flat(reminder_hours: int = 1) -> MagicMock:
    flat = MagicMock()
    flat.reminder_hours_before_deadline = reminder_hours
    return flat


# ═══════════════════════════════════════════════════════════════════════════════
# Day-before reminder trigger
# ═══════════════════════════════════════════════════════════════════════════════


class TestDayBeforeReminderDispatch:
    """Tests for _dispatch_day_before_reminder (helper behind the callable/HTTP triggers)."""

    @patch("triggers.reminder_trigger.NotificationService")
    @patch("triggers.reminder_trigger.TaskRepository")
    @patch("triggers.reminder_trigger.firestore")
    def test_given_task_has_assignee_when_dispatched_then_reminder_sent(
        self,
        mock_firestore: MagicMock,
        mock_task_repo_cls: MagicMock,
        mock_notif_svc_cls: MagicMock,
    ) -> None:
        """Given a task with a valid assignee, when _dispatch_day_before_reminder
        is called, then send_day_before_reminder is invoked with the correct args.
        """
        from triggers.reminder_trigger import _dispatch_day_before_reminder

        task = _make_task()
        mock_task_repo_cls.return_value.get_task.return_value = task

        _dispatch_day_before_reminder(_FLAT_ID, _TASK_ID)

        mock_notif_svc_cls.return_value.send_day_before_reminder.assert_called_once_with(
            _FLAT_ID,
            _ALICE_UID,
            "Toilet",
        )

    @patch("triggers.reminder_trigger.NotificationService")
    @patch("triggers.reminder_trigger.TaskRepository")
    @patch("triggers.reminder_trigger.firestore")
    def test_given_task_has_no_assignee_when_dispatched_then_nothing_sent(
        self,
        mock_firestore: MagicMock,
        mock_task_repo_cls: MagicMock,
        mock_notif_svc_cls: MagicMock,
    ) -> None:
        """Given a vacant task (no assignee), when _dispatch_day_before_reminder
        is called, then no notification is sent.
        """
        from triggers.reminder_trigger import _dispatch_day_before_reminder

        task = _make_task(assigned_to="")
        mock_task_repo_cls.return_value.get_task.return_value = task

        _dispatch_day_before_reminder(_FLAT_ID, _TASK_ID)

        mock_notif_svc_cls.return_value.send_day_before_reminder.assert_not_called()

    @patch("triggers.reminder_trigger.NotificationService")
    @patch("triggers.reminder_trigger.TaskRepository")
    @patch("triggers.reminder_trigger.firestore")
    def test_given_task_was_swapped_when_dispatched_then_original_assignee_notified(
        self,
        mock_firestore: MagicMock,
        mock_task_repo_cls: MagicMock,
        mock_notif_svc_cls: MagicMock,
    ) -> None:
        """Given a task with original_assigned_to set (swap active), when
        _dispatch_day_before_reminder is called, then the original assignee
        is notified (effective_assigned_to resolves to original).
        """
        from triggers.reminder_trigger import _dispatch_day_before_reminder

        task = _make_task(assigned_to=_BOB_UID, original_assigned_to=_ALICE_UID)
        mock_task_repo_cls.return_value.get_task.return_value = task

        _dispatch_day_before_reminder(_FLAT_ID, _TASK_ID)

        mock_notif_svc_cls.return_value.send_day_before_reminder.assert_called_once_with(
            _FLAT_ID,
            _ALICE_UID,
            "Toilet",
        )


# ═══════════════════════════════════════════════════════════════════════════════
# Hours-before reminder trigger
# ═══════════════════════════════════════════════════════════════════════════════


class TestHoursBeforeReminderDispatch:
    """Tests for _dispatch_hours_before_reminder."""

    @patch("triggers.reminder_trigger.NotificationService")
    @patch("triggers.reminder_trigger.FlatRepository")
    @patch("triggers.reminder_trigger.TaskRepository")
    @patch("triggers.reminder_trigger.firestore")
    def test_given_flat_has_2h_reminder_when_dispatched_then_hours_param_is_2(
        self,
        mock_firestore: MagicMock,
        mock_task_repo_cls: MagicMock,
        mock_flat_repo_cls: MagicMock,
        mock_notif_svc_cls: MagicMock,
    ) -> None:
        """Given the flat's reminder_hours_before_deadline is 2, when
        _dispatch_hours_before_reminder is called, then the notification
        includes hours_remaining=2.
        """
        from triggers.reminder_trigger import _dispatch_hours_before_reminder

        task = _make_task()
        mock_task_repo_cls.return_value.get_task.return_value = task
        mock_flat_repo_cls.return_value.get_flat.return_value = _make_flat(reminder_hours=2)

        _dispatch_hours_before_reminder(_FLAT_ID, _TASK_ID)

        mock_notif_svc_cls.return_value.send_hours_before_reminder.assert_called_once_with(
            _FLAT_ID,
            _ALICE_UID,
            "Toilet",
            2,
        )

    @patch("triggers.reminder_trigger.NotificationService")
    @patch("triggers.reminder_trigger.FlatRepository")
    @patch("triggers.reminder_trigger.TaskRepository")
    @patch("triggers.reminder_trigger.firestore")
    def test_given_vacant_task_when_hours_reminder_dispatched_then_nothing_sent(
        self,
        mock_firestore: MagicMock,
        mock_task_repo_cls: MagicMock,
        mock_flat_repo_cls: MagicMock,
        mock_notif_svc_cls: MagicMock,
    ) -> None:
        """Given a vacant task, when _dispatch_hours_before_reminder is called,
        then no notification is sent.
        """
        from triggers.reminder_trigger import _dispatch_hours_before_reminder

        task = _make_task(assigned_to="")
        mock_task_repo_cls.return_value.get_task.return_value = task
        mock_flat_repo_cls.return_value.get_flat.return_value = _make_flat()

        _dispatch_hours_before_reminder(_FLAT_ID, _TASK_ID)

        mock_notif_svc_cls.return_value.send_hours_before_reminder.assert_not_called()


# ═══════════════════════════════════════════════════════════════════════════════
# Task completed trigger
# ═══════════════════════════════════════════════════════════════════════════════


class TestNotifyTaskCompletedCallable:
    """Tests for notify_task_completed_callable."""

    @patch("triggers.notify_task_completed_trigger.NotificationService")
    @patch("triggers.notify_task_completed_trigger.PersonRepository")
    @patch("triggers.notify_task_completed_trigger.TaskRepository")
    @patch("triggers.notify_task_completed_trigger.firestore")
    def test_given_valid_payload_when_called_then_fcm_and_in_app_both_fire(
        self,
        mock_firestore: MagicMock,
        mock_task_repo_cls: MagicMock,
        mock_person_repo_cls: MagicMock,
        mock_notif_svc_cls: MagicMock,
    ) -> None:
        """Given a valid flatId/taskId/completedByUid, when the callable fires,
        then both send_task_completed_notification (FCM) and
        write_in_app_notifications_to_all (Firestore) are called.
        """
        from triggers.notify_task_completed_trigger import notify_task_completed_callable

        task = _make_task(name="Toilet")
        person = _make_person(name="Alice")
        mock_task_repo_cls.return_value.get_task.return_value = task
        mock_person_repo_cls.return_value.get_member.return_value = person

        req = MagicMock()
        req.data = {"flatId": _FLAT_ID, "taskId": _TASK_ID, "completedByUid": _ALICE_UID}

        result = _unwrap_callable(notify_task_completed_callable)(req)

        assert result == {"success": True}
        svc = mock_notif_svc_cls.return_value
        svc.send_task_completed_notification.assert_called_once_with(
            _FLAT_ID,
            "Alice",
            "Toilet",
        )
        svc.write_in_app_notifications_to_all.assert_called_once()
        call_args = svc.write_in_app_notifications_to_all.call_args
        assert call_args.args[0] == _FLAT_ID
        assert call_args.args[1] == "task_completed"

    def test_given_missing_flat_id_when_called_then_raises_invalid_argument(self) -> None:
        """Given payload is missing flatId, when the callable fires,
        then an HttpsError with INVALID_ARGUMENT is raised.
        """
        from firebase_functions import https_fn

        from triggers.notify_task_completed_trigger import notify_task_completed_callable

        req = MagicMock()
        req.data = {"taskId": _TASK_ID, "completedByUid": _ALICE_UID}

        with pytest.raises(https_fn.HttpsError):
            _unwrap_callable(notify_task_completed_callable)(req)

    def test_given_missing_completed_by_uid_when_called_then_raises_invalid_argument(self) -> None:
        """Given payload is missing completedByUid, when the callable fires,
        then an HttpsError with INVALID_ARGUMENT is raised.
        """
        from firebase_functions import https_fn

        from triggers.notify_task_completed_trigger import notify_task_completed_callable

        req = MagicMock()
        req.data = {"flatId": _FLAT_ID, "taskId": _TASK_ID}

        with pytest.raises(https_fn.HttpsError):
            _unwrap_callable(notify_task_completed_callable)(req)


# ═══════════════════════════════════════════════════════════════════════════════
# Swap request trigger
# ═══════════════════════════════════════════════════════════════════════════════


class TestNotifySwapRequestCallable:
    """Tests for notify_swap_request_callable."""

    @patch("triggers.notify_swap_request_trigger.NotificationService")
    @patch("triggers.notify_swap_request_trigger.PersonRepository")
    @patch("triggers.notify_swap_request_trigger.TaskRepository")
    @patch("triggers.notify_swap_request_trigger.firestore")
    def test_given_valid_swap_request_when_called_then_fcm_sent_to_target(
        self,
        mock_firestore: MagicMock,
        mock_task_repo_cls: MagicMock,
        mock_person_repo_cls: MagicMock,
        mock_notif_svc_cls: MagicMock,
    ) -> None:
        """Given a valid swap request with requester and target, when the callable
        fires, then send_swap_request_notification is called for the target.
        """
        from triggers.notify_swap_request_trigger import notify_swap_request_callable

        # Mock the swap request document.
        swap_doc = MagicMock()
        swap_doc.exists = True
        swap_doc.to_dict.return_value = {
            "requester_uid": _ALICE_UID,
            "target_task_id": "task-1",
        }
        db_chain = mock_firestore.Client.return_value.collection.return_value
        db_chain.document.return_value.collection.return_value.document.return_value.get.return_value = swap_doc

        target_task = _make_task(task_id="task-1", assigned_to=_BOB_UID)
        mock_task_repo_cls.return_value.get_task.return_value = target_task

        requester = _make_person(uid=_ALICE_UID, name="Alice", tokens=2)
        mock_person_repo_cls.return_value.get_member.return_value = requester

        req = MagicMock()
        req.data = {"flatId": _FLAT_ID, "swapRequestId": _SWAP_REQUEST_ID}

        result = _unwrap_callable(notify_swap_request_callable)(req)

        assert result == {"success": True}
        mock_notif_svc_cls.return_value.send_swap_request_notification.assert_called_once_with(
            _FLAT_ID,
            _BOB_UID,
            "Alice",
            2,
        )

    @patch("triggers.notify_swap_request_trigger.firestore")
    def test_given_swap_request_not_found_when_called_then_skipped(
        self,
        mock_firestore: MagicMock,
    ) -> None:
        """Given the swap request document does not exist (auto-accepted), when
        the callable fires, then it returns success with skipped reason.
        """
        from triggers.notify_swap_request_trigger import notify_swap_request_callable

        swap_doc = MagicMock()
        swap_doc.exists = False
        db_chain = mock_firestore.Client.return_value.collection.return_value
        db_chain.document.return_value.collection.return_value.document.return_value.get.return_value = swap_doc

        req = MagicMock()
        req.data = {"flatId": _FLAT_ID, "swapRequestId": _SWAP_REQUEST_ID}

        result = _unwrap_callable(notify_swap_request_callable)(req)

        assert result["success"] is True
        assert "skipped" in result

    @patch("triggers.notify_swap_request_trigger.NotificationService")
    @patch("triggers.notify_swap_request_trigger.PersonRepository")
    @patch("triggers.notify_swap_request_trigger.TaskRepository")
    @patch("triggers.notify_swap_request_trigger.firestore")
    def test_given_target_task_is_vacant_when_called_then_skipped(
        self,
        mock_firestore: MagicMock,
        mock_task_repo_cls: MagicMock,
        mock_person_repo_cls: MagicMock,
        mock_notif_svc_cls: MagicMock,
    ) -> None:
        """Given the target task has no assignee (vacant), when the callable fires,
        then no notification is sent and the result indicates skipped.
        """
        from triggers.notify_swap_request_trigger import notify_swap_request_callable

        swap_doc = MagicMock()
        swap_doc.exists = True
        swap_doc.to_dict.return_value = {
            "requester_uid": _ALICE_UID,
            "target_task_id": "task-1",
        }
        db_chain = mock_firestore.Client.return_value.collection.return_value
        db_chain.document.return_value.collection.return_value.document.return_value.get.return_value = swap_doc

        vacant_task = _make_task(task_id="task-1", assigned_to="")
        mock_task_repo_cls.return_value.get_task.return_value = vacant_task

        req = MagicMock()
        req.data = {"flatId": _FLAT_ID, "swapRequestId": _SWAP_REQUEST_ID}

        result = _unwrap_callable(notify_swap_request_callable)(req)

        assert result["success"] is True
        assert "skipped" in result
        mock_notif_svc_cls.return_value.send_swap_request_notification.assert_not_called()

    def test_given_missing_flat_id_when_called_then_raises_invalid_argument(self) -> None:
        """Given payload is missing flatId, when the callable fires,
        then an HttpsError with INVALID_ARGUMENT is raised.
        """
        from firebase_functions import https_fn

        from triggers.notify_swap_request_trigger import notify_swap_request_callable

        req = MagicMock()
        req.data = {"swapRequestId": _SWAP_REQUEST_ID}

        with pytest.raises(https_fn.HttpsError):
            _unwrap_callable(notify_swap_request_callable)(req)

    def test_given_missing_swap_request_id_when_called_then_raises_invalid_argument(self) -> None:
        """Given payload is missing swapRequestId, when the callable fires,
        then an HttpsError with INVALID_ARGUMENT is raised.
        """
        from firebase_functions import https_fn

        from triggers.notify_swap_request_trigger import notify_swap_request_callable

        req = MagicMock()
        req.data = {"flatId": _FLAT_ID}

        with pytest.raises(https_fn.HttpsError):
            _unwrap_callable(notify_swap_request_callable)(req)
