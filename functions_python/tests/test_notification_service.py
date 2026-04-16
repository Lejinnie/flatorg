"""BDD tests for NotificationService.

Scenarios are named:
  "Given <precondition>, when <action>, then <outcome>"

Uses unittest.mock to stub firebase_admin.messaging and Firestore.
"""

from __future__ import annotations

from unittest.mock import MagicMock, call, patch

import pytest

from models.person import Person, PersonRole
from services.notification_service import NotificationService

# ── Fixtures ──────────────────────────────────────────────────────────────────

_FLAT_ID = "flat-1"
_ALICE_UID = "alice-uid"
_BOB_UID = "bob-uid"
_CARLA_UID = "carla-uid"
_ALICE_TOKEN = "fcm-token-alice"
_BOB_TOKEN = "fcm-token-bob"
_CARLA_TOKEN = "fcm-token-carla"


def _make_member_doc(uid: str, token: str | None = None) -> MagicMock:
    """Build a mock Firestore member document with an optional FCM token."""
    doc = MagicMock()
    data: dict = {"name": uid, "email": f"{uid}@test.com"}
    if token:
        data["fcm_token"] = token
    doc.to_dict.return_value = data
    return doc


def _make_person(uid: str, tokens: int = 3) -> Person:
    return Person(
        uid=uid,
        name=uid,
        email=f"{uid}@test.com",
        role=PersonRole.Member,
        on_vacation=False,
        swap_tokens_remaining=tokens,
    )


def _build_db_mock(
    member_docs: dict[str, MagicMock] | None = None,
) -> MagicMock:
    """Build a mock Firestore Client with optional member docs for token lookup."""
    db = MagicMock()

    def _get_member_doc(uid: str) -> MagicMock:
        doc = MagicMock()
        if member_docs and uid in member_docs:
            doc.get.return_value = member_docs[uid]
        else:
            doc.get.return_value = _make_member_doc(uid)
        return doc

    def _collection_side_effect(name: str) -> MagicMock:
        col = MagicMock()
        flat_doc = MagicMock()

        def _members_col(name2: str) -> MagicMock:
            members_col = MagicMock()
            members_col.document = _get_member_doc
            return members_col

        flat_doc.collection = _members_col
        col.document.return_value = flat_doc
        return col

    db.collection = _collection_side_effect
    return db


def _build_svc(
    tokens: dict[str, str] | None = None,
    all_members: list[Person] | None = None,
) -> tuple[NotificationService, MagicMock]:
    """Build a NotificationService with mocked Firestore token lookups.

    Returns the service and the underlying db mock.
    """
    tokens = tokens or {}
    db = MagicMock()

    # Stub _get_fcm_token via the Firestore document chain.
    def _fake_get(flat_id: str, uid: str) -> str | None:
        return tokens.get(uid)

    svc = NotificationService(db)
    svc._get_fcm_token = MagicMock(side_effect=_fake_get)  # type: ignore[method-assign]

    if all_members is not None:
        svc._get_all_fcm_tokens = MagicMock(  # type: ignore[method-assign]
            return_value=[t for t in tokens.values() if t],
        )

    svc._person_repo = MagicMock()
    if all_members is not None:
        svc._person_repo.get_all_members.return_value = all_members

    return svc, db


# ═══════════════════════════════════════════════════════════════════════════════
# In-app notification writes
# ═══════════════════════════════════════════════════════════════════════════════


class TestWriteInAppNotification:
    """Tests for write_in_app_notification — single-user Firestore doc writes."""

    def test_given_valid_args_when_write_called_then_firestore_doc_is_set(self) -> None:
        """Given valid flat/uid/type, when write_in_app_notification is called,
        then a Firestore document is created with the correct fields."""
        db = MagicMock()
        svc = NotificationService(db)

        svc.write_in_app_notification(
            _FLAT_ID, _ALICE_UID, "reminder", "Title", "Body", "task-0",
        )

        # Verify the chain: collection → doc → collection → doc → collection → doc → set
        db.collection.assert_called_once()
        set_call = db.collection().document().collection().document().collection().document().set
        set_call.assert_called_once()
        written_data = set_call.call_args[0][0]
        assert written_data["type"] == "reminder"
        assert written_data["title"] == "Title"
        assert written_data["body"] == "Body"
        assert written_data["task_id"] == "task-0"

    def test_given_firestore_error_when_write_called_then_no_exception_raised(self) -> None:
        """Given Firestore throws, when write_in_app_notification is called,
        then the error is logged but not re-raised."""
        db = MagicMock()
        db.collection().document().collection().document().collection().document().set.side_effect = Exception("Firestore down")
        svc = NotificationService(db)

        # Should not raise.
        svc.write_in_app_notification(_FLAT_ID, _ALICE_UID, "reminder", "T", "B")


