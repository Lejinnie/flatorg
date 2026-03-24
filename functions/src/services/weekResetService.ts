import { Firestore } from 'firebase-admin/firestore';
import { Task, TaskState, effectiveAssignedTo } from '../models/task';
import { Person } from '../models/person';
import { Flat } from '../models/flat';
import { TaskRepository } from '../repository/taskRepository';
import { PersonRepository } from '../repository/personRepository';
import { FlatRepository } from '../repository/flatRepository';
import {
  buildWeekResetContext,
  BlueShortVacationStrategy,
  GreenL3Strategy,
  GreenL2Strategy,
  RedL3Strategy,
  RedL2Strategy,
  RedL1Strategy,
  GreenL1Strategy,
  BlueLongVacationStrategy,
  AssignmentStrategy,
  WeekResetContext,
} from './assignmentStrategy';
import { LOG_WEEK_RESET_COMPLETE, LOG_WEEK_RESET_START } from '../constants/strings';
import * as logger from 'firebase-functions/logger';

/**
 * Orchestrates the weekly task reassignment algorithm (Template Method pattern).
 *
 * week_reset() must run as an atomic Firestore transaction to prevent partial state
 * (e.g. two people assigned to the same task) under concurrent execution or crashes.
 *
 * Step order matches the spec in CLAUDE.md:
 *   1. Blue short vacation (protected slots)
 *   2. Green L3 → L2 (scan forward)
 *   3. Green L2 → L1 (scan forward)
 *   4. Red L3 → stay L3
 *   5. Red L2 → up to L3
 *   6. Red L1 → up to L2
 *   7. Green L1 → fill remaining (shortest ring distance)
 *   8. Blue long vacation → fill remaining (unprotected)
 */
export class WeekResetService {
  private readonly taskRepo: TaskRepository;
  private readonly personRepo: PersonRepository;
  private readonly flatRepo: FlatRepository;

  /** Ordered list of assignment strategies executed each reset cycle. */
  private readonly strategies: AssignmentStrategy[] = [
    new BlueShortVacationStrategy(),
    new GreenL3Strategy(),
    new GreenL2Strategy(),
    new RedL3Strategy(),
    new RedL2Strategy(),
    new RedL1Strategy(),
    new GreenL1Strategy(),
    new BlueLongVacationStrategy(),
  ];

  constructor(db: Firestore) {
    this.taskRepo = new TaskRepository(db);
    this.personRepo = new PersonRepository(db);
    this.flatRepo = new FlatRepository(db);
  }

  /**
   * Runs the full weekly reset for a flat inside a single Firestore transaction.
   *
   * @param flatId - Firestore document ID of the flat.
   */
  async weekReset(flatId: string): Promise<void> {
    logger.info(LOG_WEEK_RESET_START, { flatId });

    const db = (this.taskRepo as unknown as { db: Firestore }).db;

    await db.runTransaction(async (transaction) => {
      // ── Load all data inside the transaction ─────────────────────────────
      const flat = await this.flatRepo.getFlatInTransaction(flatId, transaction);
      const tasks = await this.taskRepo.getAllTasksInTransaction(flatId, transaction);
      const persons = await this.personRepo.getAllMembersInTransaction(flatId, transaction);

      // ── Pre-step: increment weeks_not_cleaned ────────────────────────────
      const updatedTasks = this.incrementWeeksNotCleaned(tasks, persons);

      // ── Build context and run strategies ────────────────────────────────
      const ctx = buildWeekResetContext(
        updatedTasks,
        persons,
        flat.vacation_threshold_weeks,
      );
      for (const strategy of this.strategies) {
        strategy.execute(ctx);
      }

      // ── Write results back ───────────────────────────────────────────────
      this.writeResetResults(flatId, updatedTasks, persons, ctx, transaction);
    });

    logger.info(LOG_WEEK_RESET_COMPLETE, { flatId });
  }

