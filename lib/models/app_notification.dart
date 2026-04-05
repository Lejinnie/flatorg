import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/strings.dart';

/// An in-app notification stored at
/// `flats/{flatId}/members/{uid}/notifications/{notifId}`.
///
/// Used on iOS (where native push is unavailable without an APNs key) and as
/// the persistent in-app history on all platforms.  Cloud Functions write these
/// documents; users dismiss them by tapping the Dismiss button in the panel.
///
/// [type] values are one of [notifTypeReminder], [notifTypeGracePeriod], or
/// [notifTypeTaskCompleted] — these must match the Python NOTIF_TYPE_* constants
/// in `functions_python/constants/strings.py`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.taskId,
    required this.createdAt,
  });

  /// Firestore document ID.
  final String id;

  /// One of [notifTypeReminder], [notifTypeGracePeriod], [notifTypeTaskCompleted].
  final String type;

  /// Short heading shown in the notification panel.
  final String title;

  /// Full message shown below the heading.
  final String body;

  /// The related task ID, or empty string when not task-specific.
  final String taskId;

  /// When the Cloud Function wrote this notification.
  final Timestamp createdAt;

  factory AppNotification.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    assert(data != null, 'AppNotification.fromFirestore: document ${doc.id} has no data');
    final d = data!;
    return AppNotification(
      id:        doc.id,
      type:      (d[fieldNotifType]  as String?)  ?? '',
      title:     (d[fieldNotifTitle] as String?)  ?? '',
      body:      (d[fieldNotifBody]  as String?)  ?? '',
      taskId:    (d[fieldNotifTaskId] as String?) ?? '',
      createdAt: (d[fieldNotifCreatedAt] as Timestamp?) ?? Timestamp.now(),
    );
  }
}
