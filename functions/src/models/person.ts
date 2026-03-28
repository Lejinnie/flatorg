/**
 * Role of a flat member. Controls which UI actions and Firestore writes are permitted.
 */
export enum PersonRole {
  Admin = 'admin',
  Member = 'member',
}

/**
 * A flat member. Maps 1-to-1 with a Firebase Auth user and a Firestore document
 * at flats/{flatId}/members/{uid}.
 */
export interface Person {
  /** Firebase Auth UID — primary key. */
  uid: string;
  /** Display name shown in the app. */
  name: string;
  /** Email used for login and invitations. */
  email: string;
  /** Determines which admin-only actions this person may take. */
  role: PersonRole;
  /**
   * When true, the person is marked as away.
   * Takes effect on the next week_reset() if set before it fires;
   * otherwise takes effect the week after.
   */
  on_vacation: boolean;
  /**
   * Number of task-swap opportunities remaining this semester.
   * Resets to SWAP_TOKENS_PER_SEMESTER at the start of each ETH semester.
   */
  swap_tokens_remaining: number;
}

/** Plain-object representation for Firestore writes. */
export type PersonData = Omit<Person, 'uid'>;

/** Converts a Firestore document snapshot to a typed Person. */
export function personFromFirestore(
  uid: string,
  data: FirebaseFirestore.DocumentData,
): Person {
  return {
    uid,
    name: data['name'] ?? '',
    email: data['email'] ?? '',
    role: (data['role'] as PersonRole) ?? PersonRole.Member,
    on_vacation: data['on_vacation'] ?? false,
    swap_tokens_remaining: data['swap_tokens_remaining'] ?? 0,
  };
}

/** Converts a Person to a plain Firestore-compatible object (excludes uid). */
export function personToFirestore(person: Person): PersonData {
  return {
    name: person.name,
    email: person.email,
    role: person.role,
    on_vacation: person.on_vacation,
    swap_tokens_remaining: person.swap_tokens_remaining,
  };
}