  /**
   * Increments weeks_not_cleaned on every task whose effective assignee is on
   * vacation or whose state is Vacant. Returns a new array with updated tasks.
   * This happens before categorisation so the threshold comparison is current.
   */
  private incrementWeeksNotCleaned(tasks: Task[], persons: Person[]): Task[] {
    const vacationUids = new Set(
      persons.filter((p) => p.on_vacation).map((p) => p.uid),
    );

    return tasks.map((task) => {
      const effectiveUid = effectiveAssignedTo(task);
      const isVacant = task.state === TaskState.Vacant;
      const assigneeOnVacation = effectiveUid !== '' && vacationUids.has(effectiveUid);

      if (isVacant || assigneeOnVacation) {
        return { ...task, weeks_not_cleaned: task.weeks_not_cleaned + 1 };
      }
      return task;
    });
  }

  /**
   * Applies all computed next-week assignments and resets task/person state
   * in the transaction batch.
   *
   * Post-step actions (per spec):
   * - Assign each task to the person in ctx.nextAssignments
   * - Clear original_assigned_to on all tasks
   * - Set all task states to Pending
   * - Clear on_vacation on all persons
   */
  private writeResetResults(
    flatId: string,
    tasks: Task[],
    persons: Person[],
    ctx: WeekResetContext,
    transaction: FirebaseFirestore.Transaction,
  ): void {
    // Build ring_index → task.id map for write operations
    const taskByRingIndex = new Map<number, Task>();
    for (const task of tasks) {
      taskByRingIndex.set(task.ring_index, task);
    }

    // Update each task with its new assignment and reset state
    for (let ringIndex = 0; ringIndex < ctx.nextAssignments.length; ringIndex++) {
      const newAssignee = ctx.nextAssignments[ringIndex];
      const task = taskByRingIndex.get(ringIndex);
      if (!task) continue;

      this.taskRepo.updateTaskInTransaction(
        flatId,
        task.id,
        {
          assigned_to: newAssignee,
          original_assigned_to: '',
          state: TaskState.Pending,
          weeks_not_cleaned: task.weeks_not_cleaned, // already updated in incrementWeeksNotCleaned
        },
        transaction,
      );
    }

    // Clear on_vacation on all persons
    for (const person of persons) {
      this.personRepo.updateMemberInTransaction(
        flatId,
        person.uid,
        { on_vacation: false },
        transaction,
      );
    }
  }

  /**
   * Marks a task as completed. Resets weeks_not_cleaned and clears on_vacation
   * on the assigned person.
   * Does NOT modify original_assigned_to (swap tracking is independent).
   *
   * @param flatId - The flat's Firestore document ID.
   * @param taskId - The task's Firestore document ID.
   */
  async completedTask(flatId: string, taskId: string): Promise<void> {
    const db = (this.taskRepo as unknown as { db: Firestore }).db;

    await db.runTransaction(async (transaction) => {
      const task = await this.taskRepo.getTaskInTransaction(flatId, taskId, transaction);

      this.taskRepo.updateTaskInTransaction(
        flatId,
        taskId,
        { state: TaskState.Completed, weeks_not_cleaned: 0 },
        transaction,
      );

      // Clear vacation status on the assigned person (post-vacation return)
      const uid = effectiveAssignedTo(task);
      if (uid !== '') {
        this.personRepo.updateMemberInTransaction(
          flatId,
          uid,
          { on_vacation: false },
          transaction,
        );
      }
    });
  }

  /**
   * Records a swap request from `requesterUid` targeting `targetTaskId`.
   * Returns the created swap request document ID.
   */
  async requestChangeTask(
    flatId: string,
    requesterUid: string,
    requesterTaskId: string,
    targetTaskId: string,
    db: Firestore,
  ): Promise<string> {
    const { Timestamp } = await import('firebase-admin/firestore');
    const { COLLECTION_FLATS, COLLECTION_SWAP_REQUESTS } = await import('../constants/strings');
    const { SwapRequestStatus } = await import('../models/swapRequest');

    const swapRef = db
      .collection(COLLECTION_FLATS)
      .doc(flatId)
      .collection(COLLECTION_SWAP_REQUESTS)
      .doc();

    await swapRef.set({
      requester_uid: requesterUid,
      requester_task_id: requesterTaskId,
      target_task_id: targetTaskId,
      status: SwapRequestStatus.Pending,
      created_at: Timestamp.now(),
    });

    return swapRef.id;
  }

