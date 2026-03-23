import { getMessaging } from 'firebase-admin/messaging';
import { Firestore } from 'firebase-admin/firestore';
import { PersonRepository } from '../repository/personRepository';
import {
  NOTIFICATION_TITLE_REMINDER,
  NOTIFICATION_BODY_REMINDER_DAY_BEFORE,
  NOTIFICATION_BODY_REMINDER_HOURS_BEFORE,
  NOTIFICATION_TITLE_TASK_COMPLETED,
  NOTIFICATION_BODY_TASK_COMPLETED,
  NOTIFICATION_TITLE_SWAP_REQUEST,
  NOTIFICATION_BODY_SWAP_REQUEST,
  COLLECTION_FLATS,
  COLLECTION_MEMBERS,
} from '../constants/strings';
import * as logger from 'firebase-functions/logger';

/** Field name for the FCM device token stored on each member document. */
const FIELD_FCM_TOKEN = 'fcm_token';

/**
 * Handles all outbound FCM push notifications.
 * Android: native push via FCM.
 * iOS: notifications appear only in the in-app panel (no APNs key required).
 */
export class NotificationService {
  private readonly personRepo: PersonRepository;

  constructor(private readonly db: Firestore) {
    this.personRepo = new PersonRepository(db);
  }

  /** Retrieves the FCM token for a member, or null if none registered. */
  private async getFcmToken(flatId: string, uid: string): Promise<string | null> {
    const doc = await this.db
      .collection(COLLECTION_FLATS)
      .doc(flatId)
      .collection(COLLECTION_MEMBERS)
      .doc(uid)
      .get();
    return (doc.data()?.[FIELD_FCM_TOKEN] as string) ?? null;
  }

  /** Retrieves FCM tokens for all members that have one registered. */
  private async getAllFcmTokens(flatId: string): Promise<string[]> {
    const members = await this.personRepo.getAllMembers(flatId);
    const tokens: string[] = [];
    for (const member of members) {
      const token = await this.getFcmToken(flatId, member.uid);
      if (token) tokens.push(token);
    }
    return tokens;
  }

  /**
   * Sends a reminder to the assignee 1 day before their task deadline.
   * Includes a prompt to complete the task or mark as on vacation.
   */
  async sendDayBeforeReminder(
    flatId: string,
    assigneeUid: string,
    taskName: string,
  ): Promise<void> {
    const token = await this.getFcmToken(flatId, assigneeUid);
    if (!token) return;

    const body = NOTIFICATION_BODY_REMINDER_DAY_BEFORE.replace('{taskName}', taskName);
    await this.sendToToken(token, NOTIFICATION_TITLE_REMINDER, body);
    logger.info('sendDayBeforeReminder sent', { flatId, assigneeUid, taskName });
  }

  /**
   * Sends a reminder to the assignee X hours before their task deadline.
   */
  async sendHoursBeforeReminder(
    flatId: string,
    assigneeUid: string,
    taskName: string,
    hoursRemaining: number,
  ): Promise<void> {
    const token = await this.getFcmToken(flatId, assigneeUid);
    if (!token) return;

    const body = NOTIFICATION_BODY_REMINDER_HOURS_BEFORE
      .replace('{taskName}', taskName)
      .replace('{hours}', String(hoursRemaining));
    await this.sendToToken(token, NOTIFICATION_TITLE_REMINDER, body);
    logger.info('sendHoursBeforeReminder sent', { flatId, assigneeUid, taskName });
  }

  /**
   * Notifies all flat members that someone completed a task.
   */
  async sendTaskCompletedNotification(
    flatId: string,
    completedByName: string,
    taskName: string,
  ): Promise<void> {
    const tokens = await this.getAllFcmTokens(flatId);
    if (tokens.length === 0) return;

    const body = NOTIFICATION_BODY_TASK_COMPLETED
      .replace('{personName}', completedByName)
      .replace('{taskName}', taskName);

    await this.sendToMultipleTokens(tokens, NOTIFICATION_TITLE_TASK_COMPLETED, body);
    logger.info('sendTaskCompletedNotification sent', { flatId, taskName });
  }

  /**
   * Sends a swap request notification to the target person.
   * The request also appears in the in-app notification panel (all platforms).
   */
  async sendSwapRequestNotification(
    flatId: string,
    targetUid: string,
    requesterName: string,
    tokensRemaining: number,
  ): Promise<void> {
    const token = await this.getFcmToken(flatId, targetUid);
    if (!token) return;

    const body = NOTIFICATION_BODY_SWAP_REQUEST
      .replace('{requesterName}', requesterName)
      .replace('{tokens}', String(tokensRemaining));

    await this.sendToToken(token, NOTIFICATION_TITLE_SWAP_REQUEST, body);
    logger.info('sendSwapRequestNotification sent', { flatId, targetUid });
  }

  /** Sends a notification to a single FCM token. */
  private async sendToToken(token: string, title: string, body: string): Promise<void> {
    try {
      await getMessaging().send({ token, notification: { title, body } });
    } catch (error) {
      // Log but do not throw — notification failure must not abort business logic.
      logger.error('FCM send failed', { token: token.slice(0, 10), error });
    }
  }

  /** Sends a notification to multiple FCM tokens using multicast. */
  private async sendToMultipleTokens(
    tokens: string[],
    title: string,
    body: string,
  ): Promise<void> {
    if (tokens.length === 0) return;
    try {
      await getMessaging().sendEachForMulticast({
        tokens,
        notification: { title, body },
      });
    } catch (error) {
      logger.error('FCM multicast failed', { error });
    }
  }
}