class TestWriteInAppNotificationsToAll:
    """Tests for write_in_app_notifications_to_all — broadcast to every member."""

    def test_given_3_members_when_broadcast_called_then_3_docs_written(self) -> None:
        """Given a flat with 3 members, when write_in_app_notifications_to_all is
        called, then one document is written per member."""
        members = [_make_person("p0"), _make_person("p1"), _make_person("p2")]
        svc, _ = _build_svc(all_members=members)
        svc._person_repo.get_all_members.return_value = members
        svc.write_in_app_notification = MagicMock()  # type: ignore[method-assign]

        svc.write_in_app_notifications_to_all(
            _FLAT_ID, "task_completed", "Done!", "Someone finished.",
        )

        assert svc.write_in_app_notification.call_count == 3
        written_uids = [c.args[1] for c in svc.write_in_app_notification.call_args_list]
        assert set(written_uids) == {"p0", "p1", "p2"}


# ═══════════════════════════════════════════════════════════════════════════════
# FCM send helpers
# ═══════════════════════════════════════════════════════════════════════════════


class TestSendToToken:
    """Tests for _send_to_token — single FCM push."""

    @patch("services.notification_service.messaging")
    def test_given_valid_token_when_send_called_then_fcm_message_sent(
        self, mock_messaging: MagicMock,
    ) -> None:
        """Given a valid FCM token, when _send_to_token is called,
        then messaging.send is invoked with correct token and notification args."""
        db = MagicMock()
        svc = NotificationService(db)

        svc._send_to_token("fake-token", "Title", "Body")

        mock_messaging.send.assert_called_once()
        # Verify Message was constructed with the right token.
        mock_messaging.Message.assert_called_once()
        msg_kwargs = mock_messaging.Message.call_args
        assert msg_kwargs.kwargs.get("token") == "fake-token"
        # Verify Notification was constructed with title and body.
        mock_messaging.Notification.assert_called_once_with(title="Title", body="Body")

    @patch("services.notification_service.messaging")
    def test_given_fcm_error_when_send_called_then_no_exception_raised(
        self, mock_messaging: MagicMock,
    ) -> None:
        """Given FCM throws, when _send_to_token is called,
        then the error is logged but not re-raised."""
        mock_messaging.send.side_effect = Exception("FCM unavailable")
        db = MagicMock()
        svc = NotificationService(db)

        # Should not raise.
        svc._send_to_token("fake-token", "Title", "Body")


class TestSendToMultipleTokens:
    """Tests for _send_to_multiple_tokens — multicast FCM push."""

    @patch("services.notification_service.messaging")
    def test_given_3_tokens_when_multicast_called_then_send_each_for_multicast_invoked(
        self, mock_messaging: MagicMock,
    ) -> None:
        """Given 3 FCM tokens, when _send_to_multiple_tokens is called,
        then messaging.send_each_for_multicast is invoked with all tokens."""
        db = MagicMock()
        svc = NotificationService(db)
        tokens = ["token-a", "token-b", "token-c"]

        svc._send_to_multiple_tokens(tokens, "Title", "Body")

        mock_messaging.send_each_for_multicast.assert_called_once()
        # Verify MulticastMessage was constructed with the right tokens.
        mock_messaging.MulticastMessage.assert_called_once()
        mc_kwargs = mock_messaging.MulticastMessage.call_args
        assert mc_kwargs.kwargs.get("tokens") == tokens

    @patch("services.notification_service.messaging")
    def test_given_empty_tokens_when_multicast_called_then_nothing_sent(
        self, mock_messaging: MagicMock,
    ) -> None:
        """Given an empty token list, when _send_to_multiple_tokens is called,
        then no FCM call is made."""
        db = MagicMock()
        svc = NotificationService(db)

        svc._send_to_multiple_tokens([], "Title", "Body")

        mock_messaging.send_each_for_multicast.assert_not_called()


