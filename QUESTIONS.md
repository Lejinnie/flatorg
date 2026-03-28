# UI Implementation Questions

These questions need answers before the UI can be built correctly.

---

## 1. Package additions

To build the UI, I need to add several Flutter packages to `pubspec.yaml`. Which of the following are acceptable?

| Package | Purpose |
|---|---|
| `google_fonts` | "Public Sans" font (from Google Fonts) |
| `shared_preferences` | Persist the user's joined flat ID across app restarts (so they don't have to log in every time) |
| `url_launcher` | Open the email client with a pre-filled `mailto:` link for the Issue → Send to Livit feature |
| `intl` | Format dates/times (due dates on task cards) |
| `go_router` | Declarative navigation/routing between screens |
| `provider` | Lightweight state management for auth state + current flat ID (holds the current user + flat across the widget tree) |

> **Note on `provider`:** The CLAUDE.md says no state management library is needed, and StreamBuilder handles reactive UI. But auth state (current Firebase user) and flat membership (which flat is loaded) must be accessible throughout the whole widget tree. We can manage this with a top-level `InheritedWidget` instead, but `provider` is the standard lightweight wrapper for exactly this use case. Your call.

---

## 2. Color scheme

CLAUDE.md asks for a centralized color scheme with primary, secondary, and base colors, supporting light/dark theme. The wireframes suggest a clean, minimal look.

**Proposed scheme:**

| Variable | Light | Dark | Usage |
|---|---|---|---|
| `primaryColor` | `#3B82F6` (blue) | `#60A5FA` (lighter blue) | Buttons, active nav, vacation (blue theme) |
| `secondaryColor` | `#10B981` (green) | `#34D399` | Completed tasks, positive actions |
| `baseColor` | `#FFFFFF` | `#111827` | Card/page backgrounds |
| `warningColor` | `#EF4444` (red) | `#F87171` | Overdue tasks, destructive actions |
| `pendingColor` | `#F59E0B` (amber) | `#FCD34D` | Pending tasks |
| Gray scale | `#F3F4F6`, `#9CA3AF`, `#374151` | dark equivalents | Surfaces, secondary text, primary text |

Is this color scheme acceptable, or do you want specific colors?

---

## 3. In-app notification panel

The task page has a notification bell that opens a panel. The notifications come from:
- **Swap requests** (stored in `flats/{flatId}/swapRequests`) — require Yes/No action
- **Reminders** (Cloud Function sends FCM push) — informational, need "Dismiss" button

Cloud Functions send FCM push notifications to the device. But the in-app panel needs a data source.

**Options:**
- **Option A:** Read swap requests from Firestore (StreamBuilder) + ignore reminders in the in-app panel (reminders are FCM-only, not stored in Firestore)
- **Option B:** Add a `notifications` subcollection to Firestore (e.g. `flats/{flatId}/members/{uid}/notifications`) that Cloud Functions write to, giving the in-app panel a full list of all notification types including reminders
- **Option C:** Only show pending swap requests in the notification panel (simplest; skip reminders since they're already in the FCM system tray)

What should the in-app notification panel show?

---

## 4. Missing issue/shopping repositories

The `lib/repositories/` folder has `TaskRepository`, `FlatRepository`, and `PersonRepository` but **no `IssueRepository`, `ShoppingRepository`, or `SwapRequestRepository`**. The Cloud Functions (TypeScript) handle the write-heavy logic, but the UI still needs Firestore streams and basic CRUD.

Should I create these 3 missing repositories in `lib/repositories/`?
(They would follow the exact same Repository pattern already in place.)

---

## 5. Email templates

CLAUDE.md says:
> The app randomly selects one of 3 pre-written German-language templates. See `email_templates/issue_template_1.txt`, `email_templates/issue_template_2.txt`, and `email_templates/issue_template_3.txt`.

These files **do not exist yet** in the repository.

Should I:
- **A)** Write the 3 German email templates (landlord complaint templates for HWB 33)?
- **B)** Leave placeholder template strings in a constants file for you to fill in?

---

## 6. Initial task assignment (flat creation step 2)

The flat creation flow has a page 2: "Let's assign tasks!" where the admin assigns 9 people to 9 tasks. But during flat creation, there might not yet be 9 members — only the admin exists at that point (others join via invite code later).

**Which flow should page 2 use?**
- **A)** Admin enters 9 member names manually during creation (names only, not Firebase accounts). Each gets assigned a task. They create their actual accounts later via invite code, and the admin then links them.
- **B)** Skip strict 9-person assignment at creation. Admin creates the flat and assigns themselves, then as each member joins via invite code, the admin assigns them a task from the settings screen.
- **C)** Page 2 shows all 9 task slots and lets admin input names as placeholders. When a real person joins, the admin can map that person to a placeholder.

---

## 7. Swap request: vacation person vs. non-vacation person

CLAUDE.md says:
> "They can switch to a vacation person's slot without asking (the requester's original slot becomes the new vacation slot, and the vacation person is reassigned there). They can also swap with a non-vacation person if that person agrees."

From the task list screen, when a user presses "Request Swap" on another person's task:
- If that person is on vacation: swap happens **immediately** with no confirmation needed from the vacation person
- If that person is not on vacation: sends a swap request notification; the target must accept/decline

Should the UI detect this automatically (check `assignedPerson.onVacation` and skip the request flow), or always go through the notification/accept flow for consistency?

---

## 8. Admin transfer

CLAUDE.md says admin can "transfer admin rights to another member". This isn't in the wireframes. Where should this UI be?
- **A)** In the Settings screen, long-press on a member name (similar to the remove-member flow)
- **B)** A separate "Transfer Admin" button in Settings (only visible to current admin)
- **C)** Skip for now (not shown in wireframes)
