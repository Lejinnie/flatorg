import { Firestore, Transaction } from 'firebase-admin/firestore';
import { Flat, flatFromFirestore, flatToFirestore } from '../models/flat';
import { COLLECTION_FLATS, ERROR_FLAT_NOT_FOUND } from '../constants/strings';

/**
 * Repository for Flat documents in the top-level 'flats' collection.
 * All Firestore access for flat settings goes through this class (Repository pattern).
 */
export class FlatRepository {
  constructor(private readonly db: Firestore) {}

  /** Fetches a flat by ID, throws if not found. */
  async getFlat(flatId: string): Promise<Flat> {
    const doc = await this.db.collection(COLLECTION_FLATS).doc(flatId).get();
    if (!doc.exists) {
      throw new Error(`${ERROR_FLAT_NOT_FOUND}: ${flatId}`);
    }
    return flatFromFirestore(doc.id, doc.data()!);
  }

  /** Fetches a flat within a transaction. */
  async getFlatInTransaction(flatId: string, transaction: Transaction): Promise<Flat> {
    const doc = await transaction.get(
      this.db.collection(COLLECTION_FLATS).doc(flatId),
    );
    if (!doc.exists) {
      throw new Error(`${ERROR_FLAT_NOT_FOUND}: ${flatId}`);
    }
    return flatFromFirestore(doc.id, doc.data()!);
  }

  /** Creates a new flat document. */
  async createFlat(flatId: string, flat: Flat): Promise<void> {
    await this.db
      .collection(COLLECTION_FLATS)
      .doc(flatId)
      .set(flatToFirestore(flat));
  }

  /** Updates specific admin-configurable settings on a flat. */
  async updateFlatSettings(
    flatId: string,
    updates: Partial<Omit<Flat, 'id' | 'created_at' | 'admin_uid' | 'invite_code'>>,
  ): Promise<void> {
    await this.db.collection(COLLECTION_FLATS).doc(flatId).update(updates);
  }

  /**
   * Looks up a flat by its invite code.
   * Returns null when no matching flat exists.
   */
  async findFlatByInviteCode(inviteCode: string): Promise<Flat | null> {
    const snapshot = await this.db
      .collection(COLLECTION_FLATS)
      .where('invite_code', '==', inviteCode)
      .limit(1)
      .get();

    if (snapshot.empty) {
      return null;
    }
    return flatFromFirestore(snapshot.docs[0].id, snapshot.docs[0].data());
  }
}
