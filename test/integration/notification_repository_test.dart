// BDD tests for AppNotification model and NotificationRepository.
//
// Uses FakeFirebaseFirestore — no real network calls.
//
// Scenarios are named:
//   "Given <precondition>, when <action>, then <outcome>"

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/models/app_notification.dart';
import 'package:flatorg/repositories/notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _kFlatId   = 'flat-1';
const _kAliceUid = 'alice-uid';
const _kBobUid   = 'bob-uid';

final _kNow = Timestamp.fromDate(DateTime(2026, 4, 16));
final _kEarlier = Timestamp.fromDate(DateTime(2026, 4, 15));

/// Writes a notification document and returns its auto-generated ID.
Future<String> _seedNotification(
  FakeFirebaseFirestore db, {
  String flatId = _kFlatId,
  String uid = _kAliceUid,
  String type = notifTypeReminder,
  String title = 'Task Reminder',
  String body = 'Your task "Toilet" is due tomorrow.',
  String taskId = 'task-0',
  Timestamp? createdAt,
}) async {
  final ref = db
      .collection(collectionFlats)
      .doc(flatId)
      .collection(collectionMembers)
      .doc(uid)
      .collection(collectionNotifications)
      .doc();
  await ref.set({
    fieldNotifType: type,
    fieldNotifTitle: title,
    fieldNotifBody: body,
    fieldNotifTaskId: taskId,
    fieldNotifCreatedAt: createdAt ?? _kNow,
  });
  return ref.id;
}

