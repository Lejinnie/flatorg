"""Cloud Functions triggers for automatic deletion of bought shopping items.

Runs every hour and deletes items where is_bought=True and bought_at is older
than the flat's shopping_cleanup_hours setting.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime, timedelta
from typing import Any
from zoneinfo import ZoneInfo

from firebase_functions import https_fn, scheduler_fn
from google.cloud import firestore
from google.cloud.firestore_v1 import Client

from constants.strings import (
    COLLECTION_FLATS,
    COLLECTION_SHOPPING_ITEMS,
    LOG_SHOPPING_CLEANUP,
)
from repository.flat_repository import FlatRepository

logger = logging.getLogger(__name__)


@scheduler_fn.on_schedule(schedule="every 1 hours", timezone=ZoneInfo("Europe/Zurich"))  # type: ignore[untyped-decorator, unused-ignore]
def shopping_cleanup_scheduled(_event: scheduler_fn.ScheduledEvent) -> None:
    """Periodically delete bought shopping items older than the flat's threshold."""
    db = firestore.Client()
    flat_repo = FlatRepository(db)
    for flat_doc in db.collection(COLLECTION_FLATS).stream():
        flat = flat_repo.get_flat(flat_doc.id)
        _delete_expired_shopping_items(flat_doc.id, flat.shopping_cleanup_hours, db)


@https_fn.on_request()  # type: ignore[untyped-decorator, unused-ignore]
def shopping_cleanup_http(req: Any) -> Any:
    """HTTP trigger for manual testing. Expects JSON: {"flatId": "<id>"}"""
    body = req.get_json(silent=True) or {}
    flat_id: str = body.get("flatId", "")
    if not flat_id:
        return https_fn.Response({"error": "flatId is required"}, status=400, mimetype="application/json")  # type: ignore[attr-defined, unused-ignore]
    try:
        db = firestore.Client()
        flat = FlatRepository(db).get_flat(flat_id)
        deleted = _delete_expired_shopping_items(flat_id, flat.shopping_cleanup_hours, db)
        return https_fn.Response({"success": True, "deleted": deleted}, status=200, mimetype="application/json")  # type: ignore[attr-defined, unused-ignore]
    except Exception as exc:
        logger.error("shopping_cleanup_http failed flat=%s error=%s", flat_id, exc)
        return https_fn.Response({"error": "Internal error"}, status=500, mimetype="application/json")  # type: ignore[attr-defined, unused-ignore]


def _delete_expired_shopping_items(flat_id: str, cleanup_hours: int, db: Client) -> int:
    """Delete all bought shopping items in a flat older than cleanup_hours.

    Returns the number of items deleted.
    """
    cutoff = datetime.now(tz=UTC) - timedelta(hours=cleanup_hours)

    snapshot = list(
        db.collection(COLLECTION_FLATS)
        .document(flat_id)
        .collection(COLLECTION_SHOPPING_ITEMS)
        .where("is_bought", "==", True)
        .where("bought_at", "<=", cutoff)
        .stream()
    )

    if not snapshot:
        return 0

    batch = db.batch()
    for doc in snapshot:
        batch.delete(doc.reference)
    batch.commit()

    logger.info("%s flat=%s deleted=%d", LOG_SHOPPING_CLEANUP, flat_id, len(snapshot))
    return len(snapshot)
