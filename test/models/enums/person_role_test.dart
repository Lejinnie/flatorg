import 'package:flutter_test/flutter_test.dart';
import 'package:flatorg/models/enums/person_role.dart';

void main() {
  group('PersonRole', () {
    group('toFirestore', () {
      test('admin serializes to "admin"', () {
        expect(PersonRole.admin.toFirestore(), 'admin');
      });

      test('member serializes to "member"', () {
        expect(PersonRole.member.toFirestore(), 'member');
      });
    });

    group('fromFirestore', () {
      test('parses "admin"', () {
        expect(PersonRole.fromFirestore('admin'), PersonRole.admin);
      });

      test('parses "member"', () {
        expect(PersonRole.fromFirestore('member'), PersonRole.member);
      });

      test('null defaults to member', () {
        expect(PersonRole.fromFirestore(null), PersonRole.member);
      });

      test('unknown string defaults to member', () {
        expect(PersonRole.fromFirestore('superadmin'), PersonRole.member);
      });
    });
  });
}
