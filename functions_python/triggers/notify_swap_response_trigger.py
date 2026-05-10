"""Cloud Function callables for swap-outcome FCM pushes.

The Flutter client writes the in-app notification document directly (it has
Firestore access).  These callables exist solely to deliver the matching
system-tray push via Firebase Cloud Messaging — Flutter cannot send FCM pushes
on its own because doing so requires the Admin SDK.

Two callables are exposed:

  notify_swap_withdrawn_callable
    payload: {flatId, targetUid, requesterName}
    fired by the requester after they delete their pending swap request.

  notify_swap_response_callable
    payload: {flatId, requesterUid, responderName, accepted: bool}
    fired by the target after Accept / Reject and once per auto-rejected
    competing request when a swap is accepted.

Both are fire-and-forget on the client — failure must not block the swap-flow
UX.  They return ``{success: True}`` even when the FCM token is missing because
"no token" is not an error from the caller's perspective.
"""

from __future__ import annotations

import logging
from typing import Any

from firebase_functions import https_fn
from google.cloud import firestore

from services.notification_service import NotificationService

logger = logging.getLogger(__name__)


# ── Withdraw ─────────────────────────────────────────────────────────────────


@https_fn.on_call()  # type: ignore[untyped-decorator, unused-ignore]
def notify_swap_withdrawn_callable(
    req: https_fn.CallableRequest[Any],
) -> dict[str, Any]:
    """Send an FCM push to the swap target informing them the request was withdrawn.

    Expected payload:
      flatId        — the flat document ID
      targetUid     — UID of the original target (B)
      requesterName — display name of the person who withdrew (A)
    """
    data = req.data or {}
    flat_id: str        = data.get("flatId", "")
    target_uid: str     = data.get("targetUid", "")
    requester_name: str = data.get("requesterName", "")

    if not flat_id or not target_uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="flatId and targetUid are required",
        )

    db = firestore.Client()
    NotificationService(db).send_swap_withdrawn_notification(
        flat_id, target_uid, requester_name
    )
    logger.info(
        "notify_swap_withdrawn_callable completed flat=%s target=%s",
        flat_id,
        target_uid,
    )
    return {"success": True}


# ── Accept / Reject ──────────────────────────────────────────────────────────


@https_fn.on_call()  # type: ignore[untyped-decorator, unused-ignore]
def notify_swap_response_callable(
    req: https_fn.CallableRequest[Any],
) -> dict[str, Any]:
    """Send an FCM push to the swap requester informing them of the outcome.

    Used for both manual responses (Accept/Reject by the target) and the
    auto-rejection of competing requests when the target accepts a different
    one.  The caller passes ``accepted=False`` for both manual rejections
    and auto-rejections.

    Expected payload:
      flatId        — the flat document ID
      requesterUid  — UID of the requester (A)
      responderName — display name of the responder (B)
      accepted      — bool, true → accepted, false → rejected
    """
    data = req.data or {}
    flat_id: str        = data.get("flatId", "")
    requester_uid: str  = data.get("requesterUid", "")
    responder_name: str = data.get("responderName", "")
    accepted: bool      = bool(data.get("accepted", False))

    if not flat_id or not requester_uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="flatId and requesterUid are required",
        )

    db  = firestore.Client()
    svc = NotificationService(db)
    if accepted:
        svc.send_swap_accepted_notification(flat_id, requester_uid, responder_name)
    else:
        svc.send_swap_rejected_notification(flat_id, requester_uid, responder_name)
    logger.info(
        "notify_swap_response_callable completed flat=%s requester=%s accepted=%s",
        flat_id,
        requester_uid,
        accepted,
    )
    return {"success": True}
