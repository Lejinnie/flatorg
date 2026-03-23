import 'package:flutter_test/flutter_test.dart';
import 'package:flatorg/constants/string_constants.dart';
import 'package:flatorg/constants/task_constants.dart';
import 'package:flatorg/models/enums/task_state.dart';
import 'package:flatorg/models/person.dart';
import 'package:flatorg/models/task.dart';

void main() {
  group('Task', () {
    late Task task;

    setUp(() {
      task = Task(
        name: StringConstants.taskToilet,
        description: ['Clean bowl', 'Mop floor'],
        dueDateTime: DateTime(2026, 3, 22, 18, 0),
        assignedTo: 'user1',
      );
    });

    group('effectiveAssignedTo', () {
      test('returns assignedTo when no swap is active', () {
        expect(task.effectiveAssignedTo, 'user1');
      });

      test('returns originalAssignedTo when swap is active', () {
        task.originalAssignedTo = 'original_user';
        expect(task.effectiveAssignedTo, 'original_user');
      });

      test('returns assignedTo when originalAssignedTo is empty', () {
        task.originalAssignedTo = '';
        expect(task.effectiveAssignedTo, 'user1');
      });
    });

    group('difficultyLevel', () {
      test('Toilet is L3 (hard)', () {
        expect(task.difficultyLevel, TaskConstants.difficultyLevelHard);
      });

      test('Shower is L3 (hard)', () {
        final t = Task(
          name: StringConstants.taskShower,
          description: [],
          dueDateTime: DateTime(2026, 3, 22),
        );
        expect(t.difficultyLevel, TaskConstants.difficultyLevelHard);
      });

      test('Bathroom is L3 (hard)', () {
        final t = Task(
          name: StringConstants.taskBathroom,
          description: [],
          dueDateTime: DateTime(2026, 3, 22),
        );
        expect(t.difficultyLevel, TaskConstants.difficultyLevelHard);
      });

      test('Kitchen is L2 (medium)', () {
        final t = Task(
          name: StringConstants.taskKitchen,
          description: [],
          dueDateTime: DateTime(2026, 3, 22),
        );
        expect(t.difficultyLevel, TaskConstants.difficultyLevelMedium);
      });

      test('Floor (A) is L2 (medium)', () {
        final t = Task(
          name: StringConstants.taskFloorA,
          description: [],
          dueDateTime: DateTime(2026, 3, 22),
        );
        expect(t.difficultyLevel, TaskConstants.difficultyLevelMedium);
      });

      test('Floor (B) is L2 (medium)', () {
        final t = Task(
          name: StringConstants.taskFloorB,
          description: [],
          dueDateTime: DateTime(2026, 3, 22),
        );
        expect(t.difficultyLevel, TaskConstants.difficultyLevelMedium);
      });

      test('Recycling is L1 (easy)', () {
        final t = Task(
          name: StringConstants.taskRecycling,
          description: [],
          dueDateTime: DateTime(2026, 3, 22),
        );
        expect(t.difficultyLevel, TaskConstants.difficultyLevelEasy);
      });

      test('Washing Rags is L1 (easy)', () {
        final t = Task(
          name: StringConstants.taskWashingRags,
          description: [],
          dueDateTime: DateTime(2026, 3, 22),
        );
        expect(t.difficultyLevel, TaskConstants.difficultyLevelEasy);
      });

      test('Shopping is L1 (easy)', () {
        final t = Task(
          name: StringConstants.taskShopping,
          description: [],
          dueDateTime: DateTime(2026, 3, 22),
        );
        expect(t.difficultyLevel, TaskConstants.difficultyLevelEasy);
      });

      test('unknown task defaults to L1', () {
        final t = Task(
          name: 'Unknown Task',
          description: [],
          dueDateTime: DateTime(2026, 3, 22),
        );
        expect(t.difficultyLevel, TaskConstants.difficultyLevelEasy);
      });
    });

    group('taskRingIndex', () {
      test('returns correct index for each task in ring order', () {
        for (var i = 0; i < TaskConstants.taskRingOrder.length; i++) {
          final t = Task(
            name: TaskConstants.taskRingOrder[i],
            description: [],
            dueDateTime: DateTime(2026, 3, 22),
          );
          expect(t.taskRingIndex, i);
        }
      });

      test('returns -1 for unknown task name', () {
        final t = Task(
          name: 'Not A Task',
          description: [],
          dueDateTime: DateTime(2026, 3, 22),
        );
        expect(t.taskRingIndex, -1);
      });
    });

    group('enterGracePeriod', () {
      test('transitions pending to notDone', () {
        task.enterGracePeriod();
        expect(task.state, TaskState.notDone);
      });

      test('does nothing when already completed', () {
        task.state = TaskState.completed;
        task.enterGracePeriod();
        expect(task.state, TaskState.completed);
      });

      test('does nothing when already notDone', () {
        task.state = TaskState.notDone;
        task.enterGracePeriod();
        expect(task.state, TaskState.notDone);
      });

      test('does nothing when vacant', () {
        task.state = TaskState.vacant;
        task.enterGracePeriod();
        expect(task.state, TaskState.vacant);
      });
    });

    group('completedTask', () {
      test('transitions pending to completed', () {
        final person = Person(uid: 'user1', name: 'Alice', email: 'a@b.c');
        task.completedTask(person);
        expect(task.state, TaskState.completed);
      });

      test('resets weeksNotCleaned to 0', () {
        task.weeksNotCleaned = 5;
        final person = Person(uid: 'user1', name: 'Alice', email: 'a@b.c');
        task.completedTask(person);
        expect(task.weeksNotCleaned, 0);
      });

      test('clears person vacation status', () {
        final person = Person(
          uid: 'user1',
          name: 'Alice',
          email: 'a@b.c',
          onVacation: true,
        );
        task.completedTask(person);
        expect(person.onVacation, false);
      });

      test('throws StateError when not pending', () {
        task.state = TaskState.completed;
        final person = Person(uid: 'user1', name: 'Alice', email: 'a@b.c');
        expect(() => task.completedTask(person), throwsStateError);
      });

      test('throws StateError when notDone', () {
        task.state = TaskState.notDone;
        final person = Person(uid: 'user1', name: 'Alice', email: 'a@b.c');
        expect(() => task.completedTask(person), throwsStateError);
      });
    });

    group('requestChangeTask', () {
      test('throws StateError when no swap tokens', () {
        final requester = Person(
          uid: 'user1',
          name: 'Alice',
          email: 'a@b.c',
          swapTokensRemaining: 0,
        );
        expect(
          () => task.requestChangeTask('user2', requester),
          throwsStateError,
        );
      });

      test('throws UnimplementedError when tokens available', () {
        final requester = Person(
          uid: 'user1',
          name: 'Alice',
          email: 'a@b.c',
        );
        expect(
          () => task.requestChangeTask('user2', requester),
          throwsUnimplementedError,
        );
      });
    });

    group('Firestore serialization', () {
      test('round-trip preserves all fields', () {
        final original = Task(
          name: StringConstants.taskKitchen,
          description: ['Wipe counters', 'Clean sink'],
          dueDateTime: DateTime(2026, 3, 22, 18, 0),
          assignedTo: 'user1',
          originalAssignedTo: 'user2',
          state: TaskState.notDone,
          weeksNotCleaned: 3,
        );

        // toFirestore uses Timestamp which needs Firebase — test fromFirestore
        // with a plain map instead
        final data = {
          'name': StringConstants.taskKitchen,
          'description': ['Wipe counters', 'Clean sink'],
          'due_date_time': DateTime(2026, 3, 22, 18, 0),
          'assigned_to': 'user1',
          'original_assigned_to': 'user2',
          'state': 'not_done',
          'weeks_not_cleaned': 3,
        };

        final restored = Task.fromFirestore(data);
        expect(restored.name, original.name);
        expect(restored.description, original.description);
        expect(restored.assignedTo, original.assignedTo);
        expect(restored.originalAssignedTo, original.originalAssignedTo);
        expect(restored.state, original.state);
        expect(restored.weeksNotCleaned, original.weeksNotCleaned);
      });

      test('fromFirestore handles missing fields gracefully', () {
        final task = Task.fromFirestore({});
        expect(task.name, '');
        expect(task.description, isEmpty);
        expect(task.assignedTo, '');
        expect(task.originalAssignedTo, '');
        expect(task.state, TaskState.pending);
        expect(task.weeksNotCleaned, 0);
      });
    });
  });
}
