import 'package:flutter_test/flutter_test.dart';
import 'package:flatorg/models/eth_semester_calendar.dart';

void main() {
  group('EthSemesterCalendar', () {
    group('isInSemester', () {
      test('date in autumn semester (HS) returns true', () {
        // Week 40, 2026 — well within HS (38–51)
        final date = DateTime(2026, 10, 1);
        expect(EthSemesterCalendar.isInSemester(date), true);
      });

      test('date in spring semester (FS) returns true', () {
        // Week 10, 2026 — well within FS (8–22)
        final date = DateTime(2026, 3, 5);
        expect(EthSemesterCalendar.isInSemester(date), true);
      });

      test('date in summer break returns false', () {
        // Week 30, 2026 — between FS end (22) and HS start (38)
        final date = DateTime(2026, 7, 20);
        expect(EthSemesterCalendar.isInSemester(date), false);
      });

      test('date in winter break returns false', () {
        // Week 2, 2026 — between HS end (51) and FS start (8)
        final date = DateTime(2026, 1, 10);
        expect(EthSemesterCalendar.isInSemester(date), false);
      });

      test('first week of HS (week 38) returns true', () {
        // Monday of ISO week 38, 2026 = Sep 14, 2026
        final date = DateTime(2026, 9, 14);
        expect(EthSemesterCalendar.isInSemester(date), true);
      });

      test('last week of HS (week 51) returns true', () {
        // Week 51 = mid-December 2026
        final date = DateTime(2026, 12, 17);
        expect(EthSemesterCalendar.isInSemester(date), true);
      });

      test('first week of FS (week 8) returns true', () {
        // Week 8, 2026 = late February
        final date = DateTime(2026, 2, 19);
        expect(EthSemesterCalendar.isInSemester(date), true);
      });

      test('last week of FS (week 22) returns true', () {
        // Week 22 = late May
        final date = DateTime(2026, 5, 28);
        expect(EthSemesterCalendar.isInSemester(date), true);
      });

      test('week 23 (just after FS) returns false', () {
        final date = DateTime(2026, 6, 4);
        expect(EthSemesterCalendar.isInSemester(date), false);
      });

      test('week 37 (just before HS) returns false', () {
        final date = DateTime(2026, 9, 7);
        expect(EthSemesterCalendar.isInSemester(date), false);
      });
    });

    group('currentSemesterStart', () {
      test('during HS returns HS start of same year', () {
        final date = DateTime(2026, 10, 15);
        final start = EthSemesterCalendar.currentSemesterStart(date);
        // Should be Monday of week 38, 2026
        expect(start.weekday, DateTime.monday);
        expect(start.year, 2026);
        expect(start.month, 9); // September
      });

      test('during FS returns FS start of same year', () {
        final date = DateTime(2026, 3, 20);
        final start = EthSemesterCalendar.currentSemesterStart(date);
        // Should be Monday of week 8, 2026
        expect(start.weekday, DateTime.monday);
        expect(start.year, 2026);
        expect(start.month, 2); // February
      });

      test('during summer break returns most recent FS start', () {
        final date = DateTime(2026, 7, 15);
        final start = EthSemesterCalendar.currentSemesterStart(date);
        // Most recent was FS 2026
        expect(start.weekday, DateTime.monday);
        expect(start.year, 2026);
        expect(start.month, 2);
      });

      test('during winter break (Jan) returns HS start of previous year', () {
        final date = DateTime(2026, 1, 5);
        final start = EthSemesterCalendar.currentSemesterStart(date);
        // Most recent was HS 2025
        expect(start.weekday, DateTime.monday);
        expect(start.year, 2025);
      });
    });

    group('nextSemesterStart', () {
      test('during FS returns HS start of same year', () {
        final date = DateTime(2026, 3, 20);
        final next = EthSemesterCalendar.nextSemesterStart(date);
        // Next is HS 2026 (week 38)
        expect(next.weekday, DateTime.monday);
        expect(next.year, 2026);
        expect(next.month, 9);
      });

      test('during summer break returns HS start of same year', () {
        final date = DateTime(2026, 7, 15);
        final next = EthSemesterCalendar.nextSemesterStart(date);
        expect(next.weekday, DateTime.monday);
        expect(next.year, 2026);
        expect(next.month, 9);
      });

      test('during HS returns FS start of next year', () {
        final date = DateTime(2026, 10, 15);
        final next = EthSemesterCalendar.nextSemesterStart(date);
        // Next is FS 2027 (week 8)
        expect(next.weekday, DateTime.monday);
        expect(next.year, 2027);
        expect(next.month, 2);
      });

      test('during winter break (Jan) returns HS start of same year', () {
        final date = DateTime(2026, 1, 5);
        final next = EthSemesterCalendar.nextSemesterStart(date);
        // Next is HS 2026
        expect(next.weekday, DateTime.monday);
        expect(next.year, 2026);
        expect(next.month, 9);
      });
    });
  });
}
