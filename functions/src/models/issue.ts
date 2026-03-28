import { Timestamp } from 'firebase-admin/firestore';

/**
 * An issue to be reported to the landlord (Livit).
 * Stored at flats/{flatId}/issues/{issueId}.
 */
export interface Issue {
  /** Firestore document ID. */
  id: string;
  /** Short summary displayed in the issue list. */
  title: string;
  /** Full description shown in the detail view. */
  description: string;
  /** UID of the member who created this issue. */
  created_by: string;
  /** When the issue was created. */
  created_at: Timestamp;
  /**
   * Timestamp of the most recent send to Livit.
   * Empty string when the issue has never been sent.
   * Used to enforce the 5-day cooldown (ISSUE_SEND_COOLDOWN_DAYS).
   * Stored as a Firestore Timestamp in the DB; null on initial creation.
   */
  last_sent_at: Timestamp | null;
}

/** Plain-object representation for Firestore writes (omits id). */
export type IssueData = Omit<Issue, 'id'>;

/** Converts a Firestore document snapshot to a typed Issue. */
export function issueFromFirestore(
  id: string,
  data: FirebaseFirestore.DocumentData,
): Issue {
  return {
    id,
    title: data['title'] ?? '',
    description: data['description'] ?? '',
    created_by: data['created_by'] ?? '',
    created_at: data['created_at'] as Timestamp,
    last_sent_at: (data['last_sent_at'] as Timestamp) ?? null,
  };
}

/** Converts an Issue to a plain Firestore-compatible object (excludes id). */
export function issueToFirestore(issue: Issue): IssueData {
  return {
    title: issue.title,
    description: issue.description,
    created_by: issue.created_by,
    created_at: issue.created_at,
    last_sent_at: issue.last_sent_at,
  };
}

