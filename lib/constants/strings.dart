// All user-facing strings and Firestore field/collection names.
// No inline string literals appear elsewhere in the codebase.

// ── Firestore collection names ────────────────────────────────────────────────

const collectionFlats = 'flats';
const collectionTasks = 'tasks';
const collectionMembers = 'members';
const collectionIssues = 'issues';
const collectionSwapRequests = 'swapRequests';
const collectionShoppingItems = 'shoppingItems';

// ── Task field names ──────────────────────────────────────────────────────────

const fieldTaskName = 'name';
const fieldTaskDescription = 'description';
const fieldTaskDueDateTime = 'due_date_time';
const fieldTaskAssignedTo = 'assigned_to';
const fieldTaskOriginalAssignedTo = 'original_assigned_to';
const fieldTaskState = 'state';
const fieldTaskWeeksNotCleaned = 'weeks_not_cleaned';
const fieldTaskRingIndex = 'ring_index';

// ── Person field names ────────────────────────────────────────────────────────

const fieldPersonUid = 'uid';
const fieldPersonName = 'name';
const fieldPersonEmail = 'email';
const fieldPersonRole = 'role';
const fieldPersonOnVacation = 'on_vacation';
const fieldPersonSwapTokens = 'swap_tokens_remaining';
const fieldPersonFcmToken = 'fcm_token';

// ── Flat field names ──────────────────────────────────────────────────────────

const fieldFlatName = 'name';
const fieldFlatAdminUid = 'admin_uid';
const fieldFlatInviteCode = 'invite_code';
const fieldFlatVacationThreshold = 'vacation_threshold_weeks';
const fieldFlatGracePeriodHours = 'grace_period_hours';
const fieldFlatReminderHours = 'reminder_hours_before_deadline';
const fieldFlatShoppingCleanupHours = 'shopping_cleanup_hours';
const fieldFlatCreatedAt = 'created_at';

// ── Issue field names ─────────────────────────────────────────────────────────

const fieldIssueTitle = 'title';
const fieldIssueDescription = 'description';
const fieldIssueCreatedBy = 'created_by';
const fieldIssueCreatedAt = 'created_at';
const fieldIssueLastSentAt = 'last_sent_at';

// ── Shopping item field names ─────────────────────────────────────────────────

const fieldShoppingText = 'text';
const fieldShoppingAddedBy = 'added_by';
const fieldShoppingIsBought = 'is_bought';
const fieldShoppingBoughtAt = 'bought_at';
const fieldShoppingOrder = 'order';

// ── Swap request field names ──────────────────────────────────────────────────

const fieldSwapRequesterUid = 'requester_uid';
const fieldSwapTargetTaskId = 'target_task_id';
const fieldSwapRequesterTaskId = 'requester_task_id';
const fieldSwapStatus = 'status';
const fieldSwapCreatedAt = 'created_at';

// ── Livit email ───────────────────────────────────────────────────────────────

const livitEmailAddress = 'studentvillage@ch.issworld.com';
const livitEmailSubject = 'Mängelmeldung für die Wohnung HWB 33';
const livitFlatReference = 'HWB 33';

// ── UI strings ────────────────────────────────────────────────────────────────

const appTitle = 'FlatOrg';
const tabTasks = 'Tasks';
const tabShoppingList = 'Shopping List';
const tabIssueList = 'Issue List';

const buttonMarkDone = 'Mark as Done';
const buttonRequestSwap = 'Request Swap';
const buttonSwap = 'Swap';
const buttonOnVacation = 'Mark as On Vacation';
const buttonGenerateInviteCode = 'Generate & Copy Invite Code';
const buttonSendToLivit = 'Send to Livit';
const buttonDeselectAll = 'Deselect All';
const buttonUndo = 'Undo';

const labelSwapTokensRemaining = 'Swap Tokens';
const labelWeeksNotCleaned = 'Weeks Uncleaned';
const labelVacationStatus = 'On Vacation';

const errorTooManyAttempts = 'Too many attempts, try again later';
const errorWeakPassword =
    'Password must be at least 6 characters and contain a number';
const errorEmailVerificationRequired =
    'Please verify your email before accessing the app';
const errorInsufficientSwapTokens =
    'You have no swap tokens remaining this semester';
const errorIssueCooldown =
    'This issue was sent recently. Please wait before sending again';

const hintEnterInviteCode = 'Enter invite code';
const hintEnterEmail = 'Email';
const hintEnterPassword = 'Password';
const hintEnterName = 'Your name';
const hintEnterFlatName = 'Flat name';
const hintIssueTitle = 'Issue title';
const hintIssueDescription = 'Describe the issue…';
const hintShoppingItem = 'Add item…';

const headingCreateFlat = 'Create a new flat';
const headingJoinFlat = 'Join an existing flat';
const headingAssignTasks = "Let's assign tasks!";
const headingSettings = 'Settings';

