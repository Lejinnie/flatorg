"""Cloud Functions triggers for semester token reset.

Resets swap_tokens_remaining to SWAP_TOKENS_PER_SEMESTER for every member
across all flats at the start of each ETH semester.

Schedule: "every monday 09:00" (Zurich time) — runs once per week.
The handler only performs the reset on the exact ISO week that opens each
semester (week 8 for FS, week 38 for HS), so the reset fires precisely on
the first day of term rather than arbitrarily early.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from zoneinfo import ZoneInfo

from firebase_functions import https_fn, scheduler_fn
from flask import Request, Response
from google.cloud import firestore

from constants.strings import COLLECTION_FLATS, LOG_TOKEN_RESET
from repository.person_repository import PersonRepository
from services.eth_semester_calendar import EthSemesterCalendar

logger = logging.getLogger(__name__)

_SEMESTER_START_WEEKS = frozenset(
    {EthSemesterCalendar.FS_START_WEEK, EthSemesterCalendar.HS_START_WEEK}
)


@scheduler_fn.on_schedule(  # type: ignore[untyped-decorator]
    schedule="every monday 09:00",
    timezone=ZoneInfo("Europe/Zurich"),
)
def token_reset_scheduled(_event: scheduler_fn.ScheduledEvent) -> None:
    """Reset swap tokens on the Monday that opens each ETH semester.

    Runs every Monday but only acts when the ISO week number matches the
    first week of FS (week 8) or HS (week 38).  All other Mondays are
    no-ops, so the reset fires exactly once per semester start.
    """
    now = datetime.now(tz=UTC)
    week = EthSemesterCalendar.iso_week_number(now)
    if week not in _SEMESTER_START_WEEKS:
        logger.info("token_reset_scheduled: not semester start week=%d, skipping", week)
        return

    db = firestore.Client()
    person_repo = PersonRepository(db)

    for flat_doc in db.collection(COLLECTION_FLATS).stream():
        logger.info("%s flat=%s", LOG_TOKEN_RESET, flat_doc.id)
        person_repo.reset_all_swap_tokens(flat_doc.id)


@https_fn.on_request()  # type: ignore[untyped-decorator]
def token_reset_http(req: Request) -> Response:
    """HTTP trigger for manual testing / admin use.

    Expects optional JSON body: {"flatId": "<id>"} to reset a single flat,
    or empty body to reset all flats.
    """
    body = req.get_json(silent=True) or {}
    flat_id: str = body.get("flatId", "")

    try:
        db = firestore.Client()
        person_repo = PersonRepository(db)
        if flat_id:
            logger.info("%s flat=%s", LOG_TOKEN_RESET, flat_id)
            person_repo.reset_all_swap_tokens(flat_id)
        else:
            for flat_doc in db.collection(COLLECTION_FLATS).stream():
                logger.info("%s flat=%s", LOG_TOKEN_RESET, flat_doc.id)
                person_repo.reset_all_swap_tokens(flat_doc.id)
        return Response({"success": True}, status=200, mimetype="application/json")
    except Exception as exc:
        logger.error("token_reset_http failed error=%s", exc)
        return Response({"error": "Internal error"}, status=500, mimetype="application/json")
