# UI Open Questions

These are things visible in the wireframe but not fully specified, or things implied by CLAUDE.md that the wireframe doesn't show. Each item needs a decision before the screen can be safely implemented.

---

## Tasks Screen (Home)

### Task card color coding
- Does the **whole card** change background color (yellow/green/red/blue), or just a left border stripe, or a colored header band?
- What does a **vacation (blue)** task card look like — same card, just blue tinted?
- What does a **vacant** task card look like (no assignee mid-week)?

### Task card icons — per-card visibility rules
The wireframe shows the first card (Shower) has **both** a ✓ (done) icon and a vacation/person icon, while the other cards only have a ↺ (swap) icon. That implies:
- ✓ and vacation icon are only shown on **your own** task — is that correct?
- Is the ↺ (swap request) shown on **all** tasks, or only on tasks that are not yours?

### Notifications section
- Can there be **multiple** notifications stacked? Or only the most recent one?
- What does a **task completed** notification look like (CLAUDE.md says everyone in the flat gets one)?
- What does a **declined swap** look like — same "XX wants to change tasks" banner but crossed out, or a different style?
- What does a **reminder** notification look like inline (1 day before / X hours before deadline)?
- Is there a way to **dismiss** a notification, or do they auto-clear?

### "Show more" on task cards
- What does the expanded state look like — just more subtasks, or also the full description, due date/time, or admin edit button?
- Does tapping "show more" expand inline or navigate to a detail screen?

### Swap request flow
- The CLAUDE.md mentions the swap popup shows remaining tokens ("2/3 Left"). Is this in the same notification banner (inline Yes/No) or a separate modal?
- After accepting/declining, does the notification tile update in place or disappear?

### Vacation toggle
- Tapping the vacation icon on your own task — is it immediate or does a confirmation popup appear first?
- Can you **un-mark** vacation from the UI, or does vacation stay until you complete the task?

---

## Flat Settings Screen

### Settings access
- Is settings reachable **only** via the ⚙ gear icon on the Tasks home screen header?
- Do non-admin members see the settings screen at all, or just a reduced version?

### Admin-only fields
- The wireframe annotates the ⊖ (remove member) button as "only visible if admin". Which other fields/sections are admin-only vs. visible to everyone?
- Where does **task editing** (name, description, due_date_time per task) live? It is not visible in the wireframe — is it inside Settings, or on the task card itself (e.g., long-press or edit icon for admins)?

### "Mark self as on vacation"
- The wireframe shows a vacation icon on the task card. Is there also a vacation toggle in Settings, or is the task card icon the only entry point?

### Settings fields not shown in wireframe
Confirm these are all in the same Settings screen or clarify where they live:
- `reminder_hours_before_deadline` setting
- Per-task `due_date_time` editing
- "Remove member" per member (shown in wireframe with ⊖)
- "Transfer admin rights" (shown in bottom of settings wireframe)

---

## Shopping List

### Adding items
- The + button is visible but no input field is shown. Does tapping + open an inline text field at the top of the list, a bottom sheet, or a dialog popup?

### Buying items
- How does a member mark an item as bought — tap it, swipe, or a checkbox?
- The wireframe shows a "grayed out" section at the bottom for bought items. Is there a section header (e.g., "Bought") or just visual greying?

---

## Issue List

### Send button visibility
- The wireframe annotation says the Send button is only visible if hold-press is active AND time has passed (not on cooldown). Does the button:
  - Only appear after a long-press (hidden otherwise), or
  - Always visible but greyed out until a valid item is selected?

### Selected issue appearance
- What does a **selected** issue look like — highlighted border, checkbox, background tint?

### "Deselect all" button placement
- Where does the "Deselect all" button appear — in the app bar, floating above the list, or at the bottom?

### Issue image
- The wireframe shows an "Image of problem" placeholder on the issue detail view. Can members attach a photo when creating an issue, or is the image placeholder just decorative/future feature?

---

## Login & Onboarding

### Create new flat — page 1 flatmate invites
- The wireframe shows email fields for "who do you want in your flat?" but CLAUDE.md says members join via invite code. Do these email fields send invite emails (requiring an emailing framework), or are they just for display/pre-populating invite suggestions?
- The wireframe note says "We assume there is one type of flat, tasks given" — does this mean the 9 tasks are always fixed and the admin cannot customise them during creation (only later in settings)?

### Email verification
- CLAUDE.md marks this with `TODO_CLAUDE: does this need emailing framework?` — Firebase Auth's email verification is built-in and does **not** require a separate emailing framework. The app just calls `sendEmailVerification()` on the Firebase user and then polls or re-checks on the next app launch. Confirm this is acceptable.

### Password reset
- Same question as above — Firebase's `sendPasswordResetEmail()` is built-in, no extra framework needed. Confirm.

---

## General / Cross-cutting

### Color palette for task states
The states are described as yellow/green/red/blue but exact hex values or material color tokens are not specified. Should these use standard Material colors (e.g., `Colors.yellow`, `Colors.green`) or a custom palette defined in the theme file?

### Task card "assignee" label
- When **you** are the assignee, does the card say "You" or your name?
- When someone else is the assignee, does it show their display name?

### Admin badge / indicator
- Is there any UI indicator that a member is the admin (e.g., a crown icon next to their name in settings)?

### Swap token display
- Tokens are shown on the swap confirmation popup ("2/3 Left"). Is the token count also visible anywhere passively (e.g., in settings or on the task card)?
