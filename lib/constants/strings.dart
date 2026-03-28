// All user-facing strings and Firestore field/collection names.
// No inline string literals appear elsewhere in the codebase.

// ── Firestore collection names ────────────────────────────────────────────────

const String collectionFlats = 'flats';
const String collectionTasks = 'tasks';
const String collectionMembers = 'members';
const String collectionIssues = 'issues';
const String collectionSwapRequests = 'swapRequests';
const String collectionShoppingItems = 'shoppingItems';

// ── Task field names ──────────────────────────────────────────────────────────

const String fieldTaskName = 'name';
const String fieldTaskDescription = 'description';
const String fieldTaskDueDateTime = 'due_date_time';
const String fieldTaskAssignedTo = 'assigned_to';
const String fieldTaskOriginalAssignedTo = 'original_assigned_to';
const String fieldTaskState = 'state';
const String fieldTaskWeeksNotCleaned = 'weeks_not_cleaned';
const String fieldTaskRingIndex = 'ring_index';

// ── Person field names ────────────────────────────────────────────────────────

const String fieldPersonUid = 'uid';
const String fieldPersonName = 'name';
const String fieldPersonEmail = 'email';
const String fieldPersonRole = 'role';
const String fieldPersonOnVacation = 'on_vacation';
const String fieldPersonSwapTokens = 'swap_tokens_remaining';
const String fieldPersonFcmToken = 'fcm_token';

// ── Flat field names ──────────────────────────────────────────────────────────

const String fieldFlatName = 'name';
const String fieldFlatAdminUid = 'admin_uid';
const String fieldFlatInviteCode = 'invite_code';
const String fieldFlatVacationThreshold = 'vacation_threshold_weeks';
const String fieldFlatGracePeriodHours = 'grace_period_hours';
const String fieldFlatReminderHours = 'reminder_hours_before_deadline';
const String fieldFlatShoppingCleanupHours = 'shopping_cleanup_hours';
const String fieldFlatCreatedAt = 'created_at';

// ── Issue field names ─────────────────────────────────────────────────────────

const String fieldIssueTitle = 'title';
const String fieldIssueDescription = 'description';
const String fieldIssueCreatedBy = 'created_by';
const String fieldIssueCreatedAt = 'created_at';
const String fieldIssueLastSentAt = 'last_sent_at';

// ── Shopping item field names ─────────────────────────────────────────────────

const String fieldShoppingText = 'text';
const String fieldShoppingAddedBy = 'added_by';
const String fieldShoppingIsBought = 'is_bought';
const String fieldShoppingBoughtAt = 'bought_at';

// ── Swap request field names ──────────────────────────────────────────────────

const String fieldSwapRequesterUid = 'requester_uid';
const String fieldSwapTargetTaskId = 'target_task_id';
const String fieldSwapRequesterTaskId = 'requester_task_id';
const String fieldSwapStatus = 'status';
const String fieldSwapCreatedAt = 'created_at';

// ── Livit email ───────────────────────────────────────────────────────────────

const String livitEmailAddress = 'studentvillage@ch.issworld.com';
const String livitEmailSubject = 'Mängelmeldung für die Wohnung HWB 33';
const String livitFlatReference = 'HWB 33';

// ── UI strings ────────────────────────────────────────────────────────────────

const String appTitle = 'FlatOrg';
const String tabTasks = 'Tasks';
const String tabShoppingList = 'Shopping List';
const String tabIssueList = 'Issue List';

const String buttonMarkDone = 'Mark as Done';
const String buttonRequestSwap = 'Request Swap';
const String buttonOnVacation = 'Mark as On Vacation';
const String buttonGenerateInviteCode = 'Generate & Copy Invite Code';
const String buttonSendToLivit = 'Send to Livit';
const String buttonDeselectAll = 'Deselect All';

const String labelSwapTokensRemaining = 'Swap Tokens';
const String labelWeeksNotCleaned = 'Weeks Uncleaned';
const String labelVacationStatus = 'On Vacation';

const String errorTooManyAttempts = 'Too many attempts, try again later';
const String errorWeakPassword = 'Password must be at least 6 characters and contain a number';
const String errorEmailVerificationRequired =
    'Please verify your email before accessing the app';
const String errorInsufficientSwapTokens = 'You have no swap tokens remaining this semester';
const String errorIssueCooldown =
    'This issue was sent recently. Please wait before sending again';

const String hintEnterInviteCode = 'Enter invite code';
const String hintEnterEmail = 'Email';
const String hintEnterPassword = 'Password';
const String hintEnterName = 'Your name';
const String hintEnterFlatName = 'Flat name';
const String hintIssueTitle = 'Issue title';
const String hintIssueDescription = 'Describe the issue…';
const String hintShoppingItem = 'Add item…';

const String headingCreateFlat = 'Create a new flat';
const String headingJoinFlat = 'Join an existing flat';
const String headingAssignTasks = 'Let\'s assign tasks!';
const String headingSettings = 'Settings';

const String swapRequestAccepted = 'Swap request accepted';
const String swapRequestDeclined = 'Swap request declined';
const String swapTokensFormat = '{used}/3 Left';
