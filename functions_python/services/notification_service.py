"""Handles all outbound FCM push notifications and Firestore in-app notifications.

Android: native push via FCM.
iOS: native push via FCM routed through APNs (requires APNs key in Firebase).

Every notification type that targets a specific user also writes a Firestore
document under flats/{flatId}/members/{uid}/notifications/{notifId} so it
appears in the in-app notification panel on all platforms.  Broadcast
notifications (task_completed) write a document for every member.

Reminder and grace_period documents are cleaned up by week_reset_service after
the week reset runs.
"""

from __future__ import annotations

import logging

from firebase_admin import messaging
from google.cloud.firestore_v1 import SERVER_TIMESTAMP, Client

from constants.strings import (
    COLLECTION_FLATS,
    COLLECTION_MEMBERS,
    COLLECTION_NOTIFICATIONS,
    FIELD_NOTIF_BODY,
    FIELD_NOTIF_CREATED_AT,
    FIELD_NOTIF_TASK_ID,
    FIELD_NOTIF_TITLE,
    FIELD_NOTIF_TYPE,
    FIELD_PERSON_FCM_TOKEN,
    NOTIF_TYPE_GRACE_PERIOD,
    NOTIF_TYPE_REMINDER,
    NOTIF_TYPE_WEEK_RESET,
    NOTIFICATION_BODY_GRACE_PERIOD,
    NOTIFICATION_BODY_REMINDER_DAY_BEFORE,
    NOTIFICATION_BODY_REMINDER_HOURS_BEFORE,
    NOTIFICATION_BODY_SWAP_REQUEST,
    NOTIFICATION_BODY_TASK_COMPLETED,
    NOTIFICATION_BODY_WEEK_RESET,
    NOTIFICATION_TITLE_GRACE_PERIOD,
    NOTIFICATION_TITLE_REMINDER,
    NOTIFICATION_TITLE_SWAP_REQUEST,
    NOTIFICATION_TITLE_TASK_COMPLETED,
    NOTIFICATION_TITLE_WEEK_RESET,
)
from repository.person_repository import PersonRepository

logger = logging.getLogger(__name__)


