"""SwapRequest model: a pending task-swap between two members."""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from typing import Any


class SwapRequestStatus(StrEnum):
    """Lifecycle state of a task-swap request."""

    Pending = "pending"
    Accepted = "accepted"
    Declined = "declined"


@dataclass
class SwapRequest:
    """A request from one member to swap tasks with another."""

    id: str
    requester_uid: str
    requester_task_id: str
    target_task_id: str
    status: SwapRequestStatus
    created_at: Any  # Firestore Timestamp


def swap_request_from_firestore(doc_id: str, data: dict[str, Any]) -> SwapRequest:
    """Convert a Firestore swapRequests document dict to a typed SwapRequest."""
    return SwapRequest(
        id=doc_id,
        requester_uid=data.get("requester_uid", ""),
        requester_task_id=data.get("requester_task_id", ""),
        target_task_id=data.get("target_task_id", ""),
        status=SwapRequestStatus(data.get("status", SwapRequestStatus.Pending)),
        created_at=data.get("created_at"),
    )
