"""Flat model: top-level document containing identity and admin settings."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from constants.task_constants import (
    DEFAULT_GRACE_PERIOD_HOURS,
    DEFAULT_REMINDER_HOURS_BEFORE_DEADLINE,
    DEFAULT_SHOPPING_CLEANUP_HOURS,
    DEFAULT_VACATION_THRESHOLD_WEEKS,
)


@dataclass
class Flat:
    """A co-living flat. Stored as a single Firestore document under /flats/{flatId}."""

    id: str
    name: str
    admin_uid: str
    invite_code: str
    # Short vs. long vacation cutoff (weeks). Default: 1.
    vacation_threshold_weeks: int = DEFAULT_VACATION_THRESHOLD_WEEKS
    # Hours after the last due date before week_reset() fires. Default: 1.
    grace_period_hours: int = DEFAULT_GRACE_PERIOD_HOURS
    # Hours before a task deadline to send a reminder notification. Default: 1.
    reminder_hours_before_deadline: int = DEFAULT_REMINDER_HOURS_BEFORE_DEADLINE
    # Hours before bought shopping items are auto-deleted. Default: 6.
    shopping_cleanup_hours: int = DEFAULT_SHOPPING_CLEANUP_HOURS


def flat_from_firestore(doc_id: str, data: dict[str, Any]) -> Flat:
    """Convert a Firestore flat document dict to a typed Flat."""
    return Flat(
        id=doc_id,
        name=data.get("name", ""),
        admin_uid=data.get("admin_uid", ""),
        invite_code=data.get("invite_code", ""),
        vacation_threshold_weeks=data.get("vacation_threshold_weeks", DEFAULT_VACATION_THRESHOLD_WEEKS),
        grace_period_hours=data.get("grace_period_hours", DEFAULT_GRACE_PERIOD_HOURS),
        reminder_hours_before_deadline=data.get(
            "reminder_hours_before_deadline", DEFAULT_REMINDER_HOURS_BEFORE_DEADLINE
        ),
        shopping_cleanup_hours=data.get("shopping_cleanup_hours", DEFAULT_SHOPPING_CLEANUP_HOURS),
    )
