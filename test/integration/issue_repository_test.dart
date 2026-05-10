// BDD integration tests for IssueRepository.
//
// Uses FakeFirebaseFirestore — no real network calls.
//
// Scenarios are named:
//   "Given <precondition>, when <action>, then <outcome>"

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/models/issue.dart';
import 'package:flatorg/repositories/issue_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _kFlatId   = 'flat-1';
const _kAliceUid = 'alice-uid';
const _kBobUid   = 'bob-uid';

/// Builds a minimal [Issue] with sensible defaults.
Issue _makeIssue({
  String id = 'issue-1',
  String title = 'Broken heater',
  String description = 'The heater in the bathroom does not work.',
  String createdBy = _kAliceUid,
  Timestamp? createdAt,
}) => Issue(
  id: id,
  title: title,
  description: description,
  createdBy: createdBy,
  createdAt: createdAt ?? Timestamp.fromDate(DateTime(2026)),
);

void main() {

// ── IssueRepository.watchIssues ──────────────────────────────────────────────

group('IssueRepository.watchIssues', () {
  test(
    'Given no issues exist, '
    'when watchIssues is called, '
    'then the stream emits an empty list',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = IssueRepository(db: db);

      final issues = await repo.watchIssues(_kFlatId).first;
      expect(issues, isEmpty);
    },
  );

  test(
    'Given two issues created at different times, '
    'when watchIssues is called, '
    'then issues are returned newest first',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = IssueRepository(db: db);

      final older = _makeIssue(
        id: 'issue-old',
        title: 'Old issue',
        createdAt: Timestamp.fromDate(DateTime(2026)),
      );
      final newer = _makeIssue(
        id: 'issue-new',
        title: 'New issue',
        createdAt: Timestamp.fromDate(DateTime(2026, 1, 2)),
      );

      await repo.createIssue(_kFlatId, older);
      await repo.createIssue(_kFlatId, newer);

      final issues = await repo.watchIssues(_kFlatId).first;
      expect(issues.first.id, 'issue-new');
      expect(issues.last.id, 'issue-old');
    },
  );
});

// ── IssueRepository.createIssue ──────────────────────────────────────────────

group('IssueRepository.createIssue', () {
  test(
    'Given a new issue, '
    'when createIssue is called, '
    'then the title and description are persisted correctly',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = IssueRepository(db: db);
      final issue = _makeIssue(
        title: 'Leaking tap',
        description: 'The kitchen tap drips constantly.',
      );

      await repo.createIssue(_kFlatId, issue);

      final doc = await db
          .collection(collectionFlats)
          .doc(_kFlatId)
          .collection(collectionIssues)
          .doc('issue-1')
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()![fieldIssueTitle], 'Leaking tap');
      expect(doc.data()![fieldIssueDescription], 'The kitchen tap drips constantly.');
    },
  );

  test(
    'Given a new issue, '
    'when createIssue is called, '
    'then createdBy is persisted correctly',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = IssueRepository(db: db);
      final issue = _makeIssue(createdBy: _kBobUid);

      await repo.createIssue(_kFlatId, issue);

      final doc = await db
          .collection(collectionFlats)
          .doc(_kFlatId)
          .collection(collectionIssues)
          .doc(issue.id)
          .get();

      expect(doc.data()![fieldIssueCreatedBy], _kBobUid);
    },
  );

  test(
    'Given two issues with different IDs, '
    'when both are created, '
    'then both exist independently in Firestore',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = IssueRepository(db: db);

      await repo.createIssue(_kFlatId, _makeIssue(id: 'issue-a', title: 'Issue A'));
      await repo.createIssue(_kFlatId, _makeIssue(id: 'issue-b', title: 'Issue B'));

      final issues = await repo.watchIssues(_kFlatId).first;
      expect(issues, hasLength(2));
    },
  );
});

// ── IssueRepository.deleteIssue ──────────────────────────────────────────────

group('IssueRepository.deleteIssue', () {
  test(
    'Given an existing issue, '
    'when deleteIssue is called, '
    'then the issue is removed from Firestore',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = IssueRepository(db: db);
      final issue = _makeIssue();

      await repo.createIssue(_kFlatId, issue);
      await repo.deleteIssue(_kFlatId, 'issue-1');

      final doc = await db
          .collection(collectionFlats)
          .doc(_kFlatId)
          .collection(collectionIssues)
          .doc('issue-1')
          .get();

      expect(doc.exists, isFalse);
    },
  );

  test(
    'Given two issues, '
    'when one is deleted, '
    'then only the other remains',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = IssueRepository(db: db);

      await repo.createIssue(_kFlatId, _makeIssue(id: 'issue-a', title: 'Issue A'));
      await repo.createIssue(_kFlatId, _makeIssue(id: 'issue-b', title: 'Issue B'));
      await repo.deleteIssue(_kFlatId, 'issue-a');

      final issues = await repo.watchIssues(_kFlatId).first;
      expect(issues, hasLength(1));
      expect(issues.first.id, 'issue-b');
    },
  );
});

} // end main