# ═══════════════════════════════════════════════════════════════════════════════
# Day-before reminder
# ═══════════════════════════════════════════════════════════════════════════════


class TestSendDayBeforeReminder:
    """Tests for send_day_before_reminder — FCM push + in-app doc."""

    @patch("services.notification_service.messaging")
    def test_given_assignee_has_fcm_token_when_reminder_sent_then_fcm_and_in_app_both_fire(
        self, mock_messaging: MagicMock,
    ) -> None:
        """Given the assignee has an FCM token, when send_day_before_reminder is called,
        then both an FCM push and an in-app Firestore doc are created."""
        svc, _ = _build_svc(tokens={_ALICE_UID: _ALICE_TOKEN})
        svc.write_in_app_notification = MagicMock()  # type: ignore[method-assign]

        svc.send_day_before_reminder(_FLAT_ID, _ALICE_UID, "Toilet", "task-0")

        svc._get_fcm_token.assert_called_once_with(_FLAT_ID, _ALICE_UID)
        mock_messaging.send.assert_called_once()
        svc.write_in_app_notification.assert_called_once()
        written_args = svc.write_in_app_notification.call_args
        assert written_args.args[2] == "reminder"  # notif_type
        assert "Toilet" in written_args.args[4]  # body contains task name

    @patch("services.notification_service.messaging")
    def test_given_assignee_has_no_fcm_token_when_reminder_sent_then_only_in_app_fires(
        self, mock_messaging: MagicMock,
    ) -> None:
        """Given the assignee has no FCM token, when send_day_before_reminder is called,
        then only the in-app notification is written (no FCM push)."""
        svc, _ = _build_svc(tokens={_ALICE_UID: ""})
        svc._get_fcm_token.return_value = None  # type: ignore[attr-defined]
        svc.write_in_app_notification = MagicMock()  # type: ignore[method-assign]

        svc.send_day_before_reminder(_FLAT_ID, _ALICE_UID, "Toilet")

        mock_messaging.send.assert_not_called()
        svc.write_in_app_notification.assert_called_once()


# ═══════════════════════════════════════════════════════════════════════════════
# Hours-before reminder
# ═══════════════════════════════════════════════════════════════════════════════


class TestSendHoursBeforeReminder:
    """Tests for send_hours_before_reminder — FCM push + in-app doc."""

    @patch("services.notification_service.messaging")
    def test_given_token_exists_when_hours_reminder_sent_then_body_contains_hours(
        self, mock_messaging: MagicMock,
    ) -> None:
        """Given the assignee has an FCM token, when send_hours_before_reminder
        is called with hours=2, then the notification body mentions '2 hour(s)'."""
        svc, _ = _build_svc(tokens={_ALICE_UID: _ALICE_TOKEN})
        svc.write_in_app_notification = MagicMock()  # type: ignore[method-assign]

        svc.send_hours_before_reminder(_FLAT_ID, _ALICE_UID, "Kitchen", 2, "task-1")

        mock_messaging.send.assert_called_once()
        svc.write_in_app_notification.assert_called_once()
        body = svc.write_in_app_notification.call_args.args[4]
        assert "2 hour(s)" in body


# ═══════════════════════════════════════════════════════════════════════════════
# Task completed notification
# ═══════════════════════════════════════════════════════════════════════════════


class TestSendTaskCompletedNotification:
    """Tests for send_task_completed_notification — FCM multicast to all members."""

    @patch("services.notification_service.messaging")
    def test_given_3_members_with_tokens_when_task_completed_then_multicast_sent(
        self, mock_messaging: MagicMock,
    ) -> None:
        """Given 3 members all with FCM tokens, when send_task_completed_notification
        is called, then a multicast message is sent to all 3 tokens."""
        members = [_make_person("p0"), _make_person("p1"), _make_person("p2")]
        svc, _ = _build_svc(
            tokens={"p0": "t0", "p1": "t1", "p2": "t2"},
            all_members=members,
        )

        svc.send_task_completed_notification(_FLAT_ID, "Alice", "Toilet")

        mock_messaging.send_each_for_multicast.assert_called_once()
        # Verify MulticastMessage constructor was called with correct tokens.
        mock_messaging.MulticastMessage.assert_called_once()
        mc_kwargs = mock_messaging.MulticastMessage.call_args.kwargs
        assert set(mc_kwargs["tokens"]) == {"t0", "t1", "t2"}
        # Verify Notification was constructed with the expected body content.
        mock_messaging.Notification.assert_called_once()
        notif_kwargs = mock_messaging.Notification.call_args.kwargs
        assert "Alice" in notif_kwargs["body"]
        assert "Toilet" in notif_kwargs["body"]

    @patch("services.notification_service.messaging")
    def test_given_no_members_have_tokens_when_task_completed_then_no_multicast(
        self, mock_messaging: MagicMock,
    ) -> None:
        """Given no members have FCM tokens, when send_task_completed_notification
        is called, then no multicast is attempted."""
        svc, _ = _build_svc(tokens={}, all_members=[])
        svc._get_all_fcm_tokens.return_value = []  # type: ignore[attr-defined]

        svc.send_task_completed_notification(_FLAT_ID, "Alice", "Toilet")

        mock_messaging.send_each_for_multicast.assert_not_called()


