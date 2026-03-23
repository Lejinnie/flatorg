import * as functions from 'firebase-functions';
import { getFirestore } from 'firebase-admin/firestore';
import { TaskRepository } from '../repository/taskRepository';
import * as logger from 'firebase-functions/logger';
import { LOG_GRACE_PERIOD_TRANSITION } from '../constants/strings';

/**
 * HTTP-callable Cloud Function that transitions a task from Pending → NotDone.
 *
 * Each task has its own due_date_time. When that timestamp passes, Cloud Scheduler
 * calls this function with { flatId, taskId }. The transition is idempotent —
 * calling it again when the task is already NotDone or Completed is a no-op.
 */
export const enterGracePeriodCallable = functions.https.onCall(
  async (request) => {
    const { flatId, taskId } = request.data as { flatId?: string; taskId?: string };
    if (!flatId || !taskId) {
      throw new functions.https.HttpsError('invalid-argument', 'flatId and taskId are required');
    }

    const db = getFirestore();
    const repo = new TaskRepository(db);
    await repo.enterGracePeriod(flatId, taskId);

    logger.info(LOG_GRACE_PERIOD_TRANSITION, { flatId, taskId });
    return { success: true };
  },
);

/**
 * HTTP trigger variant for Cloud Scheduler.
 * Expects JSON body: { "flatId": "<id>", "taskId": "<id>" }
 */
export const enterGracePeriodHttp = functions.https.onRequest(async (req, res) => {
  const { flatId, taskId } = req.body as { flatId?: string; taskId?: string };
  if (!flatId || !taskId) {
    res.status(400).send({ error: 'flatId and taskId are required' });
    return;
  }

  try {
    const db = getFirestore();
    const repo = new TaskRepository(db);
    await repo.enterGracePeriod(flatId, taskId);
    logger.info(LOG_GRACE_PERIOD_TRANSITION, { flatId, taskId });
    res.status(200).send({ success: true });
  } catch (error) {
    logger.error('enterGracePeriodHttp failed', { flatId, taskId, error });
    res.status(500).send({ error: 'Internal error' });
  }
});
