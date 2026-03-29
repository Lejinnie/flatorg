"""Task model: state machine for a single household task."""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from typing import Any


class TaskLevel(StrEnum):
    """Difficulty level of a task in the rotation ring."""

    L1 = "L1"  # easy: Recycling, Washing Rags, Shopping
    L2 = "L2"  # medium: Kitchen, Floor(A), Floor(B)
    L3 = "L3"  # hard: Toilet, Shower, Bathroom


class TaskState(StrEnum):
    """Lifecycle state of a task within a single week.

    Drives UI colour coding and week_reset() categorisation.
    """

    # Set by week_reset(). Task not yet done — shown in yellow.
    Pending = "pending"
    # Assignee marked done before deadline — shown in green.
    Completed = "completed"
    # Deadline passed without completion (grace period) — shown in red.
    NotDone = "not_done"
    # Assignee was removed mid-week by admin. Treated like short/long vacation in reset.
    Vacant = "vacant"


@dataclass
class Task:
    """A single household task stored as a Firestore document.

    Acts as a state machine; transitions are driven by Cloud Function events.
    """

    # Firestore document ID.
    id: str
    # Display name (e.g. "Toilet", "Kitchen").
    name: str
    # Ordered list of subtask instructions shown to the assignee.
    description: list[str]
    # When the task must be completed. Cloud Functions schedule against this.
    due_date_time: Any  # google.cloud.firestore_v1.base_document.DocumentSnapshot Timestamp
    # UID of the currently assigned person. Empty string when vacant.
    assigned_to: str
    # UID of the pre-swap assignee. Non-empty only while a swap is active.
    # week_reset() always reads this field (via effective_assigned_to) to determine
    # green/red status, so swap outcomes do not affect the rotation.
    # Cleared after each weekly reset.
    original_assigned_to: str
    # Current lifecycle state.
    state: TaskState
    # Increments each reset cycle while the assignee is on vacation or the task is vacant.
    # Resets to 0 when the task is completed normally.
    weeks_not_cleaned: int
    # Position in the canonical task ring (0–8).
    ring_index: int


def effective_assigned_to(task: Task) -> str:
    """Return the effective assigned UID, respecting active swap overrides.

    week_reset() must use this to determine green/red status — never assigned_to directly.
    """
    return task.original_assigned_to if task.original_assigned_to != "" else task.assigned_to


def task_from_firestore(doc_id: str, data: dict[str, Any]) -> Task:
    """Convert a Firestore document snapshot dict to a typed Task."""
    return Task(
        id=doc_id,
        name=data.get("name", ""),
        description=data.get("description", []),
        due_date_time=data.get("due_date_time"),
        assigned_to=data.get("assigned_to", ""),
        original_assigned_to=data.get("original_assigned_to", ""),
        state=TaskState(data.get("state", TaskState.Pending)),
        weeks_not_cleaned=data.get("weeks_not_cleaned", 0),
        ring_index=data.get("ring_index", -1),
    )


def task_to_firestore(task: Task) -> dict[str, Any]:
    """Convert a Task to a plain Firestore-compatible dict (excludes id)."""
    return {
        "name": task.name,
        "description": task.description,
        "due_date_time": task.due_date_time,
        "assigned_to": task.assigned_to,
        "original_assigned_to": task.original_assigned_to,
        "state": task.state.value,
        "weeks_not_cleaned": task.weeks_not_cleaned,
        "ring_index": task.ring_index,
    }
