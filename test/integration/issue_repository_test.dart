// BDD integration tests for IssueRepository and the Issue.isOnCooldown model.
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
  Timestamp? lastSentAt,
}) => Issue(
  id: id,
  title: title,
  description: description,
  createdBy: createdBy,
  createdAt: createdAt ?? Timestamp.fromDate(DateTime(2026)),
  lastSentAt: lastSentAt,
);

void main() {

// ── Issue.isOnCooldown (pure model, no Firebase) ──────────────────────────────

group('Issue.isOnCooldown', () {
  test(
    'Given an issue that has never been sent, '
    'when isOnCooldown is read, '
    'then it is false',
    () {
      final issue = _makeIssue();
      expect(issue.isOnCooldown, isFalse);
    },
  );

  test(
    'Given an issue last sent more than 5 days ago, '
    'when isOnCooldown is read, '
    'then it is false',
    () {
      final sentAt = DateTime.now().subtract(const Duration(days: 6));
      final issue = _makeIssue(lastSentAt: Timestamp.fromDate(sentAt));
      expect(issue.isOnCooldown, isFalse);
    },
  );

  test(
    'Given an issue last sent exactly 5 days ago, '
    'when isOnCooldown is read, '
    'then it is false (cooldown has just expired)',
    () {
      // Subtract slightly more than 5 days so the cooldown end is in the past.
      final sentAt = DateTime.now().subtract(const Duration(days: 5, seconds: 1));
      final issue = _makeIssue(lastSentAt: Timestamp.fromDate(sentAt));
      expect(issue.isOnCooldown, isFalse);
    },
  );

  test(
    'Given an issue last sent less than 5 days ago, '
    'when isOnCooldown is read, '
    'then it is true',
    () {
      final sentAt = DateTime.now().subtract(const Duration(days: 3));
      final issue = _makeIssue(lastSentAt: Timestamp.fromDate(sentAt));
      expect(issue.isOnCooldown, isTrue);
    },
  );

  test(
    'Given an issue sent just now, '
    'when isOnCooldown is read, '
    'then it is true',
    () {
      final issue = _makeIssue(lastSentAt: Timestamp.now());
      expect(issue.isOnCooldown, isTrue);
    },
  );
});

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
    'Given a new issue, '
    'when createIssue is called, '
    'then lastSentAt is null (issue has never been sent)',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = IssueRepository(db: db);
      final issue = _makeIssue();

      await repo.createIssue(_kFlatId, issue);

      final doc = await db
          .collection(collectionFlats)
          .doc(_kFlatId)
          .collection(collectionIssues)
          .doc(issue.id)
          .get();

      expect(doc.data()![fieldIssueLastSentAt], isNull);
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

// ── IssueRepository.markIssueAsSent ──────────────────────────────────────────

group('IssueRepository.markIssueAsSent', () {
  test(
    'Given an issue that has never been sent, '
    'when markIssueAsSent is called, '
    'then lastSentAt is set to a recent timestamp',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = IssueRepository(db: db);
      final issue = _makeIssue();

      await repo.createIssue(_kFlatId, issue);

      final before = DateTime.now().subtract(const Duration(seconds: 1));
      await repo.markIssueAsSent(_kFlatId, 'issue-1');
      final after  = DateTime.now().add(const Duration(seconds: 1));

      final doc = await db
          .collection(collectionFlats)
          .doc(_kFlatId)
          .collection(collectionIssues)
          .doc('issue-1')
          .get();

      final sentAt = (doc.data()![fieldIssueLastSentAt] as Timestamp).toDate();
      expect(sentAt.isAfter(before), isTrue);
      expect(sentAt.isBefore(after), isTrue);
    },
  );

  test(
    'Given an issue already sent 10 days ago, '
    'when markIssueAsSent is called again, '
    'then lastSentAt is updated to now and isOnCooldown becomes true',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = IssueRepository(db: db);
      final oldSentAt = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 10)),
      );
      final issue = _makeIssue(lastSentAt: oldSentAt);

      await repo.createIssue(_kFlatId, issue);
      await repo.markIssueAsSent(_kFlatId, 'issue-1');

      final issues = await repo.watchIssues(_kFlatId).first;
      expect(issues.first.isOnCooldown, isTrue);
    },
  );

  test(
    'Given two issues, '
    'when only one is marked as sent, '
    'then only that issue is on cooldown',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = IssueRepository(db: db);

      await repo.createIssue(
        _kFlatId,
        _makeIssue(
          id: 'issue-a',
          title: 'Issue A',
          createdAt: Timestamp.fromDate(DateTime(2026, 1, 2)),
        ),
      );
      await repo.createIssue(
        _kFlatId,
        _makeIssue(
          id: 'issue-b',
          title: 'Issue B',
          createdAt: Timestamp.fromDate(DateTime(2026)),
        ),
      );

      await repo.markIssueAsSent(_kFlatId, 'issue-a');

      final issues = await repo.watchIssues(_kFlatId).first;
      final issueA = issues.firstWhere((i) => i.id == 'issue-a');
      final issueB = issues.firstWhere((i) => i.id == 'issue-b');

      expect(issueA.isOnCooldown, isTrue);
      expect(issueB.isOnCooldown, isFalse);
    },
  );
});

} // end main
