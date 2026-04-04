"""Cloud Functions triggers for the grace period (Pending → NotDone) transition.

Each task has its own due_date_time. When that timestamp passes, Cloud Scheduler
calls enter_grace_period_http with {"flatId": "<id>", "taskId": "<id>"}.
The transition is idempotent — calling again when the task is already NotDone or
Completed is a no-op.

After transitioning, sends a grace-period notification to the assignee via FCM
(Android) and writes an in-app notification document (iOS).
"""

from __future__ import annotations

import logging
from typing import Any

from firebase_functions import https_fn
from google.cloud import firestore

from constants.strings import LOG_GRACE_PERIOD_TRANSITION
from models.task import TaskState, effective_assigned_to
from repository.flat_repository import FlatRepository
from repository.task_repository import TaskRepository
from services.notification_service import NotificationService

logger = logging.getLogger(__name__)


def _notify_grace_period(db: Any, flat_id: str, task_id: str) -> None:
    """Send a grace-period notification to the task assignee.

    Looks up the task and flat to build the notification body.  Skips silently
    if the task has no assignee (vacant slot).
    """
    task = TaskRepository(db).get_task(flat_id, task_id)
    assignee_uid = effective_assigned_to(task)
    if not assignee_uid:
        return
    flat = FlatRepository(db).get_flat(flat_id)
    NotificationService(db).send_grace_period_notification(
        flat_id,
        assignee_uid,
        task.name,
        flat.grace_period_hours,
        task_id=task_id,
    )


@https_fn.on_call()
def enter_grace_period_callable(req: https_fn.CallableRequest[Any]) -> dict[str, Any]:
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
    task_repo = TaskRepository(db)
    task = task_repo.get_task(flat_id, task_id)
    # Only transition and notify if still pending — idempotent guard.
    if task.state == TaskState.Pending:
        task_repo.enter_grace_period(flat_id, task_id)
        _notify_grace_period(db, flat_id, task_id)
    logger.info("%s flat=%s task=%s", LOG_GRACE_PERIOD_TRANSITION, flat_id, task_id)
    return {"success": True}


@https_fn.on_call()
def enter_grace_period_all_callable(req: https_fn.CallableRequest[Any]) -> dict[str, Any]:
    """HTTP-callable Cloud Function that transitions every pending task in a flat to NotDone.

    Avoids N client round-trips compared to calling enter_grace_period_callable
    once per task from the Flutter side, and prevents partial-state if the
    caller loses connectivity mid-loop.
    """
    data = req.data or {}
    flat_id: str = data.get("flatId", "")
    if not flat_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="flatId is required",
        )
    db = firestore.Client()
    repo = TaskRepository(db)
    tasks = repo.get_all_tasks(flat_id)
    pending = [t for t in tasks if t.state == TaskState.Pending]
    for task in pending:
        repo.enter_grace_period(flat_id, task.id)
        _notify_grace_period(db, flat_id, task.id)
    logger.info("%s flat=%s count=%d", LOG_GRACE_PERIOD_TRANSITION, flat_id, len(pending))
    return {"success": True, "count": len(pending)}


@https_fn.on_request()
def enter_grace_period_http(req: Any) -> Any:
    """HTTP trigger variant for Cloud Scheduler.

    Expects JSON body: {"flatId": "<id>", "taskId": "<id>"}
    """
    body = req.get_json(silent=True) or {}
    flat_id: str = body.get("flatId", "")
    task_id: str = body.get("taskId", "")
    if not flat_id or not task_id:
        return https_fn.Response(  # type: ignore[attr-defined]
            {"error": "flatId and taskId are required"}, status=400, mimetype="application/json"
        )
    try:
        db = firestore.Client()
        task_repo = TaskRepository(db)
        task = task_repo.get_task(flat_id, task_id)
        if task.state == TaskState.Pending:
            task_repo.enter_grace_period(flat_id, task_id)
            _notify_grace_period(db, flat_id, task_id)
        logger.info("%s flat=%s task=%s", LOG_GRACE_PERIOD_TRANSITION, flat_id, task_id)
        return https_fn.Response({"success": True}, status=200, mimetype="application/json")  # type: ignore[attr-defined]
    except Exception as exc:
        logger.error("enter_grace_period_http failed flat=%s task=%s error=%s", flat_id, task_id, exc)
        return https_fn.Response({"error": "Internal error"}, status=500, mimetype="application/json")  # type: ignore[attr-defined]
