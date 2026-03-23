/** All user-facing and log strings. No inline string literals elsewhere. */

// ── Firestore collection / field names ──────────────────────────────────────

export const COLLECTION_FLATS = 'flats';
export const COLLECTION_TASKS = 'tasks';
export const COLLECTION_MEMBERS = 'members';
export const COLLECTION_ISSUES = 'issues';
export const COLLECTION_SWAP_REQUESTS = 'swapRequests';
export const COLLECTION_SHOPPING_ITEMS = 'shoppingItems';

// ── Firestore field names ────────────────────────────────────────────────────

// Flat fields
export const FIELD_FLAT_NAME = 'name';
export const FIELD_FLAT_ADMIN_UID = 'admin_uid';
export const FIELD_FLAT_INVITE_CODE = 'invite_code';
export const FIELD_FLAT_VACATION_THRESHOLD = 'vacation_threshold_weeks';
export const FIELD_FLAT_GRACE_PERIOD_HOURS = 'grace_period_hours';
export const FIELD_FLAT_REMINDER_HOURS = 'reminder_hours_before_deadline';
export const FIELD_FLAT_SHOPPING_CLEANUP_HOURS = 'shopping_cleanup_hours';
export const FIELD_FLAT_CREATED_AT = 'created_at';

// Task fields
export const FIELD_TASK_NAME = 'name';
export const FIELD_TASK_DESCRIPTION = 'description';
export const FIELD_TASK_DUE_DATE_TIME = 'due_date_time';
export const FIELD_TASK_ASSIGNED_TO = 'assigned_to';
export const FIELD_TASK_ORIGINAL_ASSIGNED_TO = 'original_assigned_to';
export const FIELD_TASK_STATE = 'state';
export const FIELD_TASK_WEEKS_NOT_CLEANED = 'weeks_not_cleaned';
export const FIELD_TASK_RING_INDEX = 'ring_index';

// Person fields
export const FIELD_PERSON_UID = 'uid';
export const FIELD_PERSON_NAME = 'name';
export const FIELD_PERSON_EMAIL = 'email';
export const FIELD_PERSON_ROLE = 'role';
export const FIELD_PERSON_ON_VACATION = 'on_vacation';
export const FIELD_PERSON_SWAP_TOKENS = 'swap_tokens_remaining';

// Issue fields
export const FIELD_ISSUE_TITLE = 'title';
export const FIELD_ISSUE_DESCRIPTION = 'description';
export const FIELD_ISSUE_CREATED_BY = 'created_by';
export const FIELD_ISSUE_CREATED_AT = 'created_at';
export const FIELD_ISSUE_LAST_SENT_AT = 'last_sent_at';

// Shopping item fields
export const FIELD_SHOPPING_TEXT = 'text';
export const FIELD_SHOPPING_ADDED_BY = 'added_by';
export const FIELD_SHOPPING_IS_BOUGHT = 'is_bought';
export const FIELD_SHOPPING_BOUGHT_AT = 'bought_at';

// Swap request fields
export const FIELD_SWAP_REQUESTER_UID = 'requester_uid';
export const FIELD_SWAP_TARGET_TASK_ID = 'target_task_id';
export const FIELD_SWAP_REQUESTER_TASK_ID = 'requester_task_id';
export const FIELD_SWAP_STATUS = 'status';
export const FIELD_SWAP_CREATED_AT = 'created_at';

// ── Task state values ────────────────────────────────────────────────────────

export const TASK_STATE_PENDING = 'pending';
export const TASK_STATE_COMPLETED = 'completed';
export const TASK_STATE_NOT_DONE = 'not_done';
export const TASK_STATE_VACANT = 'vacant';

// ── Swap request status values ───────────────────────────────────────────────

export const SWAP_STATUS_PENDING = 'pending';
export const SWAP_STATUS_ACCEPTED = 'accepted';
export const SWAP_STATUS_DECLINED = 'declined';

// ── Person role values ───────────────────────────────────────────────────────

export const PERSON_ROLE_ADMIN = 'admin';
export const PERSON_ROLE_MEMBER = 'member';

// ── Task level values ────────────────────────────────────────────────────────

export const TASK_LEVEL_L1 = 'L1';
export const TASK_LEVEL_L2 = 'L2';
export const TASK_LEVEL_L3 = 'L3';

// ── Notification strings ─────────────────────────────────────────────────────

export const NOTIFICATION_TITLE_REMINDER = 'Task Reminder';
export const NOTIFICATION_BODY_REMINDER_DAY_BEFORE =
  'Your task "{taskName}" is due tomorrow. Please complete it or mark yourself as on vacation.';
export const NOTIFICATION_BODY_REMINDER_HOURS_BEFORE =
  'Your task "{taskName}" is due in {hours} hour(s). Please complete it or mark yourself as on vacation.';
export const NOTIFICATION_TITLE_TASK_COMPLETED = 'Task Completed';
export const NOTIFICATION_BODY_TASK_COMPLETED = '{personName} completed the task "{taskName}".';
export const NOTIFICATION_TITLE_SWAP_REQUEST = 'Task Swap Request';
export const NOTIFICATION_BODY_SWAP_REQUEST =
  '{requesterName} wants to swap tasks with you. You have {tokens}/3 tokens remaining.';

// ── Log messages ─────────────────────────────────────────────────────────────

export const LOG_WEEK_RESET_START = 'week_reset: starting for flat';
export const LOG_WEEK_RESET_COMPLETE = 'week_reset: completed for flat';
export const LOG_GRACE_PERIOD_TRANSITION = 'enter_grace_period: task transitioned to not_done';
export const LOG_TOKEN_RESET = 'token_reset: resetting swap tokens for flat';
export const LOG_SHOPPING_CLEANUP = 'shopping_cleanup: removing bought items for flat';

// ── Error messages ────────────────────────────────────────────────────────────

export const ERROR_FLAT_NOT_FOUND = 'Flat not found';
export const ERROR_TASK_NOT_FOUND = 'Task not found';
export const ERROR_PERSON_NOT_FOUND = 'Person not found';
export const ERROR_SWAP_REQUEST_NOT_FOUND = 'Swap request not found';
export const ERROR_INSUFFICIENT_SWAP_TOKENS = 'Insufficient swap tokens';
export const ERROR_TASK_ALREADY_COMPLETED = 'Task is already completed';
export const ERROR_SWAP_NOT_PENDING = 'Swap request is not in pending state';

// ── Livit email ───────────────────────────────────────────────────────────────

export const LIVIT_EMAIL_ADDRESS = 'studentvillage@ch.issworld.com';
export const LIVIT_EMAIL_SUBJECT = 'Mängelmeldung für die Wohnung HWB 33';
export const LIVIT_FLAT_REFERENCE = 'HWB 33';
