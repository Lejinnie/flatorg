import * as functions from 'firebase-functions';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import {
  COLLECTION_FLATS,
  COLLECTION_SHOPPING_ITEMS,
  LOG_SHOPPING_CLEANUP,
} from '../constants/strings';
import { FlatRepository } from '../repository/flatRepository';
import * as logger from 'firebase-functions/logger';

/** Milliseconds per hour — avoids magic numbers. */
const MS_PER_HOUR = 3_600_000;

/**
 * Periodic Cloud Function that deletes bought shopping items older than
 * the flat's `shopping_cleanup_hours` setting.
 *
 * Runs every hour. Items are only deleted if `is_bought = true` and
 * `bought_at` is older than the configured threshold.
 */
export const shoppingCleanupScheduled = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async () => {
    const db = getFirestore();
    const flatRepo = new FlatRepository(db);
    const flatsSnapshot = await db.collection(COLLECTION_FLATS).get();

    for (const flatDoc of flatsSnapshot.docs) {
      const flat = await flatRepo.getFlat(flatDoc.id);
      await deleteExpiredShoppingItems(flatDoc.id, flat.shopping_cleanup_hours, db);
    }
  });

/**
 * HTTP trigger variant for manual testing.
 * Expects JSON body: { "flatId": "<id>" }
 */
export const shoppingCleanupHttp = functions.https.onRequest(async (req, res) => {
  const flatId = req.body?.flatId as string | undefined;
  if (!flatId) {
    res.status(400).send({ error: 'flatId is required' });
    return;
  }

  const db = getFirestore();
  const flatRepo = new FlatRepository(db);

  try {
    const flat = await flatRepo.getFlat(flatId);
    const deleted = await deleteExpiredShoppingItems(flatId, flat.shopping_cleanup_hours, db);
    res.status(200).send({ success: true, deleted });
  } catch (error) {
    logger.error('shoppingCleanupHttp failed', { flatId, error });
    res.status(500).send({ error: 'Internal error' });
  }
});

/**
 * Deletes all bought shopping items in a flat that were marked bought
 * more than `cleanupHours` ago.
 *
 * @returns The number of items deleted.
 */
async function deleteExpiredShoppingItems(
  flatId: string,
  cleanupHours: number,
  db: FirebaseFirestore.Firestore,
): Promise<number> {
  const cutoffMs = Date.now() - cleanupHours * MS_PER_HOUR;
  const cutoffTimestamp = Timestamp.fromMillis(cutoffMs);

  const snapshot = await db
    .collection(COLLECTION_FLATS)
    .doc(flatId)
    .collection(COLLECTION_SHOPPING_ITEMS)
    .where('is_bought', '==', true)
    .where('bought_at', '<=', cutoffTimestamp)
    .get();

  if (snapshot.empty) return 0;

  const batch = db.batch();
  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
  }
  await batch.commit();

  logger.info(LOG_SHOPPING_CLEANUP, { flatId, deleted: snapshot.size });
  return snapshot.size;
}