  /**
   * Accepts a swap request: swaps assigned_to on both tasks and deducts 1 token
   * from the requester.
   *
   * @throws When the request is not in Pending state or the requester has no tokens.
   */
  async acceptSwap(flatId: string, swapRequestId: string, db: Firestore): Promise<void> {
    const { COLLECTION_FLATS, COLLECTION_SWAP_REQUESTS, ERROR_SWAP_NOT_PENDING, ERROR_INSUFFICIENT_SWAP_TOKENS } =
      await import('../constants/strings');
    const { SwapRequestStatus, swapRequestFromFirestore } = await import('../models/swapRequest');

    await db.runTransaction(async (transaction) => {
      const swapRef = db
        .collection(COLLECTION_FLATS)
        .doc(flatId)
        .collection(COLLECTION_SWAP_REQUESTS)
        .doc(swapRequestId);

      const swapDoc = await transaction.get(swapRef);
      const swap = swapRequestFromFirestore(swapDoc.id, swapDoc.data()!);

      if (swap.status !== SwapRequestStatus.Pending) {
        throw new Error(ERROR_SWAP_NOT_PENDING);
      }

      const requester = await this.personRepo.getMember(flatId, swap.requester_uid);
      if (requester.swap_tokens_remaining <= 0) {
        throw new Error(ERROR_INSUFFICIENT_SWAP_TOKENS);
      }

      const requesterTask = await this.taskRepo.getTaskInTransaction(
        flatId,
        swap.requester_task_id,
        transaction,
      );
      const targetTask = await this.taskRepo.getTaskInTransaction(
        flatId,
        swap.target_task_id,
        transaction,
      );

      // Swap assigned_to; original_assigned_to tracks the pre-swap assignment
      this.taskRepo.updateTaskInTransaction(
        flatId,
        swap.requester_task_id,
        {
          assigned_to: targetTask.assigned_to,
          original_assigned_to: requesterTask.assigned_to,
        },
        transaction,
      );
      this.taskRepo.updateTaskInTransaction(
        flatId,
        swap.target_task_id,
        {
          assigned_to: requesterTask.assigned_to,
          original_assigned_to: targetTask.assigned_to,
        },
        transaction,
      );

      // Deduct one token from the requester
      this.personRepo.updateMemberInTransaction(
        flatId,
        swap.requester_uid,
        { swap_tokens_remaining: requester.swap_tokens_remaining - 1 },
        transaction,
      );

      // Mark request as accepted
      transaction.update(swapRef, { status: SwapRequestStatus.Accepted });
    });
  }
}

// ── Exported helper: builds context for testing without Firestore ─────────────

/**
 * Runs the week_reset algorithm on in-memory data without touching Firestore.
 * Used for unit and BDD tests.
 */
export function runWeekResetAlgorithm(
  tasks: Task[],
  persons: Person[],
  flat: Pick<Flat, 'vacation_threshold_weeks'>,
): string[] {
  // Simulate incrementWeeksNotCleaned
  const vacationUids = new Set(
    persons.filter((p) => p.on_vacation).map((p) => p.uid),
  );
  const updatedTasks = tasks.map((task) => {
    const effectiveUid = effectiveAssignedTo(task);
    const isVacant = task.state === TaskState.Vacant;
    const assigneeOnVacation = effectiveUid !== '' && vacationUids.has(effectiveUid);
    if (isVacant || assigneeOnVacation) {
      return { ...task, weeks_not_cleaned: task.weeks_not_cleaned + 1 };
    }
    return task;
  });

  const ctx: WeekResetContext = buildWeekResetContext(
    updatedTasks,
    persons,
    flat.vacation_threshold_weeks,
  );

  const strategies: AssignmentStrategy[] = [
    new BlueShortVacationStrategy(),
    new GreenL3Strategy(),
    new GreenL2Strategy(),
    new RedL3Strategy(),
    new RedL2Strategy(),
    new RedL1Strategy(),
    new GreenL1Strategy(),
    new BlueLongVacationStrategy(),
  ];

  for (const strategy of strategies) {
    strategy.execute(ctx);
  }

  return ctx.nextAssignments;
}
