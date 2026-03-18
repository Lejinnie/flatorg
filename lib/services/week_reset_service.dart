/// Service responsible for the weekly task reassignment algorithm.
///
/// This runs as a Cloud Function, triggered X hours (admin-configurable
/// grace period) after the latest due date of any task in the current week.
/// Must execute as an atomic Firestore transaction.
class WeekResetService {
  /// Runs the full weekly reset algorithm for a flat.
  ///
  /// Reads each person's [Task.originalAssignedTo] and [Task.state],
  /// then reassigns all tasks following these steps in order:
  ///
  /// 1. **Blue short vacation** (weeks_not_cleaned ≤ threshold):
  ///    Assigned starting from L1, filling upward (L1 → L2 → L3).
  ///    Among vacation people, harder original tasks get harder slots.
  ///    Their slots are protected — Green people jump over them.
  ///
  /// 2. **Green L3**: Move down to L2. Scan forward in task ring from
  ///    current position for next unassigned L2 slot.
  ///
  /// 3. **Green L2**: Move down to L1. Scan forward in task ring from
  ///    current position for next unassigned L1 slot.
  ///
  /// 4. **Red L3**: Stay at L3. Take same task if free, else another L3.
  ///
  /// 5. **Red L2**: Move up to L3. Take any unassigned L3 slot.
  ///    If all L3 full, stay at current L2 task.
  ///
  /// 6. **Red L1**: Move up to L2. Take any unassigned L2 slot.
  ///    If all L2 full, stay at current L1 task.
  ///
  /// 7. **Green L1**: Fill whatever slots remain (assigned last to avoid
  ///    competing with Red people for harder slots).
  ///
  /// 8. **Blue long vacation** (weeks_not_cleaned > threshold):
  ///    Fill whatever slots remain. Slots are not protected.
  ///
  /// Before running assignment steps, increments [Task.weeksNotCleaned]
  /// on every task whose assignee is on vacation or whose state is vacant.
  ///
  /// Within each step, people are processed in sequential task-ring order
  /// (Toilet → Kitchen → ... → Shopping).
  ///
  /// [flatId] — the Firestore document ID of the flat to reset.
  Future<void> resetForNewWeek(String flatId) async {
    // TODO: implement as atomic Firestore transaction
  }
}
