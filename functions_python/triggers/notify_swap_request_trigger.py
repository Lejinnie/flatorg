"""Cloud Function callable triggered by the Flutter client after a swap request is created.

Sends an FCM push notification to the target person (Android only).  iOS users
already see the swap request in the notification panel via the swapRequests
Firestore stream, so no separate in-app document is written.

The Flutter client calls this as a fire-and-forget after createSwapRequest()
succeeds, so a failure here never blocks the swap-request UX.
"""

from __future__ import annotations

import logging
from typing import Any

from firebase_functions import https_fn
from google.cloud import firestore

from constants.strings import (
    COLLECTION_FLATS,
    COLLECTION_SWAP_REQUESTS,
)
from models.task import effective_assigned_to
from repository.person_repository import PersonRepository
from repository.task_repository import TaskRepository
from services.notification_service import NotificationService

logger = logging.getLogger(__name__)


@https_fn.on_call()  # type: ignore[untyped-decorator, unused-ignore]
def notify_swap_request_callable(
    req: https_fn.CallableRequest[Any],
) -> dict[str, Any]:
    """Send an FCM push to the person targeted by a swap request.

    Expected payload:
      flatId        — the flat document ID
      swapRequestId — the swap request document ID
    """
    data = req.data or {}
    flat_id: str = data.get("flatId", "")
    swap_request_id: str = data.get("swapRequestId", "")

    if not flat_id or not swap_request_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="flatId and swapRequestId are required",
        )

    db = firestore.Client()

    swap_doc = (
        db.collection(COLLECTION_FLATS)
        .document(flat_id)
        .collection(COLLECTION_SWAP_REQUESTS)
        .document(swap_request_id)
        .get()
    )
    if not swap_doc.exists:
        # Request may have been immediately auto-accepted — nothing to notify.
        return {"success": True, "skipped": "swap request not found"}

    swap_data = swap_doc.to_dict() or {}
    requester_uid = swap_data.get("requester_uid", "")
    target_task_id = swap_data.get("target_task_id", "")

    if not requester_uid or not target_task_id:
        logger.warning(
            "notify_swap_request_callable: missing fields flat=%s swap=%s",
            flat_id,
            swap_request_id,
        )
        return {"success": True, "skipped": "missing swap request fields"}

    target_task = TaskRepository(db).get_task(flat_id, target_task_id)
    target_uid = effective_assigned_to(target_task)

    if not target_uid:
        # Target task is vacant — no one to notify.
        return {"success": True, "skipped": "no assignee on target task"}

    requester = PersonRepository(db).get_member(flat_id, requester_uid)
    tokens_remaining = requester.swap_tokens_remaining

    # FCM only — iOS already shows the request in the panel via the
    # swapRequests Firestore stream.
    NotificationService(db).send_swap_request_notification(flat_id, target_uid, requester.name, tokens_remaining)

    logger.info(
        "notify_swap_request_callable completed flat=%s swap=%s target=%s",
        flat_id,
        swap_request_id,
        target_uid,
    )
    return {"success": True}
