import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/strings.dart';
import '../constants/task_constants.dart';

/// A shared flat. Stored as a single Firestore document at flats/{flatId}.
/// Holds both identity and all admin-configurable settings.
class Flat {
  /// Firestore document ID.
  final String id;

  /// Display name of the flat (e.g. 'HWB 33').
  final String name;

  /// Firebase Auth UID of the admin member.
  final String adminUid;

  /// Short alphanumeric code used to invite new members out-of-band.
  final String inviteCode;

  /// Weeks-not-cleaned threshold separating short vacation (protected)
  /// from long vacation (unprotected) treatment in week_reset().
  final int vacationThresholdWeeks;

  /// Hours after the last task due date before week_reset() fires.
  final int gracePeriodHours;

  /// Hours before a task's deadline to send the second reminder notification.
  final int reminderHoursBeforeDeadline;

  /// Hours after a shopping item is marked bought before it is auto-deleted.
  final int shoppingCleanupHours;

  /// When the flat was created.
  final Timestamp createdAt;

  const Flat({
    required this.id,
    required this.name,
    required this.adminUid,
    required this.inviteCode,
    required this.vacationThresholdWeeks,
    required this.gracePeriodHours,
    required this.reminderHoursBeforeDeadline,
    required this.shoppingCleanupHours,
    required this.createdAt,
  });

  /// Creates a Flat from a Firestore document snapshot.
  factory Flat.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Flat(
      id: doc.id,
      name: (data[fieldFlatName] as String?) ?? '',
      adminUid: (data[fieldFlatAdminUid] as String?) ?? '',
      inviteCode: (data[fieldFlatInviteCode] as String?) ?? '',
      vacationThresholdWeeks:
          (data[fieldFlatVacationThreshold] as int?) ?? defaultVacationThresholdWeeks,
      gracePeriodHours: (data[fieldFlatGracePeriodHours] as int?) ?? defaultGracePeriodHours,
      reminderHoursBeforeDeadline:
          (data[fieldFlatReminderHours] as int?) ?? defaultReminderHoursBeforeDeadline,
      shoppingCleanupHours:
          (data[fieldFlatShoppingCleanupHours] as int?) ?? defaultShoppingCleanupHours,
      createdAt: data[fieldFlatCreatedAt] as Timestamp,
    );
  }

  /// Converts this flat to a Firestore-compatible map (excludes [id]).
  Map<String, dynamic> toFirestore() {
    return {
      fieldFlatName: name,
      fieldFlatAdminUid: adminUid,
      fieldFlatInviteCode: inviteCode,
      fieldFlatVacationThreshold: vacationThresholdWeeks,
      fieldFlatGracePeriodHours: gracePeriodHours,
      fieldFlatReminderHours: reminderHoursBeforeDeadline,
      fieldFlatShoppingCleanupHours: shoppingCleanupHours,
      fieldFlatCreatedAt: createdAt,
    };
  }

  /// Returns a copy of this flat with the specified fields replaced.
  Flat copyWith({
    String? id,
    String? name,
    String? adminUid,
    String? inviteCode,
    int? vacationThresholdWeeks,
    int? gracePeriodHours,
    int? reminderHoursBeforeDeadline,
    int? shoppingCleanupHours,
    Timestamp? createdAt,
  }) {
    return Flat(
      id: id ?? this.id,
      name: name ?? this.name,
      adminUid: adminUid ?? this.adminUid,
      inviteCode: inviteCode ?? this.inviteCode,
      vacationThresholdWeeks: vacationThresholdWeeks ?? this.vacationThresholdWeeks,
      gracePeriodHours: gracePeriodHours ?? this.gracePeriodHours,
      reminderHoursBeforeDeadline: reminderHoursBeforeDeadline ?? this.reminderHoursBeforeDeadline,
      shoppingCleanupHours: shoppingCleanupHours ?? this.shoppingCleanupHours,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
