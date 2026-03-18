import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/models/enums/person_role.dart';

/// A flat member, mapped to a Firebase Auth user and a Firestore document.
///
/// Identity and permissions are handled by Firebase Auth + Firestore Security
/// Rules. The app reads [role] to determine available UI elements and actions.
class Person {
  /// Firebase Auth user ID (primary key).
  final String uid;

  /// Display name shown in the app.
  final String name;

  /// Email address used for login and invitations.
  final String email;

  /// Role within the flat — determines available actions and UI.
  /// See [PersonRole] for details.
  PersonRole role;

  /// Whether this person is currently marked as on vacation.
  ///
  /// Takes effect on the next [WeekResetService.resetForNewWeek] if set
  /// before it fires; otherwise takes effect the week after.
  bool onVacation;

  /// Number of task-swap tokens remaining this semester.
  ///
  /// Each accepted swap costs one token. Resets to
  /// [Strings.defaultSwapTokensPerSemester] (3) at the start of each
  /// ETH semester, computed by [EthSemesterCalendar].
  int swapTokensRemaining;

  Person({
    required this.uid,
    required this.name,
    required this.email,
    this.role = PersonRole.member,
    this.onVacation = false,
    this.swapTokensRemaining = Strings.defaultSwapTokensPerSemester,
  });

  // ---------------------------------------------------------------------------
  // Methods
  // ---------------------------------------------------------------------------

  /// Sets the vacation status for this person.
  ///
  /// If set before [WeekResetService.resetForNewWeek] fires, the change
  /// takes effect that week. If set after, it takes effect the following week.
  ///
  /// When a person completes their assigned task (via [Task.completedTask]),
  /// their vacation status is automatically cleared — they are considered
  /// "back from vacation."
  ///
  /// [vacation] — `true` to mark as on vacation, `false` to return.
  void setVacation(bool vacation) {
    // TODO: implement
  }

  // ---------------------------------------------------------------------------
  // Firestore serialization
  // ---------------------------------------------------------------------------

  /// Creates a [Person] instance from a Firestore document snapshot.
  ///
  /// [data] — the `Map<String, dynamic>` from `DocumentSnapshot.data()`.
  /// Expects fields matching [Strings] field name constants.
  factory Person.fromFirestore(Map<String, dynamic> data) {
    // TODO: implement deserialization
    return Person(
      uid: data[Strings.fieldUid] as String? ?? '',
      name: data[Strings.fieldName] as String? ?? '',
      email: data[Strings.fieldEmail] as String? ?? '',
    );
  }

  /// Serializes this [Person] to a `Map<String, dynamic>` for Firestore writes.
  Map<String, dynamic> toFirestore() {
    // TODO: implement serialization
    return {};
  }
}
