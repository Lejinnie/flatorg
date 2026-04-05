"""Strategy pattern: the 8 assignment steps executed during week_reset().

Each concrete strategy implements AssignmentStrategy.execute(ctx) and mutates
ctx.next_assignments in place. The WeekResetService orchestrates them in order.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field

from constants.task_constants import (
    L1_RING_INDICES,
    L2_RING_INDICES,
    L3_RING_INDICES,
    TASK_LEVEL_BY_RING_INDEX,
    TOTAL_TASKS,
)
from models.person import Person
from models.task import Task, TaskLevel, TaskState, effective_assigned_to

# ── Shared context ────────────────────────────────────────────────────────────


@dataclass
class WeekResetContext:
    """Mutable working state shared across all assignment strategy steps.

    next_assignments maps ring_index → assigned UID for the *next* week.
    Empty-string sentinel means the slot is not yet assigned.
    """

    tasks: list[Task]
    persons: list[Person]
    vacation_threshold_weeks: int
    # Populated incrementally by each strategy; '' = unassigned.
    next_assignments: list[str] = field(default_factory=lambda: [""] * TOTAL_TASKS)


def build_week_reset_context(
    tasks: list[Task],
    persons: list[Person],
    vacation_threshold_weeks: int,
) -> WeekResetContext:
    """Create a blank context with all next-week slots unassigned."""
    return WeekResetContext(
        tasks=tasks,
        persons=persons,
        vacation_threshold_weeks=vacation_threshold_weeks,
        next_assignments=[""] * TOTAL_TASKS,
    )


# ── Categorisation helpers ────────────────────────────────────────────────────


@dataclass
class PersonTaskPair:
    """Resolved view of a person and their associated task for this week."""

    person: Person
    task: Task


def _build_uid_to_task_map(tasks: list[Task]) -> dict[str, Task]:
    """Build a uid → Task lookup using effective_assigned_to."""
    mapping: dict[str, Task] = {}
    for task in tasks:
        uid = effective_assigned_to(task)
        if uid != "":
            mapping[uid] = task
    return mapping


def categorise_persons(
    ctx: WeekResetContext,
) -> tuple[
    list[PersonTaskPair],  # green
    list[PersonTaskPair],  # red
    list[PersonTaskPair],  # blue_short
    list[PersonTaskPair],  # blue_long
]:
    """Classify every person as Green, Red, BlueShort, or BlueLong.

    Within each category the list is sorted by ascending ring_index of their
    current task (task-ring order as required by the spec).
    """
    uid_to_task = _build_uid_to_task_map(ctx.tasks)
    green: list[PersonTaskPair] = []
    red: list[PersonTaskPair] = []
    blue_short: list[PersonTaskPair] = []
    blue_long: list[PersonTaskPair] = []

    for person in ctx.persons:
        task = uid_to_task.get(person.uid)
        if task is None:
            # Person has no task this week — should not happen in normal operation.
            continue

        if person.on_vacation:
            if task.weeks_not_cleaned <= ctx.vacation_threshold_weeks:
                blue_short.append(PersonTaskPair(person=person, task=task))
            else:
                blue_long.append(PersonTaskPair(person=person, task=task))
        elif task.state == TaskState.Completed:
            green.append(PersonTaskPair(person=person, task=task))
        else:
            # NotDone, Pending-but-past-deadline, or Vacant → treated as Red.
            red.append(PersonTaskPair(person=person, task=task))

    def by_ring_index(pair: PersonTaskPair) -> int:
        return pair.task.ring_index

    return (
        sorted(green, key=by_ring_index),
        sorted(red, key=by_ring_index),
        sorted(blue_short, key=by_ring_index),
        sorted(blue_long, key=by_ring_index),
    )


# ── Slot helpers ──────────────────────────────────────────────────────────────


def level_of_slot(ring_index: int) -> TaskLevel:
    """Return the TaskLevel of a slot by its ring index."""
    return TaskLevel(TASK_LEVEL_BY_RING_INDEX[ring_index])


def level_weight(level: TaskLevel) -> int:
    """Numeric weight of a level (higher = harder) for sorting comparisons."""
    return {TaskLevel.L3: 3, TaskLevel.L2: 2, TaskLevel.L1: 1}[level]


def free_slots_by_level(ctx: WeekResetContext, level: TaskLevel) -> list[int]:
    """Return all ring indices for the given level that are still unassigned."""
    if level == TaskLevel.L3:
        indices = L3_RING_INDICES
    elif level == TaskLevel.L2:
        indices = L2_RING_INDICES
    else:
        indices = L1_RING_INDICES
    return [i for i in indices if ctx.next_assignments[i] == ""]


def assign_slot(ctx: WeekResetContext, ring_index: int, uid: str) -> None:
    """Assign a person to a specific ring-index slot in the context."""
    ctx.next_assignments[ring_index] = uid


def scan_forward_for_free_slot(ctx: WeekResetContext, start_ring_index: int, level: TaskLevel) -> int:
    """Scan forward in the task ring for the next unassigned slot at the given level.

    Returns the ring index of the found slot, or -1 if none exists.
    """
    for offset in range(1, TOTAL_TASKS + 1):
        candidate = (start_ring_index + offset) % TOTAL_TASKS
        if level_of_slot(candidate) == level and ctx.next_assignments[candidate] == "":
            return candidate
    return -1


def scan_forward_for_lower_free_slot(ctx: WeekResetContext, start_ring_index: int, current_level: TaskLevel) -> int:
    """Scan forward for the first free slot at ANY level strictly lower than current_level.

    Returns -1 if no eligible free slot exists.
    """
    current_weight = level_weight(current_level)
    for offset in range(1, TOTAL_TASKS + 1):
        candidate = (start_ring_index + offset) % TOTAL_TASKS
        if level_weight(level_of_slot(candidate)) < current_weight and ctx.next_assignments[candidate] == "":
            return candidate
    return -1


def scan_backward_for_higher_free_slot(ctx: WeekResetContext, start_ring_index: int, current_level: TaskLevel) -> int:
    """Scan backward in the task ring for the first free slot strictly higher than current_level.

    Returns -1 if no eligible free slot exists.
    Python's % always returns a non-negative result, so no double-modulo needed.
    """
    current_weight = level_weight(current_level)
    for offset in range(1, TOTAL_TASKS + 1):
        candidate = (start_ring_index - offset) % TOTAL_TASKS
        if level_weight(level_of_slot(candidate)) > current_weight and ctx.next_assignments[candidate] == "":
            return candidate
    return -1


def forward_ring_distance(from_index: int, to_index: int) -> int:
    """Return the shortest forward ring distance from from_index to to_index.

    Always returns 1–TOTAL_TASKS.
    """
    dist = (to_index - from_index + TOTAL_TASKS) % TOTAL_TASKS
    return dist if dist != 0 else TOTAL_TASKS


# ── Strategy interface ────────────────────────────────────────────────────────


class AssignmentStrategy(ABC):
    """Strategy pattern: each step in week_reset() implements this interface.

    execute() modifies ctx.next_assignments in place.
    """

    @abstractmethod
    def execute(self, ctx: WeekResetContext) -> None: ...


# ── Step 1: Blue short vacation ───────────────────────────────────────────────


class BlueShortVacationStrategy(AssignmentStrategy):
    """Assign short-vacation people (weeks_not_cleaned ≤ threshold) to protected slots.

    Fills L1 first, then L2, then L3 when there are more vacation people than L1 slots.
    Among vacation people, those who had harder tasks get the harder available slots.
    """

    def execute(self, ctx: WeekResetContext) -> None:
        _, _, blue_short, _ = categorise_persons(ctx)
        if not blue_short:
            return

        # Sort ascending by original task level so easier-task people pick first
        # and claim L1. Harder-task people land on the overflow slots (L2, L3).
        sorted_blue = sorted(
            blue_short,
            key=lambda p: level_weight(level_of_slot(p.task.ring_index)),
        )

        preferred_levels = [TaskLevel.L1, TaskLevel.L2, TaskLevel.L3]

        for pair in sorted_blue:
            for level in preferred_levels:
                free = free_slots_by_level(ctx, level)
                if free:
                    assign_slot(ctx, free[0], pair.person.uid)
                    break


# ── Step 2: Green L3 ──────────────────────────────────────────────────────────


class GreenL3Strategy(AssignmentStrategy):
    """Green L3 people scan forward for the first free slot at any lower difficulty.

    If no lower slot is free, they stay at L3.
    """

    def execute(self, ctx: WeekResetContext) -> None:
        green, _, _, _ = categorise_persons(ctx)
        green_l3 = [p for p in green if level_of_slot(p.task.ring_index) == TaskLevel.L3]

        for pair in green_l3:
            target = scan_forward_for_lower_free_slot(ctx, pair.task.ring_index, TaskLevel.L3)
            if target != -1:
                assign_slot(ctx, target, pair.person.uid)
            else:
                # No free lower slot — stay at L3.
                free_l3 = free_slots_by_level(ctx, TaskLevel.L3)
                if free_l3:
                    assign_slot(ctx, free_l3[0], pair.person.uid)


# ── Step 3: Green L2 ──────────────────────────────────────────────────────────


class GreenL2Strategy(AssignmentStrategy):
    """Green L2 people scan forward for the next free L1 slot.

    If no L1 slot is available, they stay at L2.
    """

    def execute(self, ctx: WeekResetContext) -> None:
        green, _, _, _ = categorise_persons(ctx)
        green_l2 = [p for p in green if level_of_slot(p.task.ring_index) == TaskLevel.L2]

        for pair in green_l2:
            target = scan_forward_for_free_slot(ctx, pair.task.ring_index, TaskLevel.L1)
            if target != -1:
                assign_slot(ctx, target, pair.person.uid)
            else:
                free_l2 = free_slots_by_level(ctx, TaskLevel.L2)
                if free_l2:
                    assign_slot(ctx, free_l2[0], pair.person.uid)


# ── Step 4: Red L3 ────────────────────────────────────────────────────────────


class RedL3Strategy(AssignmentStrategy):
    """Red L3 people stay at L3.

    They take their same task if unassigned; otherwise any other free L3.
    """

    def execute(self, ctx: WeekResetContext) -> None:
        _, red, _, _ = categorise_persons(ctx)
        red_l3 = [p for p in red if level_of_slot(p.task.ring_index) == TaskLevel.L3]

        for pair in red_l3:
            if ctx.next_assignments[pair.task.ring_index] == "":
                assign_slot(ctx, pair.task.ring_index, pair.person.uid)
            else:
                free_l3 = free_slots_by_level(ctx, TaskLevel.L3)
                if free_l3:
                    assign_slot(ctx, free_l3[0], pair.person.uid)
                # If no free L3 (all taken by Blue), the Red L3 person is left unassigned;
                # a later catch-all step handles that edge case.


# ── Step 5: Red L2 ────────────────────────────────────────────────────────────


class RedL2Strategy(AssignmentStrategy):
    """Red L2 people scan backward for the nearest free L3 slot (punishment).

    If no L3 slot is free, they stay at their current L2 task.
    """

    def execute(self, ctx: WeekResetContext) -> None:
        _, red, _, _ = categorise_persons(ctx)
        red_l2 = [p for p in red if level_of_slot(p.task.ring_index) == TaskLevel.L2]

        for pair in red_l2:
            backward = scan_backward_for_higher_free_slot(ctx, pair.task.ring_index, TaskLevel.L2)
            if backward != -1:
                assign_slot(ctx, backward, pair.person.uid)
            # No free L3 anywhere — stay at L2.
            elif ctx.next_assignments[pair.task.ring_index] == "":
                assign_slot(ctx, pair.task.ring_index, pair.person.uid)
            else:
                free_l2 = free_slots_by_level(ctx, TaskLevel.L2)
                if free_l2:
                    assign_slot(ctx, free_l2[0], pair.person.uid)


# ── Step 6: Red L1 ────────────────────────────────────────────────────────────


class RedL1Strategy(AssignmentStrategy):
    """Red L1 people scan backward to find a harder task (punishment).

    Phase 1 — nearest L2 (ring−1): if free, take it.
    Phase 2 — nearest L3 (ring−2): if free, take it.
    Phase 3 — any free L3 (harder punishment preferred over L2).
    Phase 4 — any free L2.
    Phase 5 — stay at L1 (no higher slot available).
    Reds do NOT cycle back to L1 during the search.
    """

    def execute(self, ctx: WeekResetContext) -> None:
        _, red, _, _ = categorise_persons(ctx)
        red_l1 = [p for p in red if level_of_slot(p.task.ring_index) == TaskLevel.L1]

        for pair in red_l1:
            # Phase 1: nearest L2 (ring - 1)
            nearest_l2 = (pair.task.ring_index - 1) % TOTAL_TASKS
            if level_of_slot(nearest_l2) == TaskLevel.L2 and ctx.next_assignments[nearest_l2] == "":
                assign_slot(ctx, nearest_l2, pair.person.uid)
                continue

            # Phase 2: nearest L3 (ring - 2)
            nearest_l3 = (pair.task.ring_index - 2) % TOTAL_TASKS
            if level_of_slot(nearest_l3) == TaskLevel.L3 and ctx.next_assignments[nearest_l3] == "":
                assign_slot(ctx, nearest_l3, pair.person.uid)
                continue

            # Phase 3: any free L3
            free_l3 = free_slots_by_level(ctx, TaskLevel.L3)
            if free_l3:
                assign_slot(ctx, free_l3[0], pair.person.uid)
                continue

            # Phase 4: any free L2
            free_l2 = free_slots_by_level(ctx, TaskLevel.L2)
            if free_l2:
                assign_slot(ctx, free_l2[0], pair.person.uid)
                continue

            # Phase 5: stay at L1
            if ctx.next_assignments[pair.task.ring_index] == "":
                assign_slot(ctx, pair.task.ring_index, pair.person.uid)
            else:
                free_l1 = free_slots_by_level(ctx, TaskLevel.L1)
                if free_l1:
                    assign_slot(ctx, free_l1[0], pair.person.uid)


# ── Step 7: Green L1 ─────────────────────────────────────────────────────────


class GreenL1Strategy(AssignmentStrategy):
    """Green L1 people fill remaining slots using shortest forward ring distance.

    For each free slot, assign the Green L1 person with the shortest forward
    distance to it in the task ring. Assigned last to avoid competing with Reds.
    """

    def execute(self, ctx: WeekResetContext) -> None:
        green, _, _, _ = categorise_persons(ctx)
        unassigned_green_l1 = [
            p
            for p in green
            if level_of_slot(p.task.ring_index) == TaskLevel.L1 and p.person.uid not in ctx.next_assignments
        ]

        if not unassigned_green_l1:
            return

        free_slots = [i for i, uid in enumerate(ctx.next_assignments) if uid == ""]
        remaining = list(unassigned_green_l1)

        for slot_index in free_slots:
            if not remaining:
                break

            # Find the Green L1 person with the shortest forward distance to this slot.
            best_idx = 0
            best_dist = forward_ring_distance(remaining[0].task.ring_index, slot_index)

            for i in range(1, len(remaining)):
                dist = forward_ring_distance(remaining[i].task.ring_index, slot_index)
                if dist < best_dist:
                    best_dist = dist
                    best_idx = i

            assign_slot(ctx, slot_index, remaining[best_idx].person.uid)
            remaining.pop(best_idx)


# ── Step 8: Blue long vacation ────────────────────────────────────────────────


class BlueLongVacationStrategy(AssignmentStrategy):
    """Long-vacation people fill whatever slots remain last.

    Their slots are unprotected — Green people can take them, preventing
    long-term vacation from blocking the reward/punishment mechanism.
    """

    def execute(self, ctx: WeekResetContext) -> None:
        _, _, _, blue_long = categorise_persons(ctx)
        if not blue_long:
            return

        free_slots = [i for i, uid in enumerate(ctx.next_assignments) if uid == ""]

        for i, pair in enumerate(blue_long):
            if i >= len(free_slots):
                break
            assign_slot(ctx, free_slots[i], pair.person.uid)