# ═══════════════════════════════════════════════════════════════════════════════
# Grace period notification
# ═══════════════════════════════════════════════════════════════════════════════


class TestSendGracePeriodNotification:
    """Tests for send_grace_period_notification — FCM push + in-app doc."""

    @patch("services.notification_service.messaging")
    def test_given_token_exists_when_grace_period_sent_then_body_has_hours(
        self, mock_messaging: MagicMock,
    ) -> None:
        """Given the assignee has an FCM token, when send_grace_period_notification
        is called, then the body mentions the hours until reset."""
        svc, _ = _build_svc(tokens={_ALICE_UID: _ALICE_TOKEN})
        svc.write_in_app_notification = MagicMock()  # type: ignore[method-assign]

        svc.send_grace_period_notification(_FLAT_ID, _ALICE_UID, "Shower", 3, "task-3")

        mock_messaging.send.assert_called_once()
        svc.write_in_app_notification.assert_called_once()
        body = svc.write_in_app_notification.call_args.args[4]
        assert "3 hour(s)" in body
        assert "Shower" in body

    @patch("services.notification_service.messaging")
    def test_given_no_token_when_grace_period_sent_then_only_in_app(
        self, mock_messaging: MagicMock,
    ) -> None:
        """Given no FCM token, when send_grace_period_notification is called,
        then only the in-app notification is written."""
        svc, _ = _build_svc(tokens={})
        svc._get_fcm_token.return_value = None  # type: ignore[attr-defined]
        svc.write_in_app_notification = MagicMock()  # type: ignore[method-assign]

        svc.send_grace_period_notification(_FLAT_ID, _ALICE_UID, "Shower", 3)

        mock_messaging.send.assert_not_called()
        svc.write_in_app_notification.assert_called_once()


# ═══════════════════════════════════════════════════════════════════════════════
# Swap request notification
# ═══════════════════════════════════════════════════════════════════════════════


class TestSendSwapRequestNotification:
    """Tests for send_swap_request_notification — FCM push only (no in-app doc)."""

    @patch("services.notification_service.messaging")
    def test_given_target_has_token_when_swap_request_sent_then_fcm_push_fires(
        self, mock_messaging: MagicMock,
    ) -> None:
        """Given the target person has an FCM token, when send_swap_request_notification
        is called, then an FCM push is sent with the requester's name and token count."""
        svc, _ = _build_svc(tokens={_BOB_UID: _BOB_TOKEN})

        svc.send_swap_request_notification(_FLAT_ID, _BOB_UID, "Alice", 2)

        mock_messaging.send.assert_called_once()
        # Verify Message constructor was called with the correct token.
        mock_messaging.Message.assert_called_once()
        msg_kwargs = mock_messaging.Message.call_args.kwargs
        assert msg_kwargs["token"] == _BOB_TOKEN
        # Verify Notification body contains requester name and token count.
        mock_messaging.Notification.assert_called_once()
        notif_kwargs = mock_messaging.Notification.call_args.kwargs
        assert "Alice" in notif_kwargs["body"]
        assert "2" in notif_kwargs["body"]

    @patch("services.notification_service.messaging")
    def test_given_target_has_no_token_when_swap_request_sent_then_nothing_sent(
        self, mock_messaging: MagicMock,
    ) -> None:
        """Given the target person has no FCM token, when send_swap_request_notification
        is called, then no FCM call is made (silent no-op)."""
        svc, _ = _build_svc(tokens={})
        svc._get_fcm_token.return_value = None  # type: ignore[attr-defined]

        svc.send_swap_request_notification(_FLAT_ID, _BOB_UID, "Alice", 2)

        mock_messaging.send.assert_not_called()


