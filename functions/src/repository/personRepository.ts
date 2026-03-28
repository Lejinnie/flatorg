import {
  Firestore,
  Transaction,
  DocumentReference,
} from 'firebase-admin/firestore';
import { Person, personFromFirestore, personToFirestore } from '../models/person';
import {
  COLLECTION_FLATS,
  COLLECTION_MEMBERS,
  ERROR_PERSON_NOT_FOUND,
} from '../constants/strings';
import { SWAP_TOKENS_PER_SEMESTER } from '../constants/taskConstants';

/**
 * Repository for Person documents under flats/{flatId}/members.
 * All Firestore access for members goes through this class (Repository pattern).
 */
export class PersonRepository {
  constructor(private readonly db: Firestore) {}

  /** Returns a Firestore document reference for a specific member. */
  private memberRef(flatId: string, uid: string): DocumentReference {
    return this.db
      .collection(COLLECTION_FLATS)
      .doc(flatId)
      .collection(COLLECTION_MEMBERS)
      .doc(uid);
  }

  /** Fetches all members of a flat. */
  async getAllMembers(flatId: string): Promise<Person[]> {
    const snapshot = await this.db
      .collection(COLLECTION_FLATS)
      .doc(flatId)
      .collection(COLLECTION_MEMBERS)
      .get();

    return snapshot.docs.map((doc) => personFromFirestore(doc.id, doc.data()));
  }

  /** Fetches all members within a transaction. */
  async getAllMembersInTransaction(
    flatId: string,
    transaction: Transaction,
  ): Promise<Person[]> {
    const collectionRef = this.db
      .collection(COLLECTION_FLATS)
      .doc(flatId)
      .collection(COLLECTION_MEMBERS);

    const snapshot = await transaction.get(collectionRef);
    return snapshot.docs.map((doc) => personFromFirestore(doc.id, doc.data()));
  }

  /** Fetches a single member by UID, throws if not found. */
  async getMember(flatId: string, uid: string): Promise<Person> {
    const doc = await this.memberRef(flatId, uid).get();
    if (!doc.exists) {
      throw new Error(`${ERROR_PERSON_NOT_FOUND}: ${uid}`);
    }
    return personFromFirestore(doc.id, doc.data()!);
  }

  /** Updates specific fields on a member document. */
  async updateMember(
    flatId: string,
    uid: string,
    updates: Partial<Omit<Person, 'uid'>>,
  ): Promise<void> {
    await this.memberRef(flatId, uid).update(updates);
  }

  /** Updates specific fields on a member document within a transaction. */
  updateMemberInTransaction(
    flatId: string,
    uid: string,
    updates: Partial<Omit<Person, 'uid'>>,
    transaction: Transaction,
  ): void {
    transaction.update(
      this.memberRef(flatId, uid),
      updates as FirebaseFirestore.UpdateData<Person>,
    );
  }

  /** Creates a new member document. */
  async createMember(flatId: string, person: Person): Promise<void> {
    await this.memberRef(flatId, person.uid).set(personToFirestore(person));
  }

  /**
   * Sets the vacation status for a member.
   * Takes effect on the next week_reset() if set before it fires.
   */
  async setVacation(flatId: string, uid: string, onVacation: boolean): Promise<void> {
    await this.updateMember(flatId, uid, { on_vacation: onVacation });
  }

  /**
   * Resets swap_tokens_remaining to the per-semester limit for all members.
   * Called by the token-reset Cloud Function at each ETH semester start.
   */
  async resetAllSwapTokens(flatId: string): Promise<void> {
    const members = await this.getAllMembers(flatId);
    const batch = this.db.batch();
    for (const member of members) {
      batch.update(this.memberRef(flatId, member.uid), {
        swap_tokens_remaining: SWAP_TOKENS_PER_SEMESTER,
      });
    }
    await batch.commit();
  }
}
