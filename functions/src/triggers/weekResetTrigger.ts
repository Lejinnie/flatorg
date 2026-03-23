import * as functions from 'firebase-functions';
import { getFirestore } from 'firebase-admin/firestore';
import { WeekResetService } from '../services/weekResetService';
import * as logger from 'firebase-functions/logger';

/**
 * HTTP-callable Cloud Function that executes week_reset() for a given flat.
 *
 * Triggered by the grace-period Cloud Scheduler job:
 *   - Fires `grace_period_hours` after the latest task due_date_time in the current week
 *   - The scheduler sets the flatId via the request body
 *
 * In production, only the scheduler (or an admin) should call this.
 * The function is idempotent: re-running after a crash produces the same result
 * because it always reads current Firestore state inside a transaction.
 */
export const weekResetCallable = functions.https.onCall(
  async (request) => {
    const flatId = request.data?.flatId as string | undefined;
    if (!flatId) {
      throw new functions.https.HttpsError('invalid-argument', 'flatId is required');
    }

    const db = getFirestore();
    const service = new WeekResetService(db);
    await service.weekReset(flatId);
    return { success: true };
  },
);

/**
 * HTTP trigger variant used by Cloud Scheduler (which cannot call HTTPS callables directly).
 * Expects a JSON body: { "flatId": "<id>" }
 */
export const weekResetHttp = functions.https.onRequest(async (req, res) => {
  const flatId = req.body?.flatId as string | undefined;
  if (!flatId) {
    res.status(400).send({ error: 'flatId is required' });
    return;
  }

  try {
    const db = getFirestore();
    const service = new WeekResetService(db);
    await service.weekReset(flatId);
    res.status(200).send({ success: true });
  } catch (error) {
    logger.error('weekResetHttp failed', { flatId, error });
    res.status(500).send({ error: 'Internal error' });
  }
});
