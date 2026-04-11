"""Firebase Cloud Functions entry point.

Firebase discovers all exported functions from this module. Each trigger module
exports its functions at module level; we import them here so the SDK can find them.
"""

import firebase_admin

# Initialise Firebase Admin SDK once. All functions share this instance.
firebase_admin.initialize_app()

# ── Week reset ────────────────────────────────────────────────────────────────
# ── Automatic deadline / reminder / week-reset scheduler ─────────────────────
from triggers.deadline_check_trigger import (  # noqa: F401, E402
    check_deadlines_http,
    check_deadlines_scheduled,
)

# ── Grace period (pending → not_done) ────────────────────────────────────────
from triggers.grace_period_trigger import (  # noqa: F401, E402
    enter_grace_period_all_callable,
    enter_grace_period_callable,
    enter_grace_period_http,
)
from triggers.notify_swap_request_trigger import notify_swap_request_callable  # noqa: F401, E402

# ── Push / in-app notification callables ─────────────────────────────────────
from triggers.notify_task_completed_trigger import notify_task_completed_callable  # noqa: F401, E402

# ── Task reminder notifications ───────────────────────────────────────────────
from triggers.reminder_trigger import (  # noqa: F401, E402
    send_day_before_reminder_callable,
    send_day_before_reminder_http,
    send_hours_before_reminder_callable,
    send_hours_before_reminder_http,
)

# ── Shopping item cleanup ─────────────────────────────────────────────────────
from triggers.shopping_cleanup_trigger import (  # noqa: F401, E402
    shopping_cleanup_http,
    shopping_cleanup_scheduled,
)

# ── Semester token reset ──────────────────────────────────────────────────────
from triggers.token_reset_trigger import token_reset_http, token_reset_scheduled  # noqa: F401, E402
from triggers.translate_issues_trigger import translate_issues_callable  # noqa: F401, E402
from triggers.week_reset_trigger import week_reset_callable, week_reset_http  # noqa: F401, E402