# ═══════════════════════════════════════════════════════════════════════════════
# FCM token retrieval helpers
# ═══════════════════════════════════════════════════════════════════════════════


class TestGetFcmToken:
    """Tests for _get_fcm_token — reads token from Firestore member doc."""

    def test_given_member_has_token_when_get_called_then_token_returned(self) -> None:
        """Given a member document with fcm_token set, when _get_fcm_token is called,
        then the token string is returned."""
        db = _build_db_mock(
            member_docs={_ALICE_UID: _make_member_doc(_ALICE_UID, _ALICE_TOKEN)},
        )
        svc = NotificationService(db)

        result = svc._get_fcm_token(_FLAT_ID, _ALICE_UID)

        assert result == _ALICE_TOKEN

    def test_given_member_has_no_token_when_get_called_then_none_returned(self) -> None:
        """Given a member document without fcm_token, when _get_fcm_token is called,
        then None is returned."""
        db = _build_db_mock(
            member_docs={_ALICE_UID: _make_member_doc(_ALICE_UID, None)},
        )
        svc = NotificationService(db)

        result = svc._get_fcm_token(_FLAT_ID, _ALICE_UID)

        assert result is None

    def test_given_member_has_empty_token_when_get_called_then_none_returned(self) -> None:
        """Given a member document with fcm_token = '', when _get_fcm_token is called,
        then None is returned (empty string treated as absent)."""
        db = _build_db_mock(
            member_docs={_ALICE_UID: _make_member_doc(_ALICE_UID, "")},
        )
        svc = NotificationService(db)

        result = svc._get_fcm_token(_FLAT_ID, _ALICE_UID)

        assert result is None


class TestGetAllFcmTokens:
    """Tests for _get_all_fcm_tokens — collects tokens from all flat members."""

    def test_given_3_members_all_with_tokens_when_called_then_3_tokens_returned(self) -> None:
        """Given 3 members all with FCM tokens, when _get_all_fcm_tokens is called,
        then all 3 tokens are returned."""
        members = [_make_person("p0"), _make_person("p1"), _make_person("p2")]
        db = MagicMock()
        svc = NotificationService(db)
        svc._person_repo = MagicMock()
        svc._person_repo.get_all_members.return_value = members

        token_map = {"p0": "t0", "p1": "t1", "p2": "t2"}
        svc._get_fcm_token = MagicMock(side_effect=lambda fid, uid: token_map.get(uid))  # type: ignore[method-assign]

        result = svc._get_all_fcm_tokens(_FLAT_ID)

        assert len(result) == 3
        assert set(result) == {"t0", "t1", "t2"}

    def test_given_some_members_missing_tokens_when_called_then_only_valid_returned(self) -> None:
        """Given 3 members but only 2 have tokens, when _get_all_fcm_tokens is called,
        then only the 2 valid tokens are returned."""
        members = [_make_person("p0"), _make_person("p1"), _make_person("p2")]
        db = MagicMock()
        svc = NotificationService(db)
        svc._person_repo = MagicMock()
        svc._person_repo.get_all_members.return_value = members

        token_map = {"p0": "t0", "p1": None, "p2": "t2"}
        svc._get_fcm_token = MagicMock(side_effect=lambda fid, uid: token_map.get(uid))  # type: ignore[method-assign]

        result = svc._get_all_fcm_tokens(_FLAT_ID)

        assert len(result) == 2
        assert set(result) == {"t0", "t2"}


# ═══════════════════════════════════════════════════════════════════════════════
# No duplicate notifications — each method sends exactly once
# ═══════════════════════════════════════════════════════════════════════════════


