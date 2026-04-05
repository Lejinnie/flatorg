"""Repository for Task documents under flats/{flatId}/tasks.

All Firestore access for tasks goes through this class (Repository pattern).
"""

from __future__ import annotations

from typing import Any

from constants.strings import (
    COLLECTION_FLATS,
    COLLECTION_TASKS,
    ERROR_TASK_NOT_FOUND,
)
from models.task import Task, TaskState, task_from_firestore, task_to_firestore


class TaskRepository:
    def __init__(self, db: Any) -> None:
        self._db = db

    def _task_ref(self, flat_id: str, task_id: str) -> Any:
        return self._db.collection(COLLECTION_FLATS).document(flat_id).collection(COLLECTION_TASKS).document(task_id)

    def _tasks_collection(self, flat_id: str) -> Any:
        return self._db.collection(COLLECTION_FLATS).document(flat_id).collection(COLLECTION_TASKS)

    def get_all_tasks(self, flat_id: str) -> list[Task]:
        """Fetch all tasks for a flat, ordered by ring_index."""
        snapshot = self._tasks_collection(flat_id).order_by("ring_index").stream()
        return [task_from_firestore(doc.id, doc.to_dict()) for doc in snapshot]

    def get_all_tasks_in_transaction(self, flat_id: str, transaction: Any) -> list[Task]:
        """Fetch all tasks for a flat within a transaction."""
        docs = self._tasks_collection(flat_id).order_by("ring_index").stream(transaction=transaction)
        return [task_from_firestore(doc.id, doc.to_dict()) for doc in docs]

    def get_task(self, flat_id: str, task_id: str) -> Task:
        """Fetch a single task by ID; raise ValueError if not found."""
        doc = self._task_ref(flat_id, task_id).get()
        if not doc.exists:
            raise ValueError(f"{ERROR_TASK_NOT_FOUND}: {task_id}")
        return task_from_firestore(doc.id, doc.to_dict())

    def get_task_in_transaction(self, flat_id: str, task_id: str, transaction: Any) -> Task:
        """Fetch a single task within a transaction; raise ValueError if not found."""
        doc = self._task_ref(flat_id, task_id).get(transaction=transaction)
        if not doc.exists:
            raise ValueError(f"{ERROR_TASK_NOT_FOUND}: {task_id}")
        return task_from_firestore(doc.id, doc.to_dict())

    def update_task(self, flat_id: str, task_id: str, updates: dict[str, Any]) -> None:
        """Update specific fields on a task document."""
        self._task_ref(flat_id, task_id).update(updates)

    def update_task_in_transaction(self, flat_id: str, task_id: str, updates: dict[str, Any], transaction: Any) -> None:
        """Update specific fields on a task document within a transaction."""
        transaction.update(self._task_ref(flat_id, task_id), updates)

    def create_task(self, flat_id: str, task_id: str, task: Task) -> None:
        """Create a new task document with a specified ID."""
        self._task_ref(flat_id, task_id).set(task_to_firestore(task))

    def enter_grace_period(self, flat_id: str, task_id: str) -> None:
        """Transition a task from Pending → NotDone (grace period entry).

        Only acts when the task is still Pending — idempotent if already transitioned.
        """
        from google.cloud.firestore_v1.transaction import transactional

        task_ref = self._task_ref(flat_id, task_id)

        @transactional  # type: ignore[untyped-decorator, unused-ignore]
        def _update_in_tx(tx: Any) -> None:
            doc = task_ref.get(transaction=tx)
            if not doc.exists:
                raise ValueError(f"{ERROR_TASK_NOT_FOUND}: {task_id}")
            if doc.to_dict().get("state") != TaskState.Pending.value:
                # Already completed or already in not_done — nothing to do.
                return
            tx.update(task_ref, {"state": TaskState.NotDone.value})

        _update_in_tx(self._db.transaction())
