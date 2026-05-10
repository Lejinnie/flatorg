import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/strings.dart';
import '../models/app_notification.dart';

/// Repository for per-member in-app notification documents stored at
/// `flats/{flatId}/members/{uid}/notifications/{notifId}`.
///
/// Cloud Functions write these documents when events occur (task completed,
/// deadline reminder, grace period entered).  The Flutter app reads them to
/// populate the notification panel and deletes individual documents when the
/// user taps Dismiss.
class NotificationRepository {
  final FirebaseFirestore _db;

  NotificationRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _notifCollection(
    String flatId,
    String uid,
  ) =>
      _db
          .collection(collectionFlats)
          .doc(flatId)
          .collection(collectionMembers)
          .doc(uid)
          .collection(collectionNotifications);

  /// Returns a live stream of all notifications for [uid], ordered newest-first.
  Stream<List<AppNotification>> watchNotificationsForUser(
    String flatId,
    String uid,
  ) {
    assert(
      flatId.isNotEmpty && uid.isNotEmpty,
      'watchNotificationsForUser: flatId and uid must not be empty. '
      'Got flatId="$flatId" uid="$uid"',
    );
    return _notifCollection(flatId, uid)
        .orderBy(fieldNotifCreatedAt, descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AppNotification.fromFirestore(
                    d as DocumentSnapshot<Map<String, dynamic>>,
                  ))
              .toList(),
        );
  }

  /// Deletes a single notification document — called when the user taps Dismiss.
  Future<void> dismissNotification(
    String flatId,
    String uid,
    String notifId,
  ) async {
    assert(
      flatId.isNotEmpty && uid.isNotEmpty && notifId.isNotEmpty,
      'dismissNotification: flatId, uid, and notifId must not be empty. '
      'Got flatId="$flatId" uid="$uid" notifId="$notifId"',
    );
    await _notifCollection(flatId, uid).doc(notifId).delete();
  }

  /// Writes an in-app notification for [uid].  Used by the Flutter client to
  /// deliver swap outcomes (accepted/rejected/withdrawn) to the other party.
  ///
  /// Cloud Functions write the same shape directly via the Python service for
  /// FCM-paired notifications (reminder, grace_period, week_reset).
  Future<void> writeNotification(
    String flatId,
    String uid, {
    required String type,
    required String title,
    required String body,
    String taskId = '',
  }) async {
    assert(
      flatId.isNotEmpty && uid.isNotEmpty,
      'writeNotification: flatId and uid must not be empty. '
      'Got flatId="$flatId" uid="$uid"',
    );
    await _notifCollection(flatId, uid).add({
      fieldNotifType:      type,
      fieldNotifTitle:     title,
      fieldNotifBody:      body,
      fieldNotifTaskId:    taskId,
      fieldNotifCreatedAt: FieldValue.serverTimestamp(),
    });
  }
}
