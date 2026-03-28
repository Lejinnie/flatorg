import { Timestamp } from 'firebase-admin/firestore';
import {
  DEFAULT_GRACE_PERIOD_HOURS,
  DEFAULT_REMINDER_HOURS_BEFORE_DEADLINE,
  DEFAULT_SHOPPING_CLEANUP_HOURS,
  DEFAULT_VACATION_THRESHOLD_WEEKS,
} from '../constants/taskConstants';

/**
 * A shared flat. Stored as a single Firestore document at flats/{flatId}.
 * All admin-configurable settings live here so Cloud Functions can read them at trigger time.
 */
export interface Flat {
  /** Firestore document ID. */
  id: string;
  /** Display name of the flat (e.g. 'HWB 33'). */
  name: string;
  /** Firebase Auth UID of the admin member. */
  admin_uid: string;
  /** Short alphanumeric code used to invite new members out-of-band. */
  invite_code: string;
  /**
   * Weeks-not-cleaned threshold separating short vacation (protected) from
   * long vacation (unprotected) treatment in week_reset().
   * Default: DEFAULT_VACATION_THRESHOLD_WEEKS.
   */
  vacation_threshold_weeks: number;
  /**
   * Hours after the last task due_date_time before week_reset() fires.
   * Default: DEFAULT_GRACE_PERIOD_HOURS.
   */
  grace_period_hours: number;
  /**
   * Hours before a task's deadline to send the second reminder notification.
   * Default: DEFAULT_REMINDER_HOURS_BEFORE_DEADLINE.
   */
  reminder_hours_before_deadline: number;
  /**
   * Hours after a shopping item is marked bought before it is auto-deleted.
   * Default: DEFAULT_SHOPPING_CLEANUP_HOURS.
   */
  shopping_cleanup_hours: number;
  /** When the flat was created. */
  created_at: Timestamp;
}

/** Plain-object representation for Firestore writes (omits id). */
export type FlatData = Omit<Flat, 'id'>;

/** Converts a Firestore document snapshot to a typed Flat. */
export function flatFromFirestore(
  id: string,
  data: FirebaseFirestore.DocumentData,
): Flat {
  return {
    id,
    name: data['name'] ?? '',
    admin_uid: data['admin_uid'] ?? '',
    invite_code: data['invite_code'] ?? '',
    vacation_threshold_weeks: data['vacation_threshold_weeks'] ?? DEFAULT_VACATION_THRESHOLD_WEEKS,
    grace_period_hours: data['grace_period_hours'] ?? DEFAULT_GRACE_PERIOD_HOURS,
    reminder_hours_before_deadline:
      data['reminder_hours_before_deadline'] ?? DEFAULT_REMINDER_HOURS_BEFORE_DEADLINE,
    shopping_cleanup_hours: data['shopping_cleanup_hours'] ?? DEFAULT_SHOPPING_CLEANUP_HOURS,
    created_at: data['created_at'] as Timestamp,
  };
}

/** Converts a Flat to a plain Firestore-compatible object (excludes id). */
export function flatToFirestore(flat: Flat): FlatData {
  return {
    name: flat.name,
    admin_uid: flat.admin_uid,
    invite_code: flat.invite_code,
    vacation_threshold_weeks: flat.vacation_threshold_weeks,
    grace_period_hours: flat.grace_period_hours,
    reminder_hours_before_deadline: flat.reminder_hours_before_deadline,
    shopping_cleanup_hours: flat.shopping_cleanup_hours,
    created_at: flat.created_at,
  };
}
