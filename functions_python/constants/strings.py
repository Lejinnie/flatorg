"""All user-facing and log strings. No inline string literals elsewhere."""

# ── Firestore collection names ────────────────────────────────────────────────

COLLECTION_FLATS = "flats"
COLLECTION_TASKS = "tasks"
COLLECTION_MEMBERS = "members"
COLLECTION_ISSUES = "issues"
COLLECTION_SWAP_REQUESTS = "swapRequests"
COLLECTION_SHOPPING_ITEMS = "shoppingItems"
COLLECTION_NOTIFICATIONS = "notifications"

# ── In-app notification field names ──────────────────────────────────────────

FIELD_NOTIF_TYPE = "type"
FIELD_NOTIF_TITLE = "title"
FIELD_NOTIF_BODY = "body"
FIELD_NOTIF_TASK_ID = "task_id"
FIELD_NOTIF_CREATED_AT = "created_at"

# In-app notification type values — must match Dart notifType* constants.
NOTIF_TYPE_REMINDER = "reminder"
NOTIF_TYPE_GRACE_PERIOD = "grace_period"
NOTIF_TYPE_TASK_COMPLETED = "task_completed"

# ── Firestore field names ─────────────────────────────────────────────────────

# Flat fields
FIELD_FLAT_NAME = "name"
FIELD_FLAT_ADMIN_UID = "admin_uid"
FIELD_FLAT_INVITE_CODE = "invite_code"
FIELD_FLAT_VACATION_THRESHOLD = "vacation_threshold_weeks"
FIELD_FLAT_GRACE_PERIOD_HOURS = "grace_period_hours"
FIELD_FLAT_REMINDER_HOURS = "reminder_hours_before_deadline"
FIELD_FLAT_SHOPPING_CLEANUP_HOURS = "shopping_cleanup_hours"
FIELD_FLAT_CREATED_AT = "created_at"
FIELD_FLAT_LAST_WEEK_RESET_AT = "last_week_reset_at"

# Task fields
FIELD_TASK_NAME = "name"
FIELD_TASK_DESCRIPTION = "description"
FIELD_TASK_DUE_DATE_TIME = "due_date_time"
FIELD_TASK_ASSIGNED_TO = "assigned_to"
FIELD_TASK_ORIGINAL_ASSIGNED_TO = "original_assigned_to"
FIELD_TASK_STATE = "state"
FIELD_TASK_WEEKS_NOT_CLEANED = "weeks_not_cleaned"
FIELD_TASK_RING_INDEX = "ring_index"
FIELD_TASK_DAY_BEFORE_REMINDER_SENT = "day_before_reminder_sent"
FIELD_TASK_HOURS_BEFORE_REMINDER_SENT = "hours_before_reminder_sent"

# Person fields
FIELD_PERSON_UID = "uid"
FIELD_PERSON_NAME = "name"
FIELD_PERSON_EMAIL = "email"
FIELD_PERSON_ROLE = "role"
FIELD_PERSON_ON_VACATION = "on_vacation"
FIELD_PERSON_SWAP_TOKENS = "swap_tokens_remaining"
FIELD_PERSON_FCM_TOKEN = "fcm_token"

# Issue fields
FIELD_ISSUE_TITLE = "title"
FIELD_ISSUE_DESCRIPTION = "description"
FIELD_ISSUE_CREATED_BY = "created_by"
FIELD_ISSUE_CREATED_AT = "created_at"
FIELD_ISSUE_LAST_SENT_AT = "last_sent_at"

# Shopping item fields
FIELD_SHOPPING_TEXT = "text"
FIELD_SHOPPING_ADDED_BY = "added_by"
FIELD_SHOPPING_IS_BOUGHT = "is_bought"
FIELD_SHOPPING_BOUGHT_AT = "bought_at"

# Swap request fields
FIELD_SWAP_REQUESTER_UID = "requester_uid"
FIELD_SWAP_TARGET_TASK_ID = "target_task_id"
FIELD_SWAP_REQUESTER_TASK_ID = "requester_task_id"
FIELD_SWAP_STATUS = "status"
FIELD_SWAP_CREATED_AT = "created_at"

# ── Task state values ─────────────────────────────────────────────────────────