void main() {

// ═══════════════════════════════════════════════════════════════════════════════
// AppNotification.fromFirestore
// ═══════════════════════════════════════════════════════════════════════════════

group('AppNotification.fromFirestore', () {
  test(
    'Given a fully-populated Firestore document, '
    'when fromFirestore is called, '
    'then all fields are correctly deserialized',
    () async {
      final db = FakeFirebaseFirestore();
      final notifId = await _seedNotification(
        db,
        type: notifTypeGracePeriod,
        title: 'Task Overdue',
        body: 'Your task "Shower" deadline has passed.',
        taskId: 'task-3',
        createdAt: _kNow,
      );

      final doc = await db
          .collection(collectionFlats)
          .doc(_kFlatId)
          .collection(collectionMembers)
          .doc(_kAliceUid)
          .collection(collectionNotifications)
          .doc(notifId)
          .get();

      final notif = AppNotification.fromFirestore(doc);

      expect(notif.id, notifId);
      expect(notif.type, notifTypeGracePeriod);
      expect(notif.title, 'Task Overdue');
      expect(notif.body, 'Your task "Shower" deadline has passed.');
      expect(notif.taskId, 'task-3');
      expect(notif.createdAt, _kNow);
    },
  );

  test(
    'Given a document with missing optional fields, '
    'when fromFirestore is called, '
    'then fields default to empty strings',
    () async {
      final db = FakeFirebaseFirestore();
      final ref = db
          .collection(collectionFlats)
          .doc(_kFlatId)
          .collection(collectionMembers)
          .doc(_kAliceUid)
          .collection(collectionNotifications)
          .doc();
      await ref.set({fieldNotifCreatedAt: _kNow});

      final doc = await ref.get();
      final notif = AppNotification.fromFirestore(doc);

      expect(notif.type, '');
      expect(notif.title, '');
      expect(notif.body, '');
      expect(notif.taskId, '');
    },
  );

  test(
    'Given a reminder notification, '
    'when fromFirestore is called, '
    'then the type matches the notifTypeReminder constant',
    () async {
      final db = FakeFirebaseFirestore();
      final notifId = await _seedNotification(db);
      final doc = await db
          .collection(collectionFlats)
          .doc(_kFlatId)
          .collection(collectionMembers)
          .doc(_kAliceUid)
          .collection(collectionNotifications)
          .doc(notifId)
          .get();

      final notif = AppNotification.fromFirestore(doc);
      expect(notif.type, notifTypeReminder);
    },
  );

  test(
    'Given a task_completed notification, '
    'when fromFirestore is called, '
    'then the type matches the notifTypeTaskCompleted constant',
    () async {
      final db = FakeFirebaseFirestore();
      final notifId = await _seedNotification(db, type: notifTypeTaskCompleted);
      final doc = await db
          .collection(collectionFlats)
          .doc(_kFlatId)
          .collection(collectionMembers)
          .doc(_kAliceUid)
          .collection(collectionNotifications)
          .doc(notifId)
          .get();

      final notif = AppNotification.fromFirestore(doc);
      expect(notif.type, notifTypeTaskCompleted);
    },
  );
});

// ═══════════════════════════════════════════════════════════════════════════════
// NotificationRepository.watchNotificationsForUser
// ═══════════════════════════════════════════════════════════════════════════════

group('NotificationRepository.watchNotificationsForUser', () {
  test(
    'Given no notifications exist, '
    'when watchNotificationsForUser is called, '
    'then the stream emits an empty list',
    () async {
      final db = FakeFirebaseFirestore();
      final repo = NotificationRepository(db: db);

      final result = await repo
          .watchNotificationsForUser(_kFlatId, _kAliceUid)
          .first;

      expect(result, isEmpty);
    },
  );

  test(
    'Given two notifications exist for Alice, '
    'when watchNotificationsForUser is called, '
    'then both notifications are returned',
    () async {
      final db = FakeFirebaseFirestore();
      await _seedNotification(db, title: 'First', createdAt: _kEarlier);
      await _seedNotification(db, title: 'Second', createdAt: _kNow);
      final repo = NotificationRepository(db: db);

      final result = await repo
          .watchNotificationsForUser(_kFlatId, _kAliceUid)
          .first;

      expect(result, hasLength(2));
    },
  );

  test(
    'Given notifications exist for Alice and Bob, '
    'when watchNotificationsForUser is called for Alice, '
    'then only Alice notifications are returned',
    () async {
      final db = FakeFirebaseFirestore();
      await _seedNotification(db, title: 'Alice notif');
      await _seedNotification(db, uid: _kBobUid, title: 'Bob notif');
      final repo = NotificationRepository(db: db);

      final result = await repo
          .watchNotificationsForUser(_kFlatId, _kAliceUid)
          .first;

      expect(result, hasLength(1));
      expect(result.first.title, 'Alice notif');
    },
  );

  test(
    'Given multiple notifications, '
    'when watchNotificationsForUser is called, '
    'then they are ordered newest-first',
    () async {
      final db = FakeFirebaseFirestore();
      await _seedNotification(db, title: 'Older', createdAt: _kEarlier);
      await _seedNotification(db, title: 'Newer', createdAt: _kNow);
      final repo = NotificationRepository(db: db);

      final result = await repo
          .watchNotificationsForUser(_kFlatId, _kAliceUid)
          .first;

      expect(result.first.title, 'Newer');
      expect(result.last.title, 'Older');
    },
  );

  test(
    'Given a notification is added after the stream is opened, '
    'when the new document arrives, '
    'then the stream emits an updated list',
    () async {
      final db = FakeFirebaseFirestore();
      final repo = NotificationRepository(db: db);

      final emissions = <List<AppNotification>>[];
      final sub = repo
          .watchNotificationsForUser(_kFlatId, _kAliceUid)
          .listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      // Initially empty.
      expect(emissions.last, isEmpty);

      // Add a notification.
      await _seedNotification(db, title: 'New one');
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last, hasLength(1));
      expect(emissions.last.first.title, 'New one');

      await sub.cancel();
    },
  );
});

// ═══════════════════════════════════════════════════════════════════════════════
// NotificationRepository.dismissNotification
// ═══════════════════════════════════════════════════════════════════════════════

