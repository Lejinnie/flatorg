import {
  Firestore,
  Transaction,
  DocumentReference,
} from 'firebase-admin/firestore';
import { Task, TaskState, taskFromFirestore, taskToFirestore } from '../models/task';
import {
  COLLECTION_FLATS,
  COLLECTION_TASKS,
  ERROR_TASK_NOT_FOUND,
} from '../constants/strings';

/**
 * Repository for Task documents under flats/{flatId}/tasks.
 * All Firestore access for tasks goes through this class (Repository pattern).
 */
export class TaskRepository {
  constructor(private readonly db: Firestore) {}

  /** Returns a Firestore document reference for a specific task. */
  private taskRef(flatId: string, taskId: string): DocumentReference {
    return this.db
      .collection(COLLECTION_FLATS)
      .doc(flatId)
      .collection(COLLECTION_TASKS)
      .doc(taskId);
  }

  /** Fetches all tasks for a flat, ordered by ring_index. */
  async getAllTasks(flatId: string): Promise<Task[]> {
    const snapshot = await this.db
      .collection(COLLECTION_FLATS)
      .doc(flatId)
      .collection(COLLECTION_TASKS)
      .orderBy('ring_index')
      .get();

    return snapshot.docs.map((doc) => taskFromFirestore(doc.id, doc.data()));
  }

  /** Fetches all tasks for a flat within a transaction. */
  async getAllTasksInTransaction(
    flatId: string,
    transaction: Transaction,
  ): Promise<Task[]> {
    const collectionRef = this.db
      .collection(COLLECTION_FLATS)
      .doc(flatId)
      .collection(COLLECTION_TASKS)
      .orderBy('ring_index');

    const snapshot = await transaction.get(collectionRef);
    return snapshot.docs.map((doc) => taskFromFirestore(doc.id, doc.data()));
  }

  /** Fetches a single task by ID, throws if not found. */
  async getTask(flatId: string, taskId: string): Promise<Task> {
    const doc = await this.taskRef(flatId, taskId).get();
    if (!doc.exists) {
      throw new Error(`${ERROR_TASK_NOT_FOUND}: ${taskId}`);
    }
    return taskFromFirestore(doc.id, doc.data()!);
  }

  /** Fetches a single task within a transaction. */
  async getTaskInTransaction(
    flatId: string,
    taskId: string,
    transaction: Transaction,
  ): Promise<Task> {
    const doc = await transaction.get(this.taskRef(flatId, taskId));
    if (!doc.exists) {
      throw new Error(`${ERROR_TASK_NOT_FOUND}: ${taskId}`);
    }
    return taskFromFirestore(doc.id, doc.data()!);
  }

  /** Updates specific fields on a task document. */
  async updateTask(
    flatId: string,
    taskId: string,
    updates: Partial<Omit<Task, 'id'>>,
  ): Promise<void> {
    await this.taskRef(flatId, taskId).update(updates);
  }

  /** Updates specific fields on a task document within a transaction. */
  updateTaskInTransaction(
    flatId: string,
    taskId: string,
    updates: Partial<Omit<Task, 'id'>>,
    transaction: Transaction,
  ): void {
    transaction.update(this.taskRef(flatId, taskId), updates as FirebaseFirestore.UpdateData<Task>);
  }

  /** Creates a new task document with a specified ID. */
  async createTask(flatId: string, taskId: string, task: Task): Promise<void> {
    await this.taskRef(flatId, taskId).set(taskToFirestore(task));
  }

  /**
   * Transitions a task from Pending to NotDone (grace period entry).
   * Only acts when the task is still Pending — idempotent if already transitioned.
   */
  async enterGracePeriod(flatId: string, taskId: string): Promise<void> {
    await this.db.runTransaction(async (transaction) => {
      const task = await this.getTaskInTransaction(flatId, taskId, transaction);
      if (task.state !== TaskState.Pending) {
        // Already completed or already in not_done — nothing to do.
        return;
      }
      this.updateTaskInTransaction(
        flatId,
        taskId,
        { state: TaskState.NotDone },
        transaction,
      );
    });
  }
}
