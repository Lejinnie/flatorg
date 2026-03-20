import 'package:flutter_test/flutter_test.dart';
import 'package:flatorg/models/enums/task_state.dart';

void main() {
  group('TaskState', () {
    group('toFirestore', () {
      test('pending serializes to "pending"', () {
        expect(TaskState.pending.toFirestore(), 'pending');
      });

      test('completed serializes to "completed"', () {
        expect(TaskState.completed.toFirestore(), 'completed');
      });

      test('notDone serializes to "not_done"', () {
        expect(TaskState.notDone.toFirestore(), 'not_done');
      });

      test('vacant serializes to "vacant"', () {
        expect(TaskState.vacant.toFirestore(), 'vacant');
      });
    });

    group('fromFirestore', () {
      test('parses "pending"', () {
        expect(TaskState.fromFirestore('pending'), TaskState.pending);
      });

      test('parses "completed"', () {
        expect(TaskState.fromFirestore('completed'), TaskState.completed);
      });

      test('parses "not_done"', () {
        expect(TaskState.fromFirestore('not_done'), TaskState.notDone);
      });

      test('parses "vacant"', () {
        expect(TaskState.fromFirestore('vacant'), TaskState.vacant);
      });

      test('null defaults to pending', () {
        expect(TaskState.fromFirestore(null), TaskState.pending);
      });

      test('unknown string defaults to pending', () {
        expect(TaskState.fromFirestore('invalid'), TaskState.pending);
      });
    });
  });
}
