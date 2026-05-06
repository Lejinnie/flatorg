"""Cloud Functions triggers for weekly task rotation reset.

Triggered by Cloud Scheduler after the grace period expires.
Expects JSON body / callable data: {"flatId": "<id>"}
"""

from __future__ import annotations

import logging
from typing import Any

from firebase_functions import https_fn
from flask import Request, Response
from google.cloud import firestore

from services.week_reset_service import WeekResetService

logger = logging.getLogger(__name__)


@https_fn.on_call()  # type: ignore[untyped-decorator]
def week_reset_callable(req: https_fn.CallableRequest[Any]) -> dict[str, Any]:
    """HTTP-callable Cloud Function that executes week_reset() for a given flat."""
    flat_id: str = (req.data or {}).get("flatId", "")
    if not flat_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="flatId is required",
        )
    db = firestore.Client()
    WeekResetService(db).week_reset(flat_id)
    return {"success": True}


@https_fn.on_request()  # type: ignore[untyped-decorator]
def week_reset_http(req: Request) -> Response:
    """HTTP trigger variant used by Cloud Scheduler.

    Expects JSON body: {"flatId": "<id>"}
    """
    body = req.get_json(silent=True) or {}
    flat_id: str = body.get("flatId", "")
    if not flat_id:
        return Response({"error": "flatId is required"}, status=400, mimetype="application/json")

    try:
        db = firestore.Client()
        WeekResetService(db).week_reset(flat_id)
        return Response({"success": True}, status=200, mimetype="application/json")
    except Exception as exc:
        logger.error("week_reset_http failed flat_id=%s error=%s", flat_id, exc)
        return Response({"error": "Internal error"}, status=500, mimetype="application/json")