const swapRequestAccepted = 'Swap request accepted';
const swapRequestDeclined = 'Swap request declined';
const swapTokensFormat = '{used}/3 Left';

// ── Navigation ────────────────────────────────────────────────────────────────

const navTasks = 'Tasks';
const navShopping = 'Shopping';
const navIssues = 'Issues';

// ── Login / Auth ──────────────────────────────────────────────────────────────

const headingWelcome = 'Welcome to FlatOrg!';
const labelLogin = 'Login';
const labelRegister = 'Register / Sign Up';
const buttonLogin = 'Login';
const buttonRegister = 'Register';
const buttonForgotPassword = 'Forgot password?';
const buttonResendEmail = 'Resend verification email';
const buttonContinue = 'Continue';
const verifyEmailHeading = 'Verify your email';
const verifyEmailBody =
    'A verification link was sent to your email address. Please check your inbox and tap the link, then come back here.';
const resetLinkSent = 'Password reset link sent — check your inbox.';
const buttonSignOut = 'Sign out';

// ── Entry screen ──────────────────────────────────────────────────────────────

const entrySubtitle = 'Do you want to:';
const buttonCreateFlat = 'Create a new flat';
const buttonJoinFlat = 'Join an existing flat';

// ── Flat setup ────────────────────────────────────────────────────────────────

const hintFlatCode = 'Flat code';
const labelFlatCode = 'Flat code';
const labelYourFlatName = 'Your flat name';
const hintTaskName = 'Task name';
const labelWhatTasks = 'What tasks?';
const buttonAddMore = 'Add more';
const buttonRemoveTask = '−';
const hintSubtasks = 'Subtasks (one per line)';
const hintDueDate = 'Due date & time';
const labelFlatCreated = 'Flat created!';
const labelJoined = 'Joined flat!';
const errorFlatNotFound = 'No flat found with that invite code.';
const errorCreatingFlat = 'Error creating flat. Please try again.';
const errorJoiningFlat = 'Error joining flat. Please try again.';

// ── Tasks screen ──────────────────────────────────────────────────────────────

const welcomePrefix = 'Welcome to ';
const buttonShowMore = 'Show more';
const buttonShowLess = 'Show less';
const labelAssignee = 'Assigned to: ';
const labelDue = 'Due: ';
const labelUnassigned = 'Unassigned';
const labelVacant = 'Vacant';
const buttonCompleteTask = 'Mark as Done';
const buttonVacation = 'Vacation';
const labelNoNotifications = 'No notifications';
const labelNotifications = 'Notifications';

// ── Swap request ──────────────────────────────────────────────────────────────

/// Used in the notification panel. {name} is the requester's name.
const swapRequestMessage = 'wants to swap tasks with you. Do you accept?';
const buttonAccept = 'Yes';
const buttonDecline = 'No';

// ── Confirmation dialogs ──────────────────────────────────────────────────────

const confirmCompleteTitle = 'Complete task?';
const confirmCompleteMessage = 'Mark this task as COMPLETED?';
const confirmCompleteLabel = 'Complete';

const confirmVacationTitle = 'Go on vacation?';
const confirmVacationMessage = 'Mark yourself as ON VACATION for this task?';
const confirmVacationLabel = 'Vacation';

const confirmSwapTitle = 'Request swap?';

/// {tokens} is replaced with e.g. "2/3"
const confirmSwapMessage = '{tokens} tokens remaining. Request this task swap?';

/// Appended to [confirmSwapMessage] when the target task is vacant or the
/// assignee is on vacation — the swap executes immediately with no reply needed.
const confirmSwapImmediateNote =
    'This will happen immediately — no need to wait for the other person to confirm.';

const confirmSwapLabel = 'Request';

const errorNoTaskAssigned =
    "You don't have a task assigned yet and can't request a swap.";

const confirmRemoveTitle = 'Remove member?';

/// {name} is replaced with the member's name.
const confirmRemoveMessage =
    'Are you sure you want to remove {name} from the flat?';
const confirmRemoveLabel = 'Remove';

const confirmLeaveTitle = 'Leave flat?';
const confirmLeaveMessage = 'You will be removed from this flat.';
const confirmLeaveLabel = 'Leave';

const confirmDeleteFlatTitle = 'Delete flat?';
const confirmDeleteFlatMessage =
    'You are the last member. This will permanently delete the flat '
    'and all its data. This cannot be undone.';
const confirmDeleteFlatLabel = 'Delete';

const labelTransferAdminBeforeLeaving = 'Choose a new admin before leaving';
const labelSelectNewAdminToLeave =
    'Select who will manage the flat after you leave:';
const labelLeaveAndTransfer = 'Leave & Transfer';
const snackRemoveMemberError = 'Failed to remove member';

const confirmAdminTitle = 'Transfer admin rights?';

/// {name} is replaced with the selected member's name.
const confirmAdminMessage =
    'You are about to transfer admin rights to {name}. Are you sure?';
const confirmAdminLabel = 'Transfer';

