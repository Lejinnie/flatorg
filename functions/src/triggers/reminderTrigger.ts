import * as functions from 'firebase-functions';
import { getFirestore } from 'firebase-admin/firestore';
import { TaskRepository } from '../repository/taskRepository';
import { FlatRepository } from '../repository/flatRepository';
import { NotificationService } from '../services/notificationService';
import { effectiveAssignedTo } from '../models/task';
import * as logger from 'firebase-functions/logger';

/**
 * HTTP-callable Cloud Function that sends the day-before reminder to a task's assignee.
 *
 * Called by Cloud Scheduler 1 day before each task's due_date_time.
 * Expects: { flatId, taskId }
 */
export const sendDayBeforeReminderCallable = functions.https.onCall(
  async (request) => {
    const { flatId, taskId } = request.data as { flatId?: string; taskId?: string };
    if (!flatId || !taskId) {
      throw new functions.https.HttpsError('invalid-argument', 'flatId and taskId are required');
    }
    await dispatchDayBeforeReminder(flatId, taskId);
    return { success: true };
  },
);

/**
 * HTTP trigger variant for Cloud Scheduler.
 * Expects JSON body: { "flatId": "<id>", "taskId": "<id>" }
 */
export const sendDayBeforeReminderHttp = functions.https.onRequest(async (req, res) => {
  const { flatId, taskId } = req.body as { flatId?: string; taskId?: string };
  if (!flatId || !taskId) {
    res.status(400).send({ error: 'flatId and taskId are required' });
    return;
  }
  try {
    await dispatchDayBeforeReminder(flatId, taskId);
    res.status(200).send({ success: true });
  } catch (error) {
    logger.error('sendDayBeforeReminderHttp failed', { flatId, taskId, error });
    res.status(500).send({ error: 'Internal error' });
  }
});

/**
 * HTTP-callable Cloud Function that sends the X-hours-before reminder.
 *
 * Called by Cloud Scheduler `reminder_hours_before_deadline` hours before each task's due_date_time.
 * Expects: { flatId, taskId }
 */
export const sendHoursBeforeReminderCallable = functions.https.onCall(
  async (request) => {
    const { flatId, taskId } = request.data as { flatId?: string; taskId?: string };
    if (!flatId || !taskId) {
      throw new functions.https.HttpsError('invalid-argument', 'flatId and taskId are required');
    }
    await dispatchHoursBeforeReminder(flatId, taskId);
    return { success: true };
  },
);

/**
 * HTTP trigger variant for Cloud Scheduler.
 */
export const sendHoursBeforeReminderHttp = functions.https.onRequest(async (req, res) => {
  const { flatId, taskId } = req.body as { flatId?: string; taskId?: string };
  if (!flatId || !taskId) {
    res.status(400).send({ error: 'flatId and taskId are required' });
    return;
  }
  try {
    await dispatchHoursBeforeReminder(flatId, taskId);
    res.status(200).send({ success: true });
  } catch (error) {
    logger.error('sendHoursBeforeReminderHttp failed', { flatId, taskId, error });
    res.status(500).send({ error: 'Internal error' });
  }
});

// ── Helpers ───────────────────────────────────────────────────────────────────

async function dispatchDayBeforeReminder(flatId: string, taskId: string): Promise<void> {
  const db = getFirestore();
  const taskRepo = new TaskRepository(db);
  const notificationService = new NotificationService(db);

  const task = await taskRepo.getTask(flatId, taskId);
  const assigneeUid = effectiveAssignedTo(task);
  if (assigneeUid === '') return;

  await notificationService.sendDayBeforeReminder(flatId, assigneeUid, task.name);
}

async function dispatchHoursBeforeReminder(flatId: string, taskId: string): Promise<void> {
  const db = getFirestore();
  const taskRepo = new TaskRepository(db);
  const flatRepo = new FlatRepository(db);
  const notificationService = new NotificationService(db);

  const [task, flat] = await Promise.all([
    taskRepo.getTask(flatId, taskId),
    flatRepo.getFlat(flatId),
  ]);

  const assigneeUid = effectiveAssignedTo(task);
  if (assigneeUid === '') return;

  await notificationService.sendHoursBeforeReminder(
    flatId,
    assigneeUid,
    task.name,
    flat.reminder_hours_before_deadline,
  );
}
