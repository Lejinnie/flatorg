"""Handles all outbound FCM push notifications.

Android: native push via FCM.
iOS: notifications appear only in the in-app panel (no APNs key required).
"""

from __future__ import annotations

import logging

from firebase_admin import messaging
from google.cloud.firestore_v1 import Client

from constants.strings import (
    COLLECTION_FLATS,
    COLLECTION_MEMBERS,
    FIELD_PERSON_FCM_TOKEN,
    NOTIFICATION_BODY_REMINDER_DAY_BEFORE,
    NOTIFICATION_BODY_REMINDER_HOURS_BEFORE,
    NOTIFICATION_BODY_SWAP_REQUEST,
    NOTIFICATION_BODY_TASK_COMPLETED,
    NOTIFICATION_TITLE_REMINDER,
    NOTIFICATION_TITLE_SWAP_REQUEST,
    NOTIFICATION_TITLE_TASK_COMPLETED,
)
from repository.person_repository import PersonRepository

logger = logging.getLogger(__name__)


class NotificationService:
    def __init__(self, db: Client) -> None:
        self._db = db
        self._person_repo = PersonRepository(db)

    def _get_fcm_token(self, flat_id: str, uid: str) -> str | None:
        """Retrieve the FCM token for a member, or None if none registered."""
        doc = (
            self._db.collection(COLLECTION_FLATS)
            .document(flat_id)
            .collection(COLLECTION_MEMBERS)
            .document(uid)
            .get()
        )
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

    def send_day_before_reminder(
        self, flat_id: str, assignee_uid: str, task_name: str
    ) -> None:
        """Send a reminder to the assignee 1 day before their task deadline."""
        token = self._get_fcm_token(flat_id, assignee_uid)
        if not token:
            return
        body = NOTIFICATION_BODY_REMINDER_DAY_BEFORE.format(task_name=task_name)
        self._send_to_token(token, NOTIFICATION_TITLE_REMINDER, body)
        logger.info("send_day_before_reminder sent flat=%s uid=%s task=%s", flat_id, assignee_uid, task_name)

    def send_hours_before_reminder(
        self, flat_id: str, assignee_uid: str, task_name: str, hours_remaining: int
    ) -> None:
        """Send a reminder to the assignee X hours before their task deadline."""
        token = self._get_fcm_token(flat_id, assignee_uid)
        if not token:
            return
        body = NOTIFICATION_BODY_REMINDER_HOURS_BEFORE.format(
            task_name=task_name, hours=hours_remaining
        )
        self._send_to_token(token, NOTIFICATION_TITLE_REMINDER, body)
        logger.info("send_hours_before_reminder sent flat=%s uid=%s task=%s", flat_id, assignee_uid, task_name)

    def send_task_completed_notification(
        self, flat_id: str, completed_by_name: str, task_name: str
    ) -> None:
        """Notify all flat members that someone completed a task."""
        tokens = self._get_all_fcm_tokens(flat_id)
        if not tokens:
            return
        body = NOTIFICATION_BODY_TASK_COMPLETED.format(
            person_name=completed_by_name, task_name=task_name
        )
        self._send_to_multiple_tokens(tokens, NOTIFICATION_TITLE_TASK_COMPLETED, body)
        logger.info("send_task_completed_notification sent flat=%s task=%s", flat_id, task_name)

    def send_swap_request_notification(
        self,
        flat_id: str,
        target_uid: str,
        requester_name: str,
        tokens_remaining: int,
    ) -> None:
        """Send a swap request notification to the target person."""
        token = self._get_fcm_token(flat_id, target_uid)
        if not token:
            return
        body = NOTIFICATION_BODY_SWAP_REQUEST.format(
            requester_name=requester_name, tokens=tokens_remaining
        )
        self._send_to_token(token, NOTIFICATION_TITLE_SWAP_REQUEST, body)
        logger.info("send_swap_request_notification sent flat=%s uid=%s", flat_id, target_uid)

    def _send_to_token(self, token: str, title: str, body: str) -> None:
        """Send a notification to a single FCM token.

        Logs but does not raise on failure — notification failure must not abort business logic.
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
