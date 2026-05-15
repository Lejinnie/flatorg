"""Cloud Function callable for server-side swap acceptance.

The Flutter client calls this after the target person taps Accept.
Running the swap in a Firestore transaction server-side ensures the token
deduction and task re-assignment are atomic and cannot be bypassed by a
malicious or buggy client.

Payload:
  flatId          — the flat document ID
  swapRequestId   — the swap request document ID to accept
"""

from __future__ import annotations

import logging
from typing import Any

from firebase_functions import https_fn
from google.cloud import firestore

from services.week_reset_service import WeekResetService

logger = logging.getLogger(__name__)


@https_fn.on_call()  # type: ignore[untyped-decorator, unused-ignore]
def accept_swap_callable(req: https_fn.CallableRequest[Any]) -> dict[str, Any]:
    """Accept a pending swap request atomically in a Firestore transaction.

    Swaps assigned_to on both tasks and deducts 1 token from the requester
    only when is_vacation_swap is True.  Free for mutual non-vacation swaps.

    Raises INVALID_ARGUMENT when required fields are missing.
    Raises FAILED_PRECONDITION when the request is not pending or the
    requester has insufficient tokens.
    """
    data = req.data or {}
    flat_id: str = data.get("flatId", "")
    swap_request_id: str = data.get("swapRequestId", "")

    if not flat_id or not swap_request_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="flatId and swapRequestId are required",
        )

    try:
        db = firestore.Client()
        WeekResetService(db).accept_swap(flat_id, swap_request_id)
    except ValueError as exc:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            message=str(exc),
        ) from exc

    logger.info(
        "accept_swap_callable completed flat=%s swap=%s",
        flat_id,
        swap_request_id,
    )
    return {"success": True}
