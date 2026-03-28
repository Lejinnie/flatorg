"""Task ring constants and admin-configurable defaults."""

from __future__ import annotations

# Imported at runtime to avoid circular imports with models.task
# TaskLevel values are the string literals "L1", "L2", "L3"

# ── Task ring ─────────────────────────────────────────────────────────────────

TASK_RING_NAMES: tuple[str, ...] = (
    "Toilet",       # 0 — L3
    "Kitchen",      # 1 — L2
    "Recycling",    # 2 — L1
    "Shower",       # 3 — L3
    "Floor(A)",     # 4 — L2
    "Washing Rags", # 5 — L1
    "Bathroom",     # 6 — L3
    "Floor(B)",     # 7 — L2
    "Shopping",     # 8 — L1
)

TOTAL_TASKS: int = 9

# Maps ring_index (0–8) → difficulty level string ("L3"/"L2"/"L1").
# Kept as plain strings to avoid importing the TaskLevel enum here.
TASK_LEVEL_BY_RING_INDEX: tuple[str, ...] = (
    "L3",  # 0: Toilet
    "L2",  # 1: Kitchen
    "L1",  # 2: Recycling
    "L3",  # 3: Shower
    "L2",  # 4: Floor(A)
    "L1",  # 5: Washing Rags
    "L3",  # 6: Bathroom
    "L2",  # 7: Floor(B)
    "L1",  # 8: Shopping
)

L3_RING_INDICES: tuple[int, ...] = (0, 3, 6)
L2_RING_INDICES: tuple[int, ...] = (1, 4, 7)
L1_RING_INDICES: tuple[int, ...] = (2, 5, 8)

# ── Admin-configurable defaults ───────────────────────────────────────────────

DEFAULT_VACATION_THRESHOLD_WEEKS: int = 1
DEFAULT_GRACE_PERIOD_HOURS: int = 1
DEFAULT_REMINDER_HOURS_BEFORE_DEADLINE: int = 1
DEFAULT_SHOPPING_CLEANUP_HOURS: int = 6

SWAP_TOKENS_PER_SEMESTER: int = 3

ISSUE_SEND_COOLDOWN_DAYS: int = 5
EMAIL_TEMPLATE_COUNT: int = 3

# Milliseconds per hour — avoids magic numbers in cleanup calculations.
MS_PER_HOUR: int = 3_600_000
