"""Shared helper functions for week_reset BDD tests.

Mirrors the test fixture helpers in functions/tests/weekReset.test.ts.
"""

from __future__ import annotations

from datetime import UTC, datetime

from models.person import Person, PersonRole
from models.task import Task, TaskState

FUTURE_DATE = datetime(2099, 1, 1, tzinfo=UTC)
DEFAULT_FLAT = {"vacation_threshold_weeks": 1}


def make_person(uid: str, on_vacation: bool = False, tokens: int = 3) -> Person:
    return Person(
        uid=uid,
        name=uid,
        email=f"{uid}@test.com",
        role=PersonRole.Member,
        on_vacation=on_vacation,
        swap_tokens_remaining=tokens,
    )


def make_task(
    ring_index: int,
    assigned_to: str,
    state: TaskState,
    weeks_not_cleaned: int = 0,
    original_assigned_to: str = "",
) -> Task:
    return Task(
        id=f"task-{ring_index}",
        name=f"Task {ring_index}",
        description=[],
        due_date_time=FUTURE_DATE,
        assigned_to=assigned_to,
        original_assigned_to=original_assigned_to,
        state=state,
        weeks_not_cleaned=weeks_not_cleaned,
        ring_index=ring_index,
    )


def build_full_scenario(
    person_ids: list[str],
    task_states: dict[int, TaskState] | None = None,
    on_vacation: dict[str, bool] | None = None,
    weeks_not_cleaned: dict[int, int] | None = None,
) -> tuple[list[Task], list[Person]]:
    """Build a full 9-task set where every person is assigned one task.

    Default state is Completed (Green) for all unless overridden.
    """
    task_states = task_states or {}
    on_vacation = on_vacation or {}
    weeks_not_cleaned = weeks_not_cleaned or {}

    persons = [make_person(uid, on_vacation.get(uid, False)) for uid in person_ids]
    tasks = [
        make_task(
            i,
            person_ids[i],
            task_states.get(i, TaskState.Completed),
            weeks_not_cleaned.get(i, 0),
        )
        for i in range(9)
    ]
    return tasks, persons
