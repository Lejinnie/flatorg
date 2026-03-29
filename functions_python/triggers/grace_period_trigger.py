"""Cloud Functions triggers for the grace period (Pending → NotDone) transition.

Each task has its own due_date_time. When that timestamp passes, Cloud Scheduler
calls enter_grace_period_http with {"flatId": "<id>", "taskId": "<id>"}.
The transition is idempotent — calling again when the task is already NotDone or
Completed is a no-op.
"""

from __future__ import annotations

import logging
from typing import Any

from firebase_functions import https_fn
from google.cloud import firestore

from constants.strings import LOG_GRACE_PERIOD_TRANSITION
from repository.task_repository import TaskRepository

logger = logging.getLogger(__name__)


@https_fn.on_call()  # type: ignore[untyped-decorator]
def enter_grace_period_callable(req: https_fn.CallableRequest) -> dict[str, Any]:
    """HTTP-callable Cloud Function that transitions a task from Pending → NotDone."""
    data = req.data or {}
    flat_id: str = data.get("flatId", "")
    task_id: str = data.get("taskId", "")
    if not flat_id or not task_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="flatId and taskId are required",
        )
    db = firestore.Client()
    TaskRepository(db).enter_grace_period(flat_id, task_id)
    logger.info("%s flat=%s task=%s", LOG_GRACE_PERIOD_TRANSITION, flat_id, task_id)
    return {"success": True}


@https_fn.on_request()  # type: ignore[untyped-decorator]
def enter_grace_period_http(req: https_fn.Request) -> https_fn.Response:
    """HTTP trigger variant for Cloud Scheduler.

    Expects JSON body: {"flatId": "<id>", "taskId": "<id>"}
    """
    body = req.get_json(silent=True) or {}
    flat_id: str = body.get("flatId", "")
    task_id: str = body.get("taskId", "")
    if not flat_id or not task_id:
        return https_fn.Response(
            {"error": "flatId and taskId are required"}, status=400, mimetype="application/json"
        )
    try:
        db = firestore.Client()
        TaskRepository(db).enter_grace_period(flat_id, task_id)
        logger.info("%s flat=%s task=%s", LOG_GRACE_PERIOD_TRANSITION, flat_id, task_id)
        return https_fn.Response({"success": True}, status=200, mimetype="application/json")
    except Exception as exc:
        logger.error("enter_grace_period_http failed flat=%s task=%s error=%s", flat_id, task_id, exc)
        return https_fn.Response({"error": "Internal error"}, status=500, mimetype="application/json")
