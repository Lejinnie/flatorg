import * as functions from 'firebase-functions';
import { getFirestore } from 'firebase-admin/firestore';
import { PersonRepository } from '../repository/personRepository';
import { EthSemesterCalendar } from '../services/ethSemesterCalendar';
import { COLLECTION_FLATS } from '../constants/strings';
import { LOG_TOKEN_RESET } from '../constants/strings';
import * as logger from 'firebase-functions/logger';

/**
 * Cloud Function scheduled at the start of each ETH semester.
 * Resets swap_tokens_remaining to SWAP_TOKENS_PER_SEMESTER for every member
 * across all flats.
 *
 * The cron expression approximates semester starts:
 *   - Spring Semester (FS) starts ~ISO week 8 (mid-February)
 *   - Autumn Semester (HS) starts ~ISO week 38 (mid-September)
 *
 * The exact boundary is computed via EthSemesterCalendar.nextSemesterStart().
 * Running the reset slightly early is harmless — tokens are replenished idempotently.
 *
 * Schedule: "0 0 * 2,9 1" — midnight on first Monday of February and September
 */
export const tokenResetScheduled = functions.pubsub
  .schedule('0 0 1 2,9 *')
  .timeZone('Europe/Zurich')
  .onRun(async () => {
    const now = new Date();
    if (!EthSemesterCalendar.isInSemester(now)) {
      logger.info('tokenResetScheduled: not in semester, skipping', { date: now.toISOString() });
      return;
    }

    const db = getFirestore();
    const personRepo = new PersonRepository(db);

    // Iterate all flats
    const flatsSnapshot = await db.collection(COLLECTION_FLATS).get();

    for (const flatDoc of flatsSnapshot.docs) {
      logger.info(LOG_TOKEN_RESET, { flatId: flatDoc.id });
      await personRepo.resetAllSwapTokens(flatDoc.id);
    }
  });

/**
 * HTTP trigger variant for manual testing / admin use.
 * Expects JSON body: { "flatId": "<id>" } to reset a single flat,
 * or empty body to reset all flats.
 */
export const tokenResetHttp = functions.https.onRequest(async (req, res) => {
  const db = getFirestore();
  const personRepo = new PersonRepository(db);

  const flatId = req.body?.flatId as string | undefined;

  try {
    if (flatId) {
      logger.info(LOG_TOKEN_RESET, { flatId });
      await personRepo.resetAllSwapTokens(flatId);
    } else {
      const flatsSnapshot = await db.collection(COLLECTION_FLATS).get();
      for (const flatDoc of flatsSnapshot.docs) {
        logger.info(LOG_TOKEN_RESET, { flatId: flatDoc.id });
        await personRepo.resetAllSwapTokens(flatDoc.id);
      }
    }
    res.status(200).send({ success: true });
  } catch (error) {
    logger.error('tokenResetHttp failed', { error });
    res.status(500).send({ error: 'Internal error' });
  }
});
