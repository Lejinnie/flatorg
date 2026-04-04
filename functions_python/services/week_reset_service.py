"""WeekResetService: orchestrates the weekly task reassignment algorithm.

Uses the Template Method pattern: a fixed sequence of AssignmentStrategy steps
runs inside a single Firestore transaction to guarantee atomicity.
"""

from __future__ import annotations

import logging
from typing import Any, ClassVar, cast

from constants.strings import (
    COLLECTION_FLATS,
    COLLECTION_SWAP_REQUESTS,
    ERROR_INSUFFICIENT_SWAP_TOKENS,
    ERROR_SWAP_NOT_PENDING,
    LOG_WEEK_RESET_COMPLETE,
    LOG_WEEK_RESET_START,
)
from models.person import Person
from models.swap_request import SwapRequestStatus, swap_request_from_firestore
from models.task import Task, TaskState, effective_assigned_to
from repository.flat_repository import FlatRepository
from repository.person_repository import PersonRepository
from repository.task_repository import TaskRepository
from services.assignment_strategy import (
    AssignmentStrategy,
    BlueLongVacationStrategy,
    BlueShortVacationStrategy,
    GreenL1Strategy,
    GreenL2Strategy,
    GreenL3Strategy,
    RedL1Strategy,
    RedL2Strategy,
    RedL3Strategy,
    WeekResetContext,
    build_week_reset_context,
)

logger = logging.getLogger(__name__)


class WeekResetService:
    """Orchestrates the weekly task reassignment algorithm.

    Step order matches the spec in CLAUDE.md:
      1. Blue short vacation (protected slots)
      2. Green L3 → L2/L1 (scan forward)
      3. Green L2 → L1 (scan forward)
      4. Red L3 → stay L3
      5. Red L2 → up to L3
      6. Red L1 → up to L2/L3
      7. Green L1 → fill remaining (shortest ring distance)
      8. Blue long vacation → fill remaining (unprotected)
    """

    # Fixed ordered list of strategies executed each reset cycle.
    _STRATEGIES: ClassVar[list[AssignmentStrategy]] = [
        BlueShortVacationStrategy(),
        GreenL3Strategy(),
        GreenL2Strategy(),
        RedL3Strategy(),
        RedL2Strategy(),
        RedL1Strategy(),
        GreenL1Strategy(),
        BlueLongVacationStrategy(),
    ]

    def __init__(self, db: Any) -> None:
        self._db = db
        self._task_repo = TaskRepository(db)
        self._person_repo = PersonRepository(db)
        self._flat_repo = FlatRepository(db)

    def week_reset(self, flat_id: str) -> None:
        """Run the full weekly reset for a flat inside a single Firestore transaction."""
        from google.cloud.firestore_v1.transaction import transactional

        logger.info("%s %s", LOG_WEEK_RESET_START, flat_id)

        @transactional
        def _run(transaction: Any) -> None:
            flat = self._flat_repo.get_flat_in_transaction(flat_id, transaction)
            tasks = self._task_repo.get_all_tasks_in_transaction(flat_id, transaction)
            persons = self._person_repo.get_all_members_in_transaction(flat_id, transaction)

            updated_tasks = _increment_weeks_not_cleaned(tasks, persons)

            ctx = build_week_reset_context(updated_tasks, persons, flat.vacation_threshold_weeks)
            for strategy in self._STRATEGIES:
                strategy.execute(ctx)

            _write_reset_results(
                flat_id,
                updated_tasks,
                ctx,
                transaction,
                self._task_repo,
            )

        _run(self._db.transaction())
        logger.info("%s %s", LOG_WEEK_RESET_COMPLETE, flat_id)

    def completed_task(self, flat_id: str, task_id: str) -> None:
        """Mark a task as completed and clear the assignee's on_vacation flag.

        Does NOT modify original_assigned_to — swap tracking is independent.
        """
        from google.cloud.firestore_v1.transaction import transactional

        @transactional
        def _run(transaction: Any) -> None:
            task = self._task_repo.get_task_in_transaction(flat_id, task_id, transaction)
            self._task_repo.update_task_in_transaction(
                flat_id,
                task_id,
                {"state": TaskState.Completed.value, "weeks_not_cleaned": 0},
                transaction,
            )
            uid = effective_assigned_to(task)
            if uid != "":
                self._person_repo.update_member_in_transaction(flat_id, uid, {"on_vacation": False}, transaction)

        _run(self._db.transaction())

    def request_change_task(
        self,
        flat_id: str,
        requester_uid: str,
        requester_task_id: str,
        target_task_id: str,
    ) -> str:
        """Record a swap request from requester_uid targeting target_task_id.

        Returns the created swap request document ID.
        """
        from google.cloud.firestore_v1 import SERVER_TIMESTAMP

        swap_ref = (
            self._db.collection(COLLECTION_FLATS).document(flat_id).collection(COLLECTION_SWAP_REQUESTS).document()
        )
        swap_ref.set(
            {
                "requester_uid": requester_uid,
                "requester_task_id": requester_task_id,
                "target_task_id": target_task_id,
                "status": SwapRequestStatus.Pending.value,
                "created_at": SERVER_TIMESTAMP,
            }
        )
        return str(swap_ref.id)

    def accept_swap(self, flat_id: str, swap_request_id: str) -> None:
        """Accept a swap request: swap assigned_to on both tasks, deduct 1 token.

        Raises ValueError when the request is not Pending or the requester has no tokens.
        """
        from google.cloud.firestore_v1.transaction import transactional

        swap_ref = (
            self._db.collection(COLLECTION_FLATS)
            .document(flat_id)
            .collection(COLLECTION_SWAP_REQUESTS)
            .document(swap_request_id)
        )

        @transactional
        def _run(transaction: Any) -> None:
            swap_doc = swap_ref.get(transaction=transaction)
            swap = swap_request_from_firestore(swap_doc.id, swap_doc.to_dict())

            if swap.status != SwapRequestStatus.Pending:
                raise ValueError(ERROR_SWAP_NOT_PENDING)

            requester = self._person_repo.get_member(flat_id, swap.requester_uid)
            if requester.swap_tokens_remaining <= 0:
                raise ValueError(ERROR_INSUFFICIENT_SWAP_TOKENS)

            requester_task = self._task_repo.get_task_in_transaction(flat_id, swap.requester_task_id, transaction)
            target_task = self._task_repo.get_task_in_transaction(flat_id, swap.target_task_id, transaction)

            self._task_repo.update_task_in_transaction(
                flat_id,
                swap.requester_task_id,
                {
                    "assigned_to": target_task.assigned_to,
                    "original_assigned_to": requester_task.assigned_to,
                },
                transaction,
            )
            self._task_repo.update_task_in_transaction(
                flat_id,
                swap.target_task_id,
                {
                    "assigned_to": requester_task.assigned_to,
                    "original_assigned_to": target_task.assigned_to,
                },
                transaction,
            )
            self._person_repo.update_member_in_transaction(
                flat_id,
                swap.requester_uid,
                {"swap_tokens_remaining": requester.swap_tokens_remaining - 1},
                transaction,
            )
            transaction.update(swap_ref, {"status": SwapRequestStatus.Accepted.value})

        _run(self._db.transaction())