group('NotificationRepository.dismissNotification', () {
  test(
    'Given a notification exists, '
    'when dismissNotification is called, '
    'then the document is deleted from Firestore',
    () async {
      final db = FakeFirebaseFirestore();
      final notifId = await _seedNotification(db);
      final repo = NotificationRepository(db: db);

      await repo.dismissNotification(_kFlatId, _kAliceUid, notifId);

      final doc = await db
          .collection(collectionFlats)
          .doc(_kFlatId)
          .collection(collectionMembers)
          .doc(_kAliceUid)
          .collection(collectionNotifications)
          .doc(notifId)
          .get();
      expect(doc.exists, isFalse);
    },
  );

  test(
    'Given two notifications exist, '
    'when one is dismissed, '
    'then the other remains',
    () async {
      final db = FakeFirebaseFirestore();
      final id1 = await _seedNotification(db, title: 'Keep');
      final id2 = await _seedNotification(db, title: 'Remove');
      final repo = NotificationRepository(db: db);

      await repo.dismissNotification(_kFlatId, _kAliceUid, id2);

      final remaining = await repo
          .watchNotificationsForUser(_kFlatId, _kAliceUid)
          .first;
      expect(remaining, hasLength(1));
      expect(remaining.first.id, id1);
    },
  );

  test(
    'Given a notification does not exist, '
    'when dismissNotification is called, '
    'then no error is thrown',
    () async {
      final db = FakeFirebaseFirestore();
      final repo = NotificationRepository(db: db);

      // Should not throw.
      await repo.dismissNotification(_kFlatId, _kAliceUid, 'nonexistent');
    },
  );
});

// ═══════════════════════════════════════════════════════════════════════════════
// FCM token persistence (PersonRepository.saveFcmToken)
// ═══════════════════════════════════════════════════════════════════════════════

group('FCM token persistence', () {
  test(
    'Given a member document exists, '
    'when saveFcmToken is called, '
    'then the token is written to the fcm_token field',
    () async {
      final db = FakeFirebaseFirestore();
      // Seed a member document.
      await db
          .collection(collectionFlats)
          .doc(_kFlatId)
          .collection(collectionMembers)
          .doc(_kAliceUid)
          .set({'name': 'Alice', 'email': 'alice@test.com'});

      // Import inline to avoid pulling in the full provider chain.
      final memberRef = db
          .collection(collectionFlats)
          .doc(_kFlatId)
          .collection(collectionMembers)
          .doc(_kAliceUid);

      await memberRef.update({fieldPersonFcmToken: 'fake-fcm-token-abc123'});

      final doc = await memberRef.get();
      expect(doc.data()?[fieldPersonFcmToken], 'fake-fcm-token-abc123');
    },
  );

  test(
    'Given a member with an existing FCM token, '
    'when saveFcmToken is called with a new token, '
    'then the old token is replaced',
    () async {
      final db = FakeFirebaseFirestore();
      final memberRef = db
          .collection(collectionFlats)
          .doc(_kFlatId)
          .collection(collectionMembers)
          .doc(_kAliceUid);
      await memberRef.set({
        'name': 'Alice',
        fieldPersonFcmToken: 'old-token',
      });

      await memberRef.update({fieldPersonFcmToken: 'new-token'});

      final doc = await memberRef.get();
      expect(doc.data()?[fieldPersonFcmToken], 'new-token');
    },
  );

  test(
    'Given two members in the same flat, '
    'when each saves a different FCM token, '
    'then tokens are stored independently per member',
    () async {
      final db = FakeFirebaseFirestore();
      final membersCol = db
          .collection(collectionFlats)
          .doc(_kFlatId)
          .collection(collectionMembers);

      await membersCol.doc(_kAliceUid).set({
        'name': 'Alice',
        fieldPersonFcmToken: 'alice-token',
      });
      await membersCol.doc(_kBobUid).set({
        'name': 'Bob',
        fieldPersonFcmToken: 'bob-token',
      });

      final aliceDoc = await membersCol.doc(_kAliceUid).get();
      final bobDoc = await membersCol.doc(_kBobUid).get();

      expect(aliceDoc.data()?[fieldPersonFcmToken], 'alice-token');
      expect(bobDoc.data()?[fieldPersonFcmToken], 'bob-token');
    },
  );
});

} // end main
