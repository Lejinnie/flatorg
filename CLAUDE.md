# FlatOrg 

- [FlatOrg](#flatorg)
  - [Tech Stack](#tech-stack)
    - [Roles \& Permissions](#roles--permissions)
  - [Coding \& Design Standards](#coding--design-standards)
  - [Functionality](#functionality)
    - [Core Function](#core-function)
    - [Switching Tasks](#switching-tasks)
    - [Vacation people (blue)](#vacation-people-blue)
    - [Notifications](#notifications)
  - [Further Functionality:](#further-functionality)
    - [Shopping list](#shopping-list)
    - [Issue List](#issue-list)
  - [UI/UX](#uiux)
  - [Implementation Details](#implementation-details)
    - [Task class](#task-class)
    - [Person class](#person-class)
    - [EthSemesterCalendar class](#ethsemestercalendar-class)
    - [Initial Assignment](#initial-assignment)
    - [Flat document (Firestore schema)](#flat-document-firestore-schema)
    - [App Settings](#app-settings)
    - [Login](#login)
  - [Known Algorithm Tradeoffs](#known-algorithm-tradeoffs)
    - [Red L1 escape when Green L3 fills L2](#red-l1-escape-when-green-l3-fills-l2)


FlatOrg is a Flutter app for scheduling and managing household tasks in a co-living area. Built for a 9-person flat.

## Tech Stack

**Frontend: Flutter**
- Cross-platform (Android primary; iOS supported but push notifications use in-app panel only — no APNs key)
- UI reactivity via `StreamBuilder` + Firestore real-time streams
- Domain state machines use enums (no state management library needed)

**Backend: Firebase (Firestore + Cloud Functions)**
- Firestore for real-time database
- Cloud Functions (Blaze plan) for all scheduled/event triggers: week reset, push notifications, grace period transitions, shopping item cleanup
- Serverless — no dedicated server needed
- Blaze free tier is more than sufficient for 9 users

**Push Notifications: Firebase Cloud Messaging (FCM)**
- Android: native push via `firebase_messaging` package
- iOS: in-app notification panel only (no APNs key required)
- All notification triggers run as Cloud Functions

**Authentication: Firebase Auth with Email/Password**
- Any flat member can generate and copy an invite code from within the app (via a "Generate & Copy Invite Code" button); the member then shares this code out-of-band (e.g. messaging) with new people who enter it during registration
- Email verification required on signup before app access is granted
- Password requirements: minimum 6 characters + at least one number (enforced client-side before submission to Firebase)
- Password reset: built-in Firebase reset-link flow, wired up in the UI
- Rate limiting on failed login attempts: handled automatically by Firebase Auth; app must display a clear, user-friendly error message when triggered

### Roles & Permissions

**Admin** (the flat creator; can transfer admin rights to another member):
- Remove members from the flat
- Modify tasks (name, description, due date, etc.)
- Read/write all tasks and app settings
- No read/write access to other members' personal data

**Normal Member** (includes admin):
- Add members to the flat
- Mark themselves as on vacation
- Mark their own task as done
- Read/write on the shopping list
- Read/write/send on the issue list

## Git & CI

- When pushing to remote, use the `$GH_TOKEN` environment variable for authentication. Set the remote URL to `https://x-access-token:${GH_TOKEN}@github.com/<owner>/<repo>.git` before pushing.

## Coding & Design Standards

- https://en.wikipedia.org/wiki/Design_Patterns This book is basically your bible. I want you to explore the page and the links inside, and then implement these principles in this project.

- do not use literal strings in code, store them in a seperate file and reference the variables in the file.
- when using themes, try to have a centralized way of controlling it. Refer to the youtube of designing good UI (TODO myself.)
  - E.g. 3 types of font sizes that is centralized in a file to be accessed. Or 3 main colorways that are also accessed that way. 
- Use "speaking" (i.e. self explanatory) names (variables, classes, and methods).
- Use constants (static final variables) instead of "Magic numbers". 
- Use docstrings to explain mehthods/fields when it is not obvious from their naming.
- Use comments to explain why something was coded in a certain way, not to explain how something was coded, or what the code does. 
- use smoke tests and BDD Tests for backend and frontend.
- Avoid nullable types where possible: use `String` with `''` (empty string) instead of `String?`, and `int` with `-1` as a sentinel instead of `int?`, wherever it makes sense.


## Functionality

### Core Function

We assume there are 9 tasks and 9 people. The Tasks are grouped and also have a sequential ordering.

Toilet-> Kitchen -> Recycling -> Shower -> Floor(A) -> Washing rags -> Bathroom -> Floor(B) -> Shopping

Our tasks are divided into three difficulties, hard (3), medium(2) and easy(1). Each of the groups have one task inside.

- Level 3: Toilet, Shower, Bathroom
- Level 2: Floor(A), Floor(B), Kitchen
- Level 1: Recycling, Washing Rags, Shopping & report to @Livit

We want to reward those that do a task by assigning them a task of lower difficulty and those who don't with a task of higher difficulty. We call those who did their task Green Person, and those who didnt Red Person. (If they are on vacation, they are a Blue Person — handled separately.)

`week_reset()` runs the following steps in order:

1. **Blue short vacation** (`weeks_not_cleaned ≤ X`, admin-configurable, default 1 week) — assigned to tasks starting from L1, filling upward if there are more short-vacation people than L1 slots (L1 → L2 → L3). Among vacation people, those who had harder tasks get the harder available slots. Their slots are protected — Green people jump over them.
2. **Green L3** — move down to an L2 task. Scan forward from their current position in the task ring to find the next unassigned L2 task. If already taken by a Blue/Green person, continue scanning forward. If no L2 slots are free, stay at L3 (no reward, no punishment).
3. **Green L2** — move down to an L1 task. Scan forward from their current position in the task ring to find the next unassigned L1 task. If already taken, continue scanning forward. If no L1 slots are free, stay at L2 (no reward, no punishment).
4. **Red L3** — stay at L3. Take their same task if unassigned, otherwise take another unassigned L3 task.
5. **Red L2** — move up to L3. Take any unassigned L3 task. If all L3 slots are full, stay at their current L2 task next week.
6. **Red L1** — move up to L2. Take any unassigned L2 task. If all L2 slots are full, stay at their current L1 task next week.
7. **Green L1** — fill whatever slots remain (assigned last to avoid competing with Red people for harder slots).
8. **Blue long vacation** (`weeks_not_cleaned > X`) — fill whatever slots remain after Green L1. Their slots are not protected and do not block Green people from moving down.

**Why Green L3/L2 before Reds:** guarantees that people who did their task get a lighter task next week. Green L3 targets L2 and Green L2 targets L1 — these never compete with Reds who target L3. Only Green L1 ("anywhere") could interfere, so they are moved to the end.

### Switching Tasks

People can switch tasks 3 times per semester (3 tokens).

They can switch to a vacation person's slot without asking (the requester's original slot becomes the new vacation slot, and the vacation person is reassigned there). They can also swap with a non-vacation person if that person agrees. The swap lasts one week only.

`week_reset()` always uses the person's **original** task (pre-swap) to determine their green/red status and next week's assignment. The swap has no lasting effect on the rotation schedule.

### Vacation people (blue)

People can mark themselves as being on vacation before `week_reset()` runs. If they mark vacation after the week has already started, it takes effect the following week — no mid-week recompute.

Vacation status is tracked via the task's `weeks_not_cleaned` counter (see Task class), which increments each week the task goes uncleaned — whether the assignee is on vacation or the task is vacant.

- **Short vacation** (`weeks_not_cleaned ≤ X`, admin-configurable per flat, default 1 week): assigned in step 1 of the algorithm. Slots are protected — Green people skip over them.
- **Long vacation** (`weeks_not_cleaned > X`): assigned last (step 8), after Green L1. Their slots are not protected and Green people can take them, preventing long-term vacation from blocking the reward/punishment mechanism.

Overflow (more vacation people than L1 slots) fills L2, then L3, giving those with originally harder tasks the harder available slots.

A person is back from vacation when they complete their assigned task. `completed_task()` clears `on_vacation` and resets `vacation_weeks` to 0.

### Notifications

All notification triggers run as scheduled/event-driven Cloud Functions. Each task has its own due date/time — notifications are relative to that, not a fixed day of the week.

- **Reminder (1 day before):** sent to the assigned person 1 day before their task's due date/time. Always includes a prompt to either complete the task or mark themselves as on vacation.
- **Reminder (X hours before deadline):** sent X hours before the task's due date/time. X is configurable per flat by admin (default: 1h).
- **Task completed:** sent to everyone in the flat when any task is marked done.
- **Swap request:** when `request_change_task()` fires, the target person receives a push notification (Android) and the request appears in the in-app notification panel (all platforms).

## Further Functionality:

### Shopping list

A simple shared shopping list on a separate tab.

- Any member can add or remove any item (no ownership — person A can remove person B's item).
- Items are plain text.
- A member can mark an item as bought. Bought items move to a greyed-out secondary list at the bottom.
- Bought items are automatically deleted after X hours (configurable per flat by admin; default: 6h) via a Cloud Function.
- Duplicate items are acceptable — no deduplication needed.

### Issue List

A list of issues to be sent to Livit, on a separate tab.

- Any member can add an issue (requires a title and a description).
- Any member can delete any issue (no ownership).
- Members can select individual issues or all at once, then tap a mail button which opens their email client pre-addressed to `studentvillage@ch.issworld.com`.
- Email boilerplate: the app randomly selects one of 3 pre-written German-language templates (to avoid repetitive emails to the landlord). Each template includes a polite greeting, a reference to the flat (HWB 33), and placeholder bullet points that are replaced with the selected issues. All templates share the subject line: **"Mängelmeldung für die Wohnung HWB 33"**. See `email_templates/issue_template_1.txt`, `email_templates/issue_template_2.txt`, and `email_templates/issue_template_3.txt`.
- Only the member currently assigned to the **Shopping** task (which includes "& report to @Livit") can trigger the send.
- To avoid spamming: each issue can only be sent once every 5 days. The cooldown is tracked per issue via a `last_sent_at` timestamp. Issues still on cooldown are visually greyed out and cannot be selected for sending.

## UI/UX

![image](./wireframe.png)

**Navigation:** 3 bottom tabs:
1. **Tasks** — home screen with task cards and inline notifications at top
2. **Shopping List** — shared shopping list
3. **Issue List** — flat issues to report to Livit

**Interaction patterns:**
- Tapping an issue opens a detail view showing the full title and description.
- Long-press on an issue to select it for sending. Multiple issues can be selected this way. A "Deselect all" button clears the selection.
- Swap request confirmation popup shows remaining swap tokens (e.g. "2/3 Left").

## Implementation Details

Architecture: state machines with events & handlers. UI listens to Firestore streams via `StreamBuilder` and rebuilds reactively.

### Task class

Each task is a state machine stored as a Firestore document.

**Attributes:**
- `name` — task name
- `description` — list of strings, each representing a subtask or step the assignee should complete
- `due_date_time` — configurable per task by admin
- `assigned_to` — person assigned (user ID)
- `original_assigned_to` — stores the pre-swap assignment when a task swap occurs; empty string when no swap is active. `week_reset()` uses `effective_assigned_to()` (returns `original_assigned_to` if non-empty, else `assigned_to`) to determine green/red status. Cleared after each weekly reset.
- `state` — enum: `pending | completed | not_done | vacant`
- `weeks_not_cleaned` — int, increments in `week_reset()` whenever the task's assignee is on vacation or the task is vacant; resets to 0 when the task is completed normally. Determines short vs. long vacation treatment (same threshold X as `vacation_weeks` was).

**State transitions:**

- **Pending (Yellow):** initial state set by `week_reset()`. Task not yet done.
  - Own deadline passes → transitions to `not_done` (Red)
  - Person marks done → transitions to `completed` (Green)
- **Completed (Green):** task was done before deadline.
  - Own deadline passes → stays `completed`
  - `week_reset()` fires → reassigned, returns to `pending`
- **Not Done (Red):** deadline passed without completion. Person is in grace period.
  - Holds until `week_reset()` fires (X hours after the **last** due date across all tasks this week)
  - `week_reset()` fires → person is treated as Red for next assignment, task returns to `pending`
- **Vacant:** assigned person was removed by admin mid-week. `assigned_to` is null.
  - Treated identically to a vacation task in `week_reset()`: if `weeks_not_cleaned ≤ X` → assigned in step 1 (protected slot); if `weeks_not_cleaned > X` → assigned in step 8 (unprotected).

**Week reset trigger:** A Cloud Function fires X hours (admin-configurable grace period; default 1h) after the latest due date of any task in the current week. At that point `week_reset()` runs for all tasks.

**Methods:**

`enter_grace_period()` — triggered by Cloud Function when a task's own deadline passes. Transitions `pending → not_done`. UI updates color from yellow to red.

`week_reset()` — Cloud Function. For each person, calls `effective_assigned_to()` to resolve swap-aware assignment, then determines green/red status from that task's state. Runs the full assignment algorithm (blue → green → red order), writes new `assigned_to`, clears `original_assigned_to`, and resets all states to `pending`.
- **Within each step, people are processed in sequential task-ring order** (by their current position in the sequence: Toilet → Kitchen → ... → Shopping). This determines who gets first pick when slots are scarce.
- **Increments `weeks_not_cleaned`** on every task whose assignee is `on_vacation` or whose state is `vacant`, before running the assignment steps.
- **Must run as an atomic Firestore transaction** to prevent partial state (e.g. two people assigned to the same task) in the event of a crash or concurrent execution.

`completed_task()` — marks state as `completed` and resets `weeks_not_cleaned` to 0 on the task. Also clears the `on_vacation` flag on the assigned person. Does not modify `original_assigned_to` (swap tracking is independent of task completion).

`request_change_task()` — fires an event to the target person requesting a task swap. Target person sees a pending request in the notification panel and can accept or decline. On accept: swap `assigned_to` on both tasks (original assignments unchanged). On decline: request is cancelled and shown as declined in the requester's notification tile. Each accepted swap costs one token from the requester's balance.

 

### Person class

Each person maps to a Firebase Auth user and a Firestore document.

**Attributes:**
- `uid` — Firebase Auth user ID (primary key)
- `name` — display name
- `email` — used for login and invitations
- `role` — enum: `admin | member`
- `on_vacation` — bool
- `swap_tokens_remaining` — int (resets to 3 at the start of each ETH semester, computed by `EthSemesterCalendar`)

**Identity & permissions** are handled entirely by Firebase Auth + Firestore Security Rules. The app reads the person's `role` field to determine what UI elements and actions are available. No custom auth logic needed.

**Methods:**

`set_vacation(bool)` — sets `on_vacation`. Takes effect on the next `week_reset()` if set before it fires; otherwise takes effect the week after.

### EthSemesterCalendar class

A pure utility class (no Firebase dependency) that encapsulates ETH semester boundary computation. Used by the token-reset Cloud Function cron and anywhere else semester dates are needed.

**ETH semester schedule:**
- **Autumn Semester (HS):** calendar weeks 38–51 (14 weeks, mid-September to just before Christmas)
- **Spring Semester (FS):** calendar weeks 8–22 (15 weeks, mid-February to late May; includes one Easter week off)

**Methods:**
- `currentSemesterStart(DateTime date)` → returns the start date of the semester containing `date`
- `nextSemesterStart(DateTime date)` → returns the start date of the following semester
- `isInSemester(DateTime date)` → bool, whether the given date falls within an active semester

The token-reset Cloud Function is scheduled as a cron at the start of each semester using `nextSemesterStart()`.

### Initial Assignment

Initial task assignment is integrated into the flat creation flow as page 2 of "Create a new flat."

**Flow:** After the admin fills in flat details and invites members (page 1), page 2 shows "Let's assign tasks!" with all 9 tasks listed in order (Toilet → Kitchen → Recycling → Shower → Floor(A) → Washing Rags → Bathroom → Floor(B) → Shopping). The admin assigns each of the 9 people to a task before the flat is fully set up. This is a one-time setup step — `week_reset()` cannot run until all tasks have an initial assignee.

For members who join later (via invite code), the admin assigns them to a vacant task or the system assigns them to the next available slot.

### Flat document (Firestore schema)

Each flat is a single Firestore document containing both identity and admin-configurable settings.

```
Collection: flats
  └── Document: {flatId}
        ├── name: String                          // flat display name
        ├── admin_uid: String                     // Firebase Auth UID of the admin
        ├── invite_code: String                   // short alphanumeric code for joining
        ├── vacation_threshold_weeks: int          // short vs long vacation cutoff (default: 1)
        ├── grace_period_hours: int                // hours after last due date before reset runs (default: 1)
        ├── reminder_hours_before_deadline: int    // notification timing (default: 1)
        ├── shopping_cleanup_hours: int            // hours before bought items are deleted (default: 6)
        └── created_at: Timestamp
```

All settings are editable by the admin only. Cloud Functions read these values at trigger time.

**Issue documents** are stored in a subcollection under the flat:

```
Collection: flats/{flatId}/issues
  └── Document: {issueId}
        ├── title: String
        ├── description: String
        ├── created_by: String                    // user ID
        ├── created_at: Timestamp
        └── last_sent_at: Timestamp?              // null if never sent; cooldown of 5 days
```

### App Settings

Settings accessible to all members and admin-only settings, consolidated in one place.

**Admin-only settings:**
- `vacation_threshold_weeks` — short vs. long vacation cutoff (default: 1)
- `grace_period_hours` — hours after the last due date before `week_reset()` runs (default: 1)
- `reminder_hours_before_deadline` — how many hours before a task's deadline to send a reminder notification (default: 1)
- `shopping_cleanup_hours` — hours before bought shopping items are auto-deleted (default: 6)
- Task configuration: name, description, and `due_date_time` per task
- Remove members from the flat
- Transfer admin rights to another member

**Normal member settings (available to everyone, including admin):**
- Add members to the flat
- Mark self as on vacation
- Mark own task as done
- Request a task swap (costs 1 token per accepted swap; 3 tokens per semester)

### Login

- Firebase Auth with Email/Password
- **First launch:** user chooses "Create a new flat" or "Join an existing flat"
  - **Create a new flat (2-step flow):**
    - **Page 1:** admin enters flat name, their name, email, password, and optionally the names of initial flatmates (the app generates an invite code the admin can share)
    - **Page 2:** "Let's assign tasks!" — admin assigns each person to one of the 9 tasks before the flat is active (see Initial Assignment)
  - **Join an existing flat:** user enters a flat invite code (shared by any existing member), plus their name, email, and password
- Email verification required before app access is granted
- Password: minimum 6 characters + at least one number, validated client-side
- Password reset: Firebase built-in reset-link email, triggered from the login screen
- Failed login rate limiting: automatic via Firebase Auth; app surfaces a clear error ("Too many attempts, try again later")
- See Roles & Permissions above for what each role can do

---

## Known Algorithm Tradeoffs

### Red L1 escape when Green L3 fills L2

When all 3 L3 people are Green, they move to L2 in step 2 and fill all 3 L2 slots. Red L1 people in step 6 then find no free L2 slots and stay at L1 — escaping punishment for that week.

This is an accepted tradeoff of the priority ordering: Green rewards take precedence over Red punishments. In practice this only occurs when all L3 people do their tasks in the same week that all L1 people fail theirs, which is unlikely. And Red L1 people staying at L1 (the easiest level) is a mild consequence regardless.

