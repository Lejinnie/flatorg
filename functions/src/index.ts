import * as admin from 'firebase-admin';

// Initialise Firebase Admin SDK once. All functions share this instance.
admin.initializeApp();

// ── Week reset ────────────────────────────────────────────────────────────────
export { weekResetCallable, weekResetHttp } from './triggers/weekResetTrigger';

// ── Grace period (pending → not_done) ────────────────────────────────────────
export { enterGracePeriodCallable, enterGracePeriodHttp } from './triggers/gracePeriodTrigger';

// ── Semester token reset ──────────────────────────────────────────────────────
export { tokenResetScheduled, tokenResetHttp } from './triggers/tokenResetTrigger';

// ── Shopping item cleanup ─────────────────────────────────────────────────────
export { shoppingCleanupScheduled, shoppingCleanupHttp } from './triggers/shoppingCleanupTrigger';

// ── Task reminder notifications ───────────────────────────────────────────────
export {
  sendDayBeforeReminderCallable,
  sendDayBeforeReminderHttp,
  sendHoursBeforeReminderCallable,
  sendHoursBeforeReminderHttp,
} from './triggers/reminderTrigger';