class NotificationService:
    def __init__(self, db: Client) -> None:
        self._db = db
        self._person_repo = PersonRepository(db)

    # ── FCM token helpers ─────────────────────────────────────────────────────

    def _get_fcm_token(self, flat_id: str, uid: str) -> str | None:
        """Retrieve the FCM token for a member, or None if none registered."""
        doc = self._db.collection(COLLECTION_FLATS).document(flat_id).collection(COLLECTION_MEMBERS).document(uid).get()
        data = doc.to_dict() or {}
        return data.get(FIELD_PERSON_FCM_TOKEN) or None

    def _get_all_fcm_tokens(self, flat_id: str) -> list[str]:
        """Retrieve FCM tokens for all members that have one registered."""
        members = self._person_repo.get_all_members(flat_id)
        tokens: list[str] = []
        for member in members:
            token = self._get_fcm_token(flat_id, member.uid)
            if token:
                tokens.append(token)
        return tokens

    # ── In-app notification writers ───────────────────────────────────────────

    def write_in_app_notification(
        self,
        flat_id: str,
        uid: str,
        notif_type: str,
        title: str,
        body: str,
        task_id: str = "",
    ) -> None:
        """Write a single Firestore in-app notification document for [uid].

        Logs but does not raise on failure — in-app notification failure must
        not abort business logic.
        """
        try:
            (
                self._db.collection(COLLECTION_FLATS)
                .document(flat_id)
                .collection(COLLECTION_MEMBERS)
                .document(uid)
                .collection(COLLECTION_NOTIFICATIONS)
                .document()
                .set(
                    {
                        FIELD_NOTIF_TYPE: notif_type,
                        FIELD_NOTIF_TITLE: title,
                        FIELD_NOTIF_BODY: body,
                        FIELD_NOTIF_TASK_ID: task_id,
                        FIELD_NOTIF_CREATED_AT: SERVER_TIMESTAMP,
                    }
                )
            )
        except Exception as exc:
            logger.error(
                "write_in_app_notification failed flat=%s uid=%s type=%s error=%s",
                flat_id,
                uid,
                notif_type,
                exc,
            )

    def write_in_app_notifications_to_all(
        self,
        flat_id: str,
        notif_type: str,
        title: str,
        body: str,
        task_id: str = "",
    ) -> None:
        """Write an in-app notification document to every flat member."""
        members = self._person_repo.get_all_members(flat_id)
        for member in members:
            self.write_in_app_notification(flat_id, member.uid, notif_type, title, body, task_id)

    # ── Outbound notification methods ─────────────────────────────────────────

    def send_day_before_reminder(self, flat_id: str, assignee_uid: str, task_name: str, task_id: str = "") -> None:
        """Send a 24-hour reminder to the assignee via FCM and in-app notification."""
        body = NOTIFICATION_BODY_REMINDER_DAY_BEFORE.format(task_name=task_name)
        token = self._get_fcm_token(flat_id, assignee_uid)
        if token:
            self._send_to_token(token, NOTIFICATION_TITLE_REMINDER, body)
        self.write_in_app_notification(
            flat_id,
            assignee_uid,
            NOTIF_TYPE_REMINDER,
            NOTIFICATION_TITLE_REMINDER,
            body,
            task_id,
        )
        logger.info(
            "send_day_before_reminder sent flat=%s uid=%s task=%s",
            flat_id,
            assignee_uid,
            task_name,
        )

    def send_hours_before_reminder(
        self,
        flat_id: str,
        assignee_uid: str,
        task_name: str,
        hours_remaining: int,
        task_id: str = "",
    ) -> None:
        """Send an X-hours-before reminder to the assignee via FCM and in-app notification."""
        body = NOTIFICATION_BODY_REMINDER_HOURS_BEFORE.format(task_name=task_name, hours=hours_remaining)
        token = self._get_fcm_token(flat_id, assignee_uid)
        if token:
            self._send_to_token(token, NOTIFICATION_TITLE_REMINDER, body)
        self.write_in_app_notification(
            flat_id,
            assignee_uid,
            NOTIF_TYPE_REMINDER,
            NOTIFICATION_TITLE_REMINDER,
            body,
            task_id,
        )
        logger.info(
            "send_hours_before_reminder sent flat=%s uid=%s task=%s",
            flat_id,
            assignee_uid,
            task_name,
        )

    def send_task_completed_notification(self, flat_id: str, completed_by_name: str, task_name: str) -> None:
        """Notify all flat members via FCM that someone completed a task.

        In-app notifications are written separately by notify_task_completed_callable
        so that the callable can control the broadcast without duplicating member
        look-ups.
        """
        tokens = self._get_all_fcm_tokens(flat_id)
        if tokens:
            body = NOTIFICATION_BODY_TASK_COMPLETED.format(person_name=completed_by_name, task_name=task_name)
            self._send_to_multiple_tokens(tokens, NOTIFICATION_TITLE_TASK_COMPLETED, body)
        logger.info(
            "send_task_completed_notification sent flat=%s task=%s",
            flat_id,
            task_name,
        )

    def send_grace_period_notification(
        self,
        flat_id: str,
        assignee_uid: str,
        task_name: str,
        hours_until_reset: int,
        task_id: str = "",
    ) -> None:
        """Send FCM + write in-app notification when a task enters the grace period.

        The message tells the assignee their deadline has passed and how many
        hours remain until the week reset runs.
        """
        body = NOTIFICATION_BODY_GRACE_PERIOD.format(task_name=task_name, hours=hours_until_reset)
        token = self._get_fcm_token(flat_id, assignee_uid)
        if token:
            self._send_to_token(token, NOTIFICATION_TITLE_GRACE_PERIOD, body)
        self.write_in_app_notification(
            flat_id,
            assignee_uid,
            NOTIF_TYPE_GRACE_PERIOD,
            NOTIFICATION_TITLE_GRACE_PERIOD,
            body,
            task_id,
        )
        logger.info(
            "send_grace_period_notification sent flat=%s uid=%s task=%s hours=%d",
            flat_id,
            assignee_uid,
            task_name,
            hours_until_reset,
        )

    def send_week_reset_notification(self, flat_id: str, assignee_uid: str, task_name: str, task_id: str = "") -> None:
        """Send FCM push + in-app notification informing a person of their new weekly task."""
        body = NOTIFICATION_BODY_WEEK_RESET.format(task_name=task_name)
        token = self._get_fcm_token(flat_id, assignee_uid)
        if token:
            self._send_to_token(token, NOTIFICATION_TITLE_WEEK_RESET, body)
        self.write_in_app_notification(
            flat_id,
            assignee_uid,
            NOTIF_TYPE_WEEK_RESET,
            NOTIFICATION_TITLE_WEEK_RESET,
            body,
            task_id,
        )
        logger.info(
            "send_week_reset_notification sent flat=%s uid=%s task=%s",
            flat_id,
            assignee_uid,
            task_name,
        )

    def send_swap_request_notification(
        self,
        flat_id: str,
        target_uid: str,
        requester_name: str,
        tokens_remaining: int,
    ) -> None:
        """Send a swap request FCM push to the target person.

        iOS also receives the push via APNs (FCM routes automatically).
        The request additionally appears via the swapRequests Firestore stream
        in the in-app notification panel — no separate in-app document is needed.
        """
        token = self._get_fcm_token(flat_id, target_uid)
        if not token:
            return
        body = NOTIFICATION_BODY_SWAP_REQUEST.format(requester_name=requester_name, tokens=tokens_remaining)
        self._send_to_token(token, NOTIFICATION_TITLE_SWAP_REQUEST, body)
        logger.info(
            "send_swap_request_notification sent flat=%s uid=%s",
            flat_id,
            target_uid,
        )

    # ── Low-level FCM send helpers ────────────────────────────────────────────

    def _send_to_token(self, token: str, title: str, body: str) -> None:
        """Send a notification to a single FCM token.

        Logs but does not raise on failure — notification failure must not abort
        business logic.
        """
        try:
            messaging.send(
                messaging.Message(
                    token=token,
                    notification=messaging.Notification(title=title, body=body),
                )
            )
        except Exception as exc:
            logger.error("FCM send failed token_prefix=%s error=%s", token[:10], exc)

    def _send_to_multiple_tokens(self, tokens: list[str], title: str, body: str) -> None:
        """Send a notification to multiple FCM tokens using multicast."""
        if not tokens:
            return
        try:
            messaging.send_each_for_multicast(
                messaging.MulticastMessage(
                    tokens=tokens,
                    notification=messaging.Notification(title=title, body=body),
                )
            )
        except Exception as exc:
            logger.error("FCM multicast failed error=%s", exc)