const confirmResolvedTitle = 'Mark as resolved?';
const confirmResolvedMessage =
    'This will permanently DELETE the selected issues. They cannot be recovered.';
const confirmResolvedLabel = 'Resolved';

const confirmSendTitle = 'Send to Livit?';
const confirmSendMessage =
    'Did you write the complaints in German? Did you check the right problems to submit?';
const confirmSendLabel = 'Send';

const buttonCancel = 'Cancel';
const buttonConfirm = 'Confirm';
const buttonGoBack = 'Exit selection';

// ── Shopping screen ───────────────────────────────────────────────────────────

const headingShopping = 'Shopping List';
const buttonAddItem = 'Add Item';

/// {hours} is replaced with the cleanup interval.
const shoppingDisappearsAfter = 'Disappears after {hours}h';

// ── Issues screen ─────────────────────────────────────────────────────────────

const headingIssues = 'Flat Issues';
const buttonAddIssue = 'Add Issue';
const buttonSend = 'Send';
const buttonResolved = 'Resolved';
const buttonSelectAll = 'Select All';
const hintIssueImageOptional = 'Image (optional)';
const labelRecentlySent = 'Recently sent';

// ── Settings screen ───────────────────────────────────────────────────────────

const labelMembers = 'Members';
const labelAdminBadge = 'admin';
const labelEditMembers = 'Edit members';
const labelAdminOnlySettings = 'Admin Settings';
const labelVacationThreshold = 'How many weeks can a task stay uncleaned?';
const labelGracePeriod = 'How long can a person still submit a task as done?';
const labelShoppingCleanup =
    'How long until bought shopping items are auto-deleted?';
const labelReminderHours = 'Reminder for hours before deadline?';
const labelChangeTasks = 'Change Tasks';
const labelTransferAdmin = 'Transfer admin rights';
const buttonGenerateInvite = 'Generate & Copy Invite Code';
const inviteCodeCopied = 'Invite code copied to clipboard!';
const labelUnitWeeks = 'weeks';
const labelUnitHours = 'hours';
const labelUnitMinutes = 'minutes';
const labelUnitDays = 'days';
const labelSelectMember = 'Select a member';
const labelTransferAdminAlone =
    'You are the only member. Add members before transferring admin rights.';
const labelAssignedToTask = 'Assigned to';
const buttonResetDefaults = 'Reset above settings to default';
const confirmResetTitle = 'Reset settings?';
const confirmResetMessage =
    'This will restore all admin settings to their default values.';
const confirmResetLabel = 'Reset';

// ── Next phase trigger ────────────────────────────────────────────────────────

const buttonTriggerNextPhase       = 'Trigger next phase';
const labelNextPhaseGracePeriod    = 'Grace Period';
const labelNextPhaseNewAssignment  = 'New Assignment';

// Grace period (Pending → NotDone)
const confirmGracePeriodTitle      = 'Trigger Grace Period?';
const confirmGracePeriodMessage    =
    'This will mark all pending tasks as overdue (not done), '
    'starting the grace period. This cannot be undone.';
const confirmGracePeriodLabel      = 'Trigger';
const snackGracePeriodSuccess      = 'Grace period started.';
const snackGracePeriodError        = 'Failed to trigger grace period — check the logs.';

// New assignment (full week reset)
const confirmWeekResetTitle     = 'Trigger new assignment?';
const confirmWeekResetMessage   =
    'This will immediately run the full week reset: reassign all tasks, '
    'clear swap history, and update green/red/blue statuses. '
    'This cannot be undone.';
const confirmWeekResetLabel     = 'Reset now';
const snackWeekResetSuccess     = 'Week reset completed successfully.';
const snackWeekResetError       = 'Week reset failed — check the logs.';

// ── Log out ───────────────────────────────────────────────────────────────────

const buttonLogOut = 'Log out';
const confirmLogOutTitle = 'Log out?';
const confirmLogOutMessage = 'You will be signed out of FlatOrg.';
const confirmLogOutLabel = 'Log out';

// ── Generic error ─────────────────────────────────────────────────────────────

const errorGeneric = 'Something went wrong. Please try again.';

// ── Optimistic-action error messages ──────────────────────────────────────────

/// Shown when the complete-task write fails and the optimistic green state is
/// rolled back to the previous card colour.
const errorCompleteTaskFailed = 'Could not mark task as done. Please try again.';

/// Shown when the vacation write fails and the optimistic grayed-out button is
/// rolled back.
const errorVacationFailed = 'Could not update vacation status. Please try again.';

/// Shown when the swap-request write fails after the user confirmed the dialog.
const errorSwapFailed = 'Could not send swap request. Please try again.';
const errorIssueTitleRequired = 'Title is required';
const errorIssueDescRequired = 'Description is required';
const tooltipSendRestricted =
    'Only the person assigned to the Shopping task can send issues to Livit';
const labelMemberNameNotLoaded = 'Not loaded';
