"""Cloud Function callable triggered by the Flutter client after a task is marked done.

Sends an FCM push notification to all flat members (Android) and writes an
in-app notification document to each member's notifications subcollection (iOS).

The Flutter client calls this as a fire-and-forget after updating the task
state in Firestore, so a failure here never blocks the task-completion UX.
"""

from __future__ import annotations

import logging
from typing import Any

from firebase_functions import https_fn
from google.cloud import firestore

from constants.strings import (
    NOTIF_TYPE_TASK_COMPLETED,
    NOTIFICATION_BODY_TASK_COMPLETED,
    NOTIFICATION_TITLE_TASK_COMPLETED,
)
from repository.person_repository import PersonRepository
from repository.task_repository import TaskRepository
from services.notification_service import NotificationService

logger = logging.getLogger(__name__)


@https_fn.on_call()  # type: ignore[untyped-decorator, unused-ignore]
def notify_task_completed_callable(
    req: https_fn.CallableRequest[Any],
) -> dict[str, Any]:
    """Notify all flat members that a task was completed.

    Expected payload:
      flatId         — the flat document ID
      taskId         — the completed task's document ID
      completedByUid — Firebase Auth UID of the person who completed the task
    """
    data = req.data or {}
    flat_id: str = data.get("flatId", "")
    task_id: str = data.get("taskId", "")
    completed_by_uid: str = data.get("completedByUid", "")

    if not flat_id or not task_id or not completed_by_uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="flatId, taskId, and completedByUid are required",
        )

    db = firestore.Client()
    task = TaskRepository(db).get_task(flat_id, task_id)
    person = PersonRepository(db).get_member(flat_id, completed_by_uid)
    svc = NotificationService(db)

    body = NOTIFICATION_BODY_TASK_COMPLETED.format(person_name=person.name, task_name=task.name)

    # Android: FCM multicast to all members with a registered token.
    svc.send_task_completed_notification(flat_id, person.name, task.name)

    # iOS: in-app notification doc written to every member's subcollection.
    svc.write_in_app_notifications_to_all(
        flat_id,
        NOTIF_TYPE_TASK_COMPLETED,
        NOTIFICATION_TITLE_TASK_COMPLETED,
        body,
        task_id=task_id,
    )

    logger.info(
        "notify_task_completed_callable completed flat=%s task=%s uid=%s",
        flat_id,
        task_id,
        completed_by_uid,
    )
    return {"success": True}