# ── Private helpers ───────────────────────────────────────────────────────────


def _increment_weeks_not_cleaned(tasks: list[Task], persons: list[Person]) -> list[Task]:
    """Increment weeks_not_cleaned on every task whose assignee is on vacation or Vacant.

    Returns a new list with updated tasks; happens before categorisation so the
    threshold comparison uses the current value.
    """
    vacation_uids = {p.uid for p in persons if p.on_vacation}
    result: list[Task] = []
    for task in tasks:
        effective_uid = effective_assigned_to(task)
        is_vacant = task.state == TaskState.Vacant
        assignee_on_vacation = effective_uid != "" and effective_uid in vacation_uids
        if is_vacant or assignee_on_vacation:
            from dataclasses import replace

            result.append(replace(task, weeks_not_cleaned=task.weeks_not_cleaned + 1))
        else:
            result.append(task)
    return result


def _write_reset_results(
    flat_id: str,
    tasks: list[Task],
    ctx: WeekResetContext,
    transaction: Any,
    task_repo: TaskRepository,
) -> None:
    """Apply all computed next-week assignments and reset task/person state in the transaction."""
    task_by_ring_index = {task.ring_index: task for task in tasks}

    for ring_index, new_assignee in enumerate(ctx.next_assignments):
        task = task_by_ring_index.get(ring_index)
        if task is None:
            continue
        task_repo.update_task_in_transaction(
            flat_id,
            task.id,
            {
                "assigned_to": new_assignee,
                "original_assigned_to": "",
                "state": TaskState.Pending.value,
                "weeks_not_cleaned": task.weeks_not_cleaned,
            },
            transaction,
        )

    # on_vacation is intentionally NOT cleared here.
    # Per spec, only completed_task() clears on_vacation — when a person
    # completes their assigned task they are considered back from vacation.
    # Clearing it on reset would show vacation-assigned tasks as yellow
    # instead of blue.


# ── Exported helper: pure in-memory algorithm for testing ────────────────────


def run_week_reset_algorithm(
    tasks: list[Task],
    persons: list[Person],
    flat: Any,  # Any object with vacation_threshold_weeks attribute or dict key
) -> list[str]:
    """Run the week_reset algorithm on in-memory data without touching Firestore.

    Used for unit and BDD tests. Returns next_assignments as a list[str].
    """
    threshold = flat["vacation_threshold_weeks"] if isinstance(flat, dict) else flat.vacation_threshold_weeks

    updated_tasks = _increment_weeks_not_cleaned(tasks, persons)
    ctx = build_week_reset_context(updated_tasks, persons, threshold)

    strategies: list[AssignmentStrategy] = [
        BlueShortVacationStrategy(),
        GreenL3Strategy(),
        GreenL2Strategy(),
        RedL3Strategy(),
        RedL2Strategy(),
        RedL1Strategy(),
        GreenL1Strategy(),
        BlueLongVacationStrategy(),
    ]
    for strategy in strategies:
        strategy.execute(ctx)

    return cast(list[str], ctx.next_assignments)