TASK_STATE_PENDING = "pending"
TASK_STATE_COMPLETED = "completed"
TASK_STATE_NOT_DONE = "not_done"
TASK_STATE_VACANT = "vacant"

# ── Swap request status values ────────────────────────────────────────────────

SWAP_STATUS_PENDING = "pending"
SWAP_STATUS_ACCEPTED = "accepted"
SWAP_STATUS_DECLINED = "declined"

# ── Person role values ────────────────────────────────────────────────────────

PERSON_ROLE_ADMIN = "admin"
PERSON_ROLE_MEMBER = "member"

# ── Task level values ─────────────────────────────────────────────────────────

TASK_LEVEL_L1 = "L1"
TASK_LEVEL_L2 = "L2"
TASK_LEVEL_L3 = "L3"

# ── Notification strings ──────────────────────────────────────────────────────

NOTIFICATION_TITLE_REMINDER = "Task Reminder"
NOTIFICATION_BODY_REMINDER_DAY_BEFORE = (
    'Your task "{task_name}" is due tomorrow. Please complete it or mark yourself as on vacation.'
)
NOTIFICATION_BODY_REMINDER_HOURS_BEFORE = (
    'Your task "{task_name}" is due in {hours} hour(s). Please complete it or mark yourself as on vacation.'
)
NOTIFICATION_TITLE_TASK_COMPLETED = "Task Completed"
NOTIFICATION_BODY_TASK_COMPLETED = '{person_name} completed the task "{task_name}".'
NOTIFICATION_TITLE_GRACE_PERIOD = "Task Overdue"
NOTIFICATION_BODY_GRACE_PERIOD = (
    'Your task "{task_name}" deadline has passed. You have {hours} hour(s) until week reset.'
)
NOTIFICATION_TITLE_SWAP_REQUEST = "Task Swap Request"
NOTIFICATION_BODY_SWAP_REQUEST = "{requester_name} wants to swap tasks with you. You have {tokens}/3 tokens remaining."

# ── Log messages ──────────────────────────────────────────────────────────────

LOG_TRANSLATE_ISSUES = "translate_issues_callable: translated %d issue(s), %d characters consumed"
ERROR_DEEPL_KEY_MISSING = (
    "DEEPL_API_KEY secret is not configured. "
    "Run: firebase functions:secrets:set DEEPL_API_KEY"
)

LOG_WEEK_RESET_START = "week_reset: starting for flat"
LOG_WEEK_RESET_COMPLETE = "week_reset: completed for flat"
LOG_GRACE_PERIOD_TRANSITION = "enter_grace_period: task transitioned to not_done"
LOG_TOKEN_RESET = "token_reset: resetting swap tokens for flat"
LOG_SHOPPING_CLEANUP = "shopping_cleanup: removing bought items for flat"
LOG_DEADLINE_CHECK = "deadline_check: processing flat"
LOG_REMINDER_DAY_BEFORE_SENT = "deadline_check: day-before reminder sent"
LOG_REMINDER_HOURS_BEFORE_SENT = "deadline_check: hours-before reminder sent"
LOG_GRACE_PERIOD_AUTO = "deadline_check: auto-triggered grace period for task"
LOG_WEEK_RESET_AUTO = "deadline_check: auto-triggered week reset for flat"

# ── Error messages ────────────────────────────────────────────────────────────

ERROR_FLAT_NOT_FOUND = "Flat not found"
ERROR_TASK_NOT_FOUND = "Task not found"
ERROR_PERSON_NOT_FOUND = "Person not found"
ERROR_SWAP_REQUEST_NOT_FOUND = "Swap request not found"
ERROR_INSUFFICIENT_SWAP_TOKENS = "Insufficient swap tokens"
ERROR_TASK_ALREADY_COMPLETED = "Task is already completed"
ERROR_SWAP_NOT_PENDING = "Swap request is not in pending state"

# ── Livit email ───────────────────────────────────────────────────────────────

LIVIT_EMAIL_ADDRESS = "studentvillage@ch.issworld.com"
LIVIT_EMAIL_SUBJECT = "Mängelmeldung für die Wohnung HWB 33"
LIVIT_FLAT_REFERENCE = "HWB 33"
