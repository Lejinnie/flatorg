import 'package:flutter_test/flutter_test.dart';
import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/models/enums/person_role.dart';
import 'package:flatorg/models/person.dart';

void main() {
  group('Person', () {
    late Person person;

    setUp(() {
      person = Person(uid: 'u1', name: 'Alice', email: 'alice@test.com');
    });

    group('constructor', () {
      test('default role is member', () {
        expect(person.role, PersonRole.member);
      });

      test('default onVacation is false', () {
        expect(person.onVacation, false);
      });

      test('default swap tokens is 3', () {
        expect(
          person.swapTokensRemaining,
          Strings.defaultSwapTokensPerSemester,
        );
      });
    });

    group('admin constructor', () {
      test('sets role to admin', () {
        final admin = Person.admin(
          uid: 'a1',
          name: 'Admin',
          email: 'admin@test.com',
        );
        expect(admin.role, PersonRole.admin);
        expect(admin.isAdmin, true);
      });
    });

    group('setVacation', () {
      test('sets onVacation to true', () {
        person.setVacation(true);
        expect(person.onVacation, true);
      });

      test('sets onVacation to false', () {
        person.onVacation = true;
        person.setVacation(false);
        expect(person.onVacation, false);
      });
    });

    group('isAdmin', () {
      test('returns true for admin role', () {
        person.role = PersonRole.admin;
        expect(person.isAdmin, true);
      });

      test('returns false for member role', () {
        expect(person.isAdmin, false);
      });
    });

    group('canSwap', () {
      test('returns true when tokens remain', () {
        expect(person.canSwap, true);
      });

      test('returns false when no tokens remain', () {
        person.swapTokensRemaining = 0;
        expect(person.canSwap, false);
      });
    });

    group('consumeSwapToken', () {
      test('decrements swap token count', () {
        person.consumeSwapToken();
        expect(person.swapTokensRemaining, 2);
      });

      test('can consume all tokens', () {
        person.consumeSwapToken();
        person.consumeSwapToken();
        person.consumeSwapToken();
        expect(person.swapTokensRemaining, 0);
      });

      test('throws StateError when no tokens remain', () {
        person.swapTokensRemaining = 0;
        expect(() => person.consumeSwapToken(), throwsStateError);
      });
    });

    group('resetSwapTokens', () {
      test('resets to default', () {
        person.swapTokensRemaining = 0;
        person.resetSwapTokens();
        expect(
          person.swapTokensRemaining,
          Strings.defaultSwapTokensPerSemester,
        );
      });
    });

    group('Firestore serialization', () {
      test('fromFirestore round-trip preserves all fields', () {
        final data = {
          'uid': 'u1',
          'name': 'Alice',
          'email': 'alice@test.com',
          'role': 'admin',
          'on_vacation': true,
          'swap_tokens_remaining': 2,
        };

        final restored = Person.fromFirestore(data);
        expect(restored.uid, 'u1');
        expect(restored.name, 'Alice');
        expect(restored.email, 'alice@test.com');
        expect(restored.role, PersonRole.admin);
        expect(restored.onVacation, true);
        expect(restored.swapTokensRemaining, 2);
      });

      test('fromFirestore handles missing fields gracefully', () {
        final person = Person.fromFirestore({});
        expect(person.uid, '');
        expect(person.name, '');
        expect(person.email, '');
        expect(person.role, PersonRole.member);
        expect(person.onVacation, false);
        expect(
          person.swapTokensRemaining,
          Strings.defaultSwapTokensPerSemester,
        );
      });

      test('toFirestore produces correct map', () {
        final map = person.toFirestore();
        expect(map['uid'], 'u1');
        expect(map['name'], 'Alice');
        expect(map['email'], 'alice@test.com');
        expect(map['role'], 'member');
        expect(map['on_vacation'], false);
        expect(map['swap_tokens_remaining'], 3);
      });
    });
  });
}
