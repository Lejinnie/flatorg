"""Cloud Functions triggers for task reminder notifications.

Cloud Scheduler calls these functions before each task's due_date_time:
  - send_day_before_reminder_http   — 1 day before
  - send_hours_before_reminder_http — reminder_hours_before_deadline hours before
"""

from __future__ import annotations

import logging
from typing import Any

from firebase_functions import https_fn
from google.cloud import firestore

from models.task import effective_assigned_to
from repository.flat_repository import FlatRepository
from repository.task_repository import TaskRepository
from services.notification_service import NotificationService

logger = logging.getLogger(__name__)


# ── Day-before reminder ───────────────────────────────────────────────────────


@https_fn.on_call()  # type: ignore[untyped-decorator, unused-ignore]
def send_day_before_reminder_callable(req: https_fn.CallableRequest[Any]) -> dict[str, Any]:
    """HTTP-callable: send the day-before reminder to a task's assignee."""
    data = req.data or {}
    flat_id: str = data.get("flatId", "")
    task_id: str = data.get("taskId", "")
    if not flat_id or not task_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="flatId and taskId are required",
        )
    _dispatch_day_before_reminder(flat_id, task_id)
    return {"success": True}


@https_fn.on_request()  # type: ignore[untyped-decorator, unused-ignore]
def send_day_before_reminder_http(req: Any) -> Any:
    """HTTP trigger for Cloud Scheduler. Expects JSON: {"flatId": ..., "taskId": ...}"""
    body = req.get_json(silent=True) or {}
    flat_id: str = body.get("flatId", "")
    task_id: str = body.get("taskId", "")
    if not flat_id or not task_id:
        return https_fn.Response({"error": "flatId and taskId are required"}, status=400, mimetype="application/json")  # type: ignore[attr-defined, unused-ignore]
    try:
        _dispatch_day_before_reminder(flat_id, task_id)
        return https_fn.Response({"success": True}, status=200, mimetype="application/json")  # type: ignore[attr-defined, unused-ignore]
    except Exception as exc:
        logger.error("send_day_before_reminder_http failed flat=%s task=%s error=%s", flat_id, task_id, exc)
        return https_fn.Response({"error": "Internal error"}, status=500, mimetype="application/json")  # type: ignore[attr-defined, unused-ignore]


# ── Hours-before reminder ─────────────────────────────────────────────────────


@https_fn.on_call()  # type: ignore[untyped-decorator, unused-ignore]
def send_hours_before_reminder_callable(req: https_fn.CallableRequest[Any]) -> dict[str, Any]:
    """HTTP-callable: send the X-hours-before reminder to a task's assignee."""
    data = req.data or {}
    flat_id: str = data.get("flatId", "")
    task_id: str = data.get("taskId", "")
    if not flat_id or not task_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="flatId and taskId are required",
        )
    _dispatch_hours_before_reminder(flat_id, task_id)
    return {"success": True}


@https_fn.on_request()  # type: ignore[untyped-decorator, unused-ignore]
def send_hours_before_reminder_http(req: Any) -> Any:
    """HTTP trigger for Cloud Scheduler. Expects JSON: {"flatId": ..., "taskId": ...}"""
    body = req.get_json(silent=True) or {}
    flat_id: str = body.get("flatId", "")
    task_id: str = body.get("taskId", "")
    if not flat_id or not task_id:
        return https_fn.Response({"error": "flatId and taskId are required"}, status=400, mimetype="application/json")  # type: ignore[attr-defined, unused-ignore]
    try:
        _dispatch_hours_before_reminder(flat_id, task_id)
        return https_fn.Response({"success": True}, status=200, mimetype="application/json")  # type: ignore[attr-defined, unused-ignore]
    except Exception as exc:
        logger.error("send_hours_before_reminder_http failed flat=%s task=%s error=%s", flat_id, task_id, exc)
        return https_fn.Response({"error": "Internal error"}, status=500, mimetype="application/json")  # type: ignore[attr-defined, unused-ignore]


# ── Helpers ───────────────────────────────────────────────────────────────────


def _dispatch_day_before_reminder(flat_id: str, task_id: str) -> None:
    db = firestore.Client()
    task = TaskRepository(db).get_task(flat_id, task_id)
    assignee_uid = effective_assigned_to(task)
    if not assignee_uid:
        return
    NotificationService(db).send_day_before_reminder(flat_id, assignee_uid, task.name)


def _dispatch_hours_before_reminder(flat_id: str, task_id: str) -> None:
    db = firestore.Client()
    task = TaskRepository(db).get_task(flat_id, task_id)
    flat = FlatRepository(db).get_flat(flat_id)
    assignee_uid = effective_assigned_to(task)
    if not assignee_uid:
        return
    NotificationService(db).send_hours_before_reminder(
        flat_id, assignee_uid, task.name, flat.reminder_hours_before_deadline
    )
