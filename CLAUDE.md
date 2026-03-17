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
    - [Complaint List](#complaint-list)
  - [UI/UX](#uiux)
  - [Implementation Details](#implementation-details)
    - [Task class](#task-class)
    - [Person class](#person-class)
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
- Admin invites members by email; members create their own account
- Email verification required on signup before app access is granted
- Password requirements: minimum 6 characters + at least one number (enforced client-side before submission to Firebase)
- Password reset: built-in Firebase reset-link flow, wired up in the UI
- Rate limiting on failed login attempts: handled automatically by Firebase Auth; app must display a clear, user-friendly error message when triggered

### Roles & Permissions

**Admin** (the flat creator; can transfer admin rights to another member):
- Add/remove members from the flat
- Modify tasks (name, description, due date, etc.)
- Read/write all tasks and app settings
- No read/write access to other members' personal data

**Normal Member** (includes admin):
- Mark themselves as on vacation
- Mark their own task as done
- Read/write on the shopping list
- Read/write/send on the complaints list

## Coding & Design Standards

- https://en.wikipedia.org/wiki/Design_Patterns This book is basically your bible. I want you to explore the page and the links inside, and then implement these principles in this project.

- do not use literal strings in code, store them in a seperate file and reference the variables in the file.
- when using themes, try to have a centralized way of controlling it. Refer to the youtube of designing good UI (TODO myself.)
  - E.g. 3 types of font sizes that is centralized in a file to be accessed. Or 3 main colorways that are also accessed that way. 
- Use "speaking" (i.e. self explanatory) names (variables, classes, and methods).
- Use constants (static final variables) instead of "Magic numbers". 
- Use docstrings to explain mehthods/fields when it is not obvious from their naming.
- Use comments to explain why something was coded in a certain way, not to explain how something was coded, or what the code does. 
- use tests for backend and frontend.


## Functionality

### Core Function

We assume there are 9 tasks and 9 people. The Tasks are grouped and also have a sequential ordering.

Toilet-> Kitchen -> Recycling -> Shower -> Floor(A) -> Washing rags -> Bathroom -> Floor(B) -> Shopping

Our tasks are divided into three difficulties, hard (3), medium(2) and easy(1). Each of the groups have one task inside.

- Level 3: Toilet, Shower, Bathroom
- Level 2: Floor(A), Floor(B), Kitchen
- Level 1: Recycling, Washing Rags, Shopping & report to @Livit

We want to reward those that do a task by assigning them a task of lower difficulty and those who don't with a task of higher difficulty. We call those who did their task Green Person, and those who didnt Red Person. (If they are on vacation, they are a Blue Person — handled separately.)

`reset_for_new_week()` runs the following steps in order:

1. **Blue short vacation** (on vacation ≤ X weeks, admin-configurable, default 1 week) — assigned to tasks starting from L1, filling upward if there are more short-vacation people than L1 slots (L1 → L2 → L3). Among vacation people, those who had harder tasks get the harder available slots. Their slots are protected — Green people jump over them.
2. **Green L3** — move down to an L2 task. Take the next unassigned L2 task in sequence. If already taken by a Blue/Green person, jump to the next L2 task. If no L2 slots are free, stay at L3 (no reward, no punishment).
3. **Green L2** — move down to an L1 task. Take the next unassigned L1 task in sequence. If already taken, jump to the next L1 task. If no L1 slots are free, stay at L2 (no reward, no punishment).
4. **Red L3** — stay at L3. Take their same task if unassigned, otherwise take another unassigned L3 task.
5. **Red L2** — move up to L3. Take any unassigned L3 task. If all L3 slots are full, stay at their current L2 task next week.
6. **Red L1** — move up to L2. Take any unassigned L2 task. If all L2 slots are full, stay at their current L1 task next week.
7. **Green L1** — fill whatever slots remain (assigned last to avoid competing with Red people for harder slots).
8. **Blue long vacation** (on vacation > X weeks) — fill whatever slots remain after Green L1. Their slots are not protected and do not block Green people from moving down.

**Why Green L3/L2 before Reds:** guarantees that people who did their task get a lighter task next week. Green L3 targets L2 and Green L2 targets L1 — these never compete with Reds who target L3. Only Green L1 ("anywhere") could interfere, so they are moved to the end.

### Switching Tasks

People can switch tasks 3 times per semester (3 tokens).

They can switch to an unassigned (blue) task, or swap with another person if that person agrees. The swap lasts one week only.

`reset_for_new_week()` always uses the person's **original** task (pre-swap) to determine their green/red status and next week's assignment. The swap has no lasting effect on the rotation schedule.

### Vacation people (blue)

People can mark themselves as being on vacation before `reset_for_new_week()` runs. If they mark vacation after the week has already started, it takes effect the following week — no mid-week recompute.

Vacation people are tracked with a `vacation_weeks` counter that increments each week they remain on vacation.

- **Short vacation** (≤ X weeks, admin-configurable per flat, default 1 week): assigned in step 1 of the algorithm. Slots are protected — Green people skip over them.
- **Long vacation** (> X weeks): assigned last (step 8), after Green L1. Their slots are not protected and Green people can take them, preventing long-term vacation from blocking the reward/punishment mechanism.

Overflow (more vacation people than L1 slots) fills L2, then L3, giving those with originally harder tasks the harder available slots.

A person is back from vacation when they complete their assigned task. `completed_task()` clears `on_vacation` and resets `vacation_weeks` to 0.

### Notifications

All notification triggers run as scheduled/event-driven Cloud Functions. Each task has its own due date/time — notifications are relative to that, not a fixed day of the week.

- **Reminder (1 day before):** sent to the assigned person 1 day before their task's due date/time. Always includes a prompt to either complete the task or mark themselves as on vacation.
- **Reminder (X hours before deadline):** sent X hours before the task's due date/time. X is configurable per flat by admin (default: 1h).
- **Task completed:** sent to everyone in the flat when any task is marked done.

## Further Functionality:

### Shopping list

pretty simple, just a shopping list an another tab

Every person in the flat can add/remove things to the shopping list.

It suffices as a simple text.

user can mark it as done/bought. They will move down the list to a secondary list where it will be grayed out but not yet deleted.

The bought items will be deleted after Xh (configurable per flat by admin; default: 6h).

### Complaint List

This is a list of complaints that we have to livit. Also another tab.

When adding it, peopel need to have a title and a description of the complaint.

after adding it it appears on a list.

The user can select (all of them with a button) or select a few that they want and then there will be a button for them to click with will be a mail button which redirects them to their email directed to studentvillage@ch.issworld.com. 

If possible, it would be great to add some boilerplate code.

To avoid spamming, we enable the send button once a week, reset on sunday after 23:59.

## UI/UX

![image](./wireframe.png)

## Implementation Details

Architecture: state machines with events & handlers. UI listens to Firestore streams via `StreamBuilder` and rebuilds reactively.

### Task class

Each task is a state machine stored as a Firestore document.

**Attributes:**
- `name` — task name
- `description` — list of strings, each representing a subtask or step the assignee should complete
- `due_date_time` — configurable per task by admin
- `assigned_to` — person assigned (user ID)
- `original_assigned_to` — person assigned before any swap (used by `reset_for_new_week()`)
- `state` — enum: `pending | completed | not_done`

**State transitions:**

- **Pending (Yellow):** initial state set by `reset_for_new_week()`. Task not yet done.
  - Own deadline passes → transitions to `not_done` (Red)
  - Person marks done → transitions to `completed` (Green)
- **Completed (Green):** task was done before deadline.
  - Own deadline passes → stays `completed`
  - `reset_for_new_week()` fires → reassigned, returns to `pending`
- **Not Done (Red):** deadline passed without completion. Person is in grace period.
  - Holds until `reset_for_new_week()` fires (X hours after the **last** due date across all tasks this week)
  - `reset_for_new_week()` fires → person is treated as Red for next assignment, task returns to `pending`

**Week reset trigger:** A Cloud Function fires X hours (admin-configurable grace period; default 1h) after the latest due date of any task in the current week. At that point `reset_for_new_week()` runs for all tasks.

**Methods:**

`enter_grace_period()` — triggered by Cloud Function when a task's own deadline passes. Transitions `pending → not_done`. UI updates color from yellow to red.

`reset_for_new_week()` — Cloud Function. Reads each person's `original_assigned_to` task and state, runs the full assignment algorithm (blue → green → red order), writes new `assigned_to` and resets all states to `pending`.
- **Within each step, people are processed in sequential task-ring order** (by their current position in the sequence: Toilet → Kitchen → ... → Shopping). This determines who gets first pick when slots are scarce.
- **`original_assigned_to` is never updated while a person is on vacation.** It only updates at the end of a normal (non-vacation) week, so returning vacation people re-enter the rotation at their correct difficulty level.

`completed_task()` — marks state as `completed`. Also clears the `on_vacation` flag and resets `vacation_weeks` to 0 on the assigned person. Updates `original_assigned_to` to this task only if the person is not on vacation.

`request_change_task()` — fires an event to the target person requesting a task swap. Target person sees a pending request in the notification panel and can accept or decline. On accept: swap `assigned_to` on both tasks (original assignments unchanged). On decline: request is cancelled and shown as declined in the requester's notification tile. Each accepted swap costs one token from the requester's balance.

 

### Person class

Each person maps to a Firebase Auth user and a Firestore document.

**Attributes:**
- `uid` — Firebase Auth user ID (primary key)
- `name` — display name
- `email` — used for login and invitations
- `role` — enum: `admin | member`
- `on_vacation` — bool
- `vacation_weeks` — int, increments each week while `on_vacation` is true; reset to 0 by `completed_task()`
- `swap_tokens_remaining` — int (resets to 3 each semester)

**Identity & permissions** are handled entirely by Firebase Auth + Firestore Security Rules. The app reads the person's `role` field to determine what UI elements and actions are available. No custom auth logic needed.

**Methods:**

`set_vacation(bool)` — sets `on_vacation`. Takes effect on the next `reset_for_new_week()` if set before it fires; otherwise takes effect the week after.

### Login

- Firebase Auth with Email/Password
- Admin invites members by email; they register via the app
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

---

## Open Questions

### Critical

**1. "Unassigned (blue) task" in swapping is undefined**
The doc says people can switch to an "unassigned (blue) task." But the algorithm always assigns all 9 tasks to all 9 people — there are no unassigned tasks. Does this mean a vacation person's slot? Or is this concept obsolete?

**2. Initial bootstrap — first week assignments**
`reset_for_new_week()` reads `original_assigned_to` to compute next week. Who makes the very first assignment before the function has ever run? The admin must manually assign all 9 tasks initially. This flow is undocumented.

**3. Admin invitation flow**
"Admin invites members by email" — Firebase Auth has no built-in invite system. Does the admin enter an email and the person gets a signup link? Does the app enforce which emails are allowed to register? A concrete flow needs to be defined.

**4. Single-flat or multi-flat?**
The doc assumes one flat. Firestore naturally supports multiple flat documents. Is this app scoped to exactly one flat forever, or should the architecture support multiple? This affects the entire Firestore schema.

**5. `reset_for_new_week()` must run as an atomic transaction**
The algorithm reads all 9 people, computes assignments, and writes 9 tasks back. If not wrapped in a Firestore transaction, a crash mid-run or concurrent execution could leave tasks double-assigned or in a partial state.

### Important

**6. "Next L2 task in sequence" — direction not specified**
When a Green L3 person looks for "the next unassigned L2 task in sequence," do they scan forward from their current position in the ring, or always from the beginning? (Simulations assumed forward from current position.)

**7. Complaint send limit — per person or per flat?**
"Enable the send button once a week." If per-flat, one person sending on Monday blocks everyone until Sunday. If per-person, each member gets one send per week independently.

**8. Shopping list — can anyone remove any item?**
"Every person can add/remove things." Can person A remove an item added by person B? No ownership rule is defined.

**9. Swap request — push notification or in-app only?**
The notification list covers reminders and task-completed events. When `request_change_task()` fires, does the target person receive a push notification or does the request only appear in the in-app panel?

**10. Semester token reset — trigger and timing**
`swap_tokens_remaining` resets to 3 "each semester." What defines the semester boundary? A Cloud Function cron? Manually by admin? ETH semesters start mid-February and mid-September — is this hardcoded or admin-configurable?

**11. Flat settings document schema**
Several admin-configurable values are scattered through the doc: vacation threshold (weeks), grace period (hours), reminder hours before deadline, shopping cleanup hours. These need a defined Firestore document structure.

**12. `vacation_weeks` increment timing**
"Increments each week while `on_vacation` is true." Implied to happen inside `reset_for_new_week()`, but never explicitly stated.

**13. Person removed mid-week**
If admin removes a member between `reset_for_new_week()` runs, their task sits assigned to a non-existent user. Is the task reassigned immediately, left pending, or flagged?

### Minor

**14. Complaint list — who can delete a complaint?**
Anyone can add. Can anyone delete? Only the author? Only admin?

**15. Complaint email boilerplate**
Subject line and body template for the email to `studentvillage@ch.issworld.com` are unspecified.

**16. Shopping list — duplicate handling**
If two people add the same item simultaneously, duplicates will appear. Is this acceptable or should the UI warn?