class TestNoDuplicateNotifications:
    """Verify that each notification method fires exactly once per call
    — no accidental double-sends of FCM pushes or in-app documents."""

    @patch("services.notification_service.messaging")
    def test_day_before_reminder_sends_exactly_one_fcm_and_one_in_app(
        self, mock_messaging: MagicMock,
    ) -> None:
        """Given an assignee with an FCM token, when send_day_before_reminder
        is called once, then exactly 1 FCM push and 1 in-app doc are written."""
        svc, _ = _build_svc(tokens={_ALICE_UID: _ALICE_TOKEN})
        svc.write_in_app_notification = MagicMock()  # type: ignore[method-assign]

        svc.send_day_before_reminder(_FLAT_ID, _ALICE_UID, "Toilet", "task-0")

        assert mock_messaging.send.call_count == 1
        assert svc.write_in_app_notification.call_count == 1

    @patch("services.notification_service.messaging")
    def test_hours_before_reminder_sends_exactly_one_fcm_and_one_in_app(
        self, mock_messaging: MagicMock,
    ) -> None:
        """Given an assignee with an FCM token, when send_hours_before_reminder
        is called once, then exactly 1 FCM push and 1 in-app doc are written."""
        svc, _ = _build_svc(tokens={_ALICE_UID: _ALICE_TOKEN})
        svc.write_in_app_notification = MagicMock()  # type: ignore[method-assign]

        svc.send_hours_before_reminder(_FLAT_ID, _ALICE_UID, "Kitchen", 2, "task-1")

        assert mock_messaging.send.call_count == 1
        assert svc.write_in_app_notification.call_count == 1

    @patch("services.notification_service.messaging")
    def test_task_completed_sends_exactly_one_multicast(
        self, mock_messaging: MagicMock,
    ) -> None:
        """Given 3 members with tokens, when send_task_completed_notification
        is called once, then exactly 1 multicast call is made (not 3 individual sends)."""
        members = [_make_person("p0"), _make_person("p1"), _make_person("p2")]
        svc, _ = _build_svc(
            tokens={"p0": "t0", "p1": "t1", "p2": "t2"},
            all_members=members,
        )

        svc.send_task_completed_notification(_FLAT_ID, "Alice", "Toilet")

        assert mock_messaging.send_each_for_multicast.call_count == 1
        # No individual send calls should be made — only multicast.
        mock_messaging.send.assert_not_called()

    @patch("services.notification_service.messaging")
    def test_grace_period_sends_exactly_one_fcm_and_one_in_app(
        self, mock_messaging: MagicMock,
    ) -> None:
        """Given an assignee with an FCM token, when send_grace_period_notification
        is called once, then exactly 1 FCM push and 1 in-app doc are written."""
        svc, _ = _build_svc(tokens={_ALICE_UID: _ALICE_TOKEN})
        svc.write_in_app_notification = MagicMock()  # type: ignore[method-assign]

        svc.send_grace_period_notification(_FLAT_ID, _ALICE_UID, "Shower", 3, "task-3")

        assert mock_messaging.send.call_count == 1
        assert svc.write_in_app_notification.call_count == 1

    @patch("services.notification_service.messaging")
    def test_swap_request_sends_exactly_one_fcm_and_no_in_app(
        self, mock_messaging: MagicMock,
    ) -> None:
        """Given a target with an FCM token, when send_swap_request_notification
        is called once, then exactly 1 FCM push is sent and no in-app doc is written
        (swap requests use the Firestore swapRequests stream, not in-app docs)."""
        svc, _ = _build_svc(tokens={_BOB_UID: _BOB_TOKEN})
        svc.write_in_app_notification = MagicMock()  # type: ignore[method-assign]

        svc.send_swap_request_notification(_FLAT_ID, _BOB_UID, "Alice", 2)

        assert mock_messaging.send.call_count == 1
        svc.write_in_app_notification.assert_not_called()

    def test_broadcast_in_app_writes_exactly_one_per_member(self) -> None:
        """Given 3 members, when write_in_app_notifications_to_all is called once,
        then exactly 3 in-app docs are written (one per member, no duplicates)."""
        members = [_make_person("p0"), _make_person("p1"), _make_person("p2")]
        svc, _ = _build_svc(all_members=members)
        svc._person_repo.get_all_members.return_value = members
        svc.write_in_app_notification = MagicMock()  # type: ignore[method-assign]

        svc.write_in_app_notifications_to_all(
            _FLAT_ID, "task_completed", "Done!", "Someone finished.",
        )

        assert svc.write_in_app_notification.call_count == 3
        written_uids = {c.args[1] for c in svc.write_in_app_notification.call_args_list}
        assert written_uids == {"p0", "p1", "p2"}
