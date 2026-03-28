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

// ── Navigation ────────────────────────────────────────────────────────────────

const String navTasks    = 'Tasks';
const String navShopping = 'Shopping';
const String navIssues   = 'Issues';

// ── Login / Auth ──────────────────────────────────────────────────────────────

const String headingWelcome        = 'Welcome to FlatOrg!';
const String labelLogin            = 'Login';
const String labelRegister         = 'Register / Sign Up';
const String buttonLogin           = 'Login';
const String buttonRegister        = 'Register';
const String buttonForgotPassword  = 'Forgot password?';
const String buttonResendEmail     = 'Resend verification email';
const String buttonContinue        = 'Continue';
const String verifyEmailHeading    = 'Verify your email';
const String verifyEmailBody       = 'A verification link was sent to your email address. Please check your inbox and tap the link, then come back here.';
const String resetLinkSent         = 'Password reset link sent — check your inbox.';
const String buttonSignOut         = 'Sign out';

// ── Entry screen ──────────────────────────────────────────────────────────────

const String entrySubtitle    = 'Do you want to:';
const String buttonCreateFlat = 'Create a new flat';
const String buttonJoinFlat   = 'Join an existing flat';

// ── Flat setup ────────────────────────────────────────────────────────────────

const String hintFlatCode         = 'Flat code';
const String labelYourFlatName    = 'Your flat name';
const String labelYourName        = 'Your name';
const String labelYourEmail       = 'Your email';
const String labelYourPassword    = 'Your password';
const String labelFlatCode        = 'Flat code';
const String labelWhatTasks       = 'What tasks?';
const String buttonAddMore        = 'Add more';
const String buttonRemoveTask     = '−';
const String hintSubtasks         = 'Subtasks (one per line)';
const String hintDueDate          = 'Due date & time';
const String labelFlatCreated     = 'Flat created!';
const String labelJoined          = 'Joined flat!';
const String errorFlatNotFound    = 'No flat found with that invite code.';
const String errorCreatingFlat    = 'Error creating flat. Please try again.';
const String errorJoiningFlat     = 'Error joining flat. Please try again.';

// ── Tasks screen ──────────────────────────────────────────────────────────────

const String welcomePrefix        = 'Welcome to ';
const String buttonShowMore       = 'Show more';
const String buttonShowLess       = 'Show less';
const String labelAssignee        = 'Assigned to: ';
const String labelDue             = 'Due: ';
const String labelUnassigned      = 'Unassigned';
const String labelVacant          = 'Vacant';
const String buttonCompleteTask   = 'Mark as Done';
const String buttonVacation       = 'Vacation';
const String labelNoNotifications = 'No notifications';
const String labelNotifications   = 'Notifications';

// ── Swap request ──────────────────────────────────────────────────────────────

/// Used in the notification panel. {name} is the requester's name.
const String swapRequestMessage   = 'wants to swap tasks with you. Do you accept?';
const String buttonAccept         = 'Yes';
const String buttonDecline        = 'No';

// ── Confirmation dialogs ──────────────────────────────────────────────────────

const String confirmCompleteTitle   = 'Complete task?';
const String confirmCompleteMessage = 'Mark this task as COMPLETED?';
const String confirmCompleteLabel   = 'Complete';

const String confirmVacationTitle   = 'Go on vacation?';
const String confirmVacationMessage = 'Mark yourself as ON VACATION for this task?';
const String confirmVacationLabel   = 'Vacation';

const String confirmSwapTitle       = 'Request swap?';
/// {tokens} is replaced with e.g. "2/3"
const String confirmSwapMessage     = '{tokens} tokens remaining. Request this task swap?';
const String confirmSwapLabel       = 'Request';

const String confirmRemoveTitle     = 'Remove member?';
/// {name} is replaced with the member's name.
const String confirmRemoveMessage   = 'Are you sure you want to remove {name} from the flat?';
const String confirmRemoveLabel     = 'Remove';

const String confirmAdminTitle      = 'Transfer admin rights?';
/// {name} is replaced with the selected member's name.
const String confirmAdminMessage    = 'You are about to transfer admin rights to {name}. Are you sure?';
const String confirmAdminLabel      = 'Transfer';

const String confirmResolvedTitle   = 'Mark as resolved?';
const String confirmResolvedMessage = 'Remove the selected issues from the list?';
const String confirmResolvedLabel   = 'Resolve';

const String confirmSendTitle       = 'Send to Livit?';
const String confirmSendMessage     = 'Did you write the complaints in German? Did you check the right problems to submit?';
const String confirmSendLabel       = 'Send';

const String buttonCancel = 'Cancel';
const String buttonConfirm = 'Confirm';

// ── Shopping screen ───────────────────────────────────────────────────────────

const String headingShopping          = 'Shopping List';
const String buttonAddItem            = 'Add Item';
/// {hours} is replaced with the cleanup interval.
const String shoppingDisappearsAfter  = 'Disappears after {hours}h';

// ── Issues screen ─────────────────────────────────────────────────────────────

const String headingIssues          = 'Flat Issues';
const String buttonAddIssue         = 'Add Issue';
const String buttonSend             = 'Send';
const String buttonResolved         = 'Resolved';
const String buttonSelectAll        = 'Select All';
const String buttonDeselectAllIssues = 'Deselect All';
const String hintIssueImageOptional = 'Image (optional)';
const String labelRecentlySent      = 'Recently sent';

// ── Settings screen ───────────────────────────────────────────────────────────

const String labelMembers                = 'Members';
const String labelAdminBadge             = '(admin)';
const String labelAdminOnlySettings      = 'Admin Settings';
const String labelVacationThreshold      = 'How many weeks can a task stay uncleaned?';
const String labelGracePeriod            = 'How long can a person still submit a task as done?';
const String labelShoppingCleanup        = 'How long until bought shopping items are auto-deleted?';
const String labelReminderHours          = 'Reminder for hours before deadline?';
const String labelChangeTasks            = 'Change Tasks';
const String labelTransferAdmin          = 'Transfer admin rights';
const String buttonGenerateInvite        = 'Generate & Copy Invite Code';
const String inviteCodeCopied            = 'Invite code copied to clipboard!';
const String labelUnitWeeks              = 'weeks';
const String labelUnitHours              = 'hours';
const String labelUnitMinutes            = 'minutes';
const String labelUnitDays               = 'days';
const String labelSelectMember           = 'Select a member';

// ── Generic error ─────────────────────────────────────────────────────────────

const String errorGeneric = 'Something went wrong. Please try again.';
