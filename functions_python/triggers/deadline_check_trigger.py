"""Scheduled trigger that drives the automatic task lifecycle transitions.

Runs every 5 minutes and, for each flat, evaluates whether any of the
following actions are due:

  1. Send the 24-hour-before reminder to the assigned person.
  2. Send the X-hours-before reminder (admin-configurable per flat).
  3. Transition pending tasks to not_done once their deadline passes.
  4. Run week_reset() once the grace period after the last deadline elapses.

All timing logic lives in deadline_check_service.compute_deadline_actions(),
which is a pure function with no Firestore dependency — see that module for
the detailed spec and edge-case handling.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from typing import Any
from zoneinfo import ZoneInfo

from firebase_functions import https_fn, scheduler_fn
from google.cloud import firestore

from constants.strings import (
    COLLECTION_FLATS,
    FIELD_TASK_DAY_BEFORE_REMINDER_SENT,
    FIELD_TASK_HOURS_BEFORE_REMINDER_SENT,
    LOG_DEADLINE_CHECK,
    LOG_GRACE_PERIOD_AUTO,
    LOG_REMINDER_DAY_BEFORE_SENT,
    LOG_REMINDER_HOURS_BEFORE_SENT,
    LOG_WEEK_RESET_AUTO,
)
from models.task import effective_assigned_to
from repository.flat_repository import FlatRepository
from repository.task_repository import TaskRepository
from services.deadline_check_service import compute_deadline_actions
from services.notification_service import NotificationService
from services.week_reset_service import WeekResetService

logger = logging.getLogger(__name__)


@scheduler_fn.on_schedule(  # type: ignore[untyped-decorator, unused-ignore]
    schedule="every 5 minutes",
    timezone=ZoneInfo("Europe/Zurich"),
)
def check_deadlines_scheduled(_event: scheduler_fn.ScheduledEvent) -> None:
    """Evaluate task deadlines across all flats every 5 minutes."""
    now = datetime.now(UTC)
    db = firestore.Client()
    _run_for_all_flats(now, db)


@https_fn.on_request()  # type: ignore[untyped-decorator, unused-ignore]
def check_deadlines_http(req: Any) -> Any:
    """HTTP trigger for manual testing. Expects optional JSON: {"flatId": "<id>"}"""
    body = req.get_json(silent=True) or {}
    flat_id_filter: str = body.get("flatId", "")
    try:
        now = datetime.now(UTC)
        db = firestore.Client()
        if flat_id_filter:
            _run_for_flat(flat_id_filter, now, db)
        else:
            _run_for_all_flats(now, db)
        return https_fn.Response({"success": True}, status=200, mimetype="application/json")  # type: ignore[attr-defined, unused-ignore]
    except Exception as exc:
        logger.error("check_deadlines_http failed error=%s", exc)
        return https_fn.Response({"error": "Internal error"}, status=500, mimetype="application/json")  # type: ignore[attr-defined, unused-ignore]


# ── Orchestration helpers ─────────────────────────────────────────────────────


def _run_for_all_flats(now: datetime, db: Any) -> None:
    for flat_doc in db.collection(COLLECTION_FLATS).stream():
        try:
            _run_for_flat(flat_doc.id, now, db)
        except Exception:
            logger.exception("deadline check failed for flat=%s", flat_doc.id)


def _run_for_flat(flat_id: str, now: datetime, db: Any) -> None:
    flat_repo = FlatRepository(db)
    task_repo = TaskRepository(db)

    flat = flat_repo.get_flat(flat_id)
    tasks = task_repo.get_all_tasks(flat_id)

    logger.info("%s %s tasks=%d", LOG_DEADLINE_CHECK, flat_id, len(tasks))

    actions = compute_deadline_actions(tasks, flat, now)

    notification_svc = NotificationService(db)

    for task in actions.tasks_needing_day_before_reminder:
        assignee_uid = effective_assigned_to(task)
        if assignee_uid:
            # send_day_before_reminder writes both FCM (Android) and in-app doc (iOS).
            notification_svc.send_day_before_reminder(flat_id, assignee_uid, task.name, task_id=task.id)
        task_repo.update_task(flat_id, task.id, {FIELD_TASK_DAY_BEFORE_REMINDER_SENT: True})
        logger.info("%s flat=%s task=%s", LOG_REMINDER_DAY_BEFORE_SENT, flat_id, task.id)

    for task in actions.tasks_needing_hours_before_reminder:
        assignee_uid = effective_assigned_to(task)
        if assignee_uid:
            # send_hours_before_reminder writes both FCM (Android) and in-app doc (iOS).
            notification_svc.send_hours_before_reminder(
                flat_id,
                assignee_uid,
                task.name,
                flat.reminder_hours_before_deadline,
                task_id=task.id,
            )
        task_repo.update_task(flat_id, task.id, {FIELD_TASK_HOURS_BEFORE_REMINDER_SENT: True})
        logger.info("%s flat=%s task=%s", LOG_REMINDER_HOURS_BEFORE_SENT, flat_id, task.id)

    for task in actions.tasks_needing_grace_period:
        task_repo.enter_grace_period(flat_id, task.id)
        # Notify the assignee that their deadline passed and how long until reset.
        assignee_uid = effective_assigned_to(task)
        if assignee_uid:
            notification_svc.send_grace_period_notification(
                flat_id,
                assignee_uid,
                task.name,
                flat.grace_period_hours,
                task_id=task.id,
            )
        logger.info("%s flat=%s task=%s", LOG_GRACE_PERIOD_AUTO, flat_id, task.id)

    if actions.should_run_week_reset:
        logger.info("%s %s", LOG_WEEK_RESET_AUTO, flat_id)
        WeekResetService(db).week_reset(flat_id)
