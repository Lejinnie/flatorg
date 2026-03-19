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
  /// Takes effect on the next [WeekResetService.weekReset] if set
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

  /// Creates a [Person] with the [PersonRole.admin] role.
  ///
  /// Used when creating the flat — the creator becomes the admin.
  Person.admin({
    required this.uid,
    required this.name,
    required this.email,
    this.onVacation = false,
    this.swapTokensRemaining = Strings.defaultSwapTokensPerSemester,
  }) : role = PersonRole.admin;

  // ---------------------------------------------------------------------------
  // Methods
  // ---------------------------------------------------------------------------

  /// Sets the vacation status for this person.
  ///
  /// If set before [WeekResetService.weekReset] fires, the change
  /// takes effect that week. If set after, it takes effect the following week.
  ///
  /// When a person completes their assigned task (via [Task.completedTask]),
  /// their vacation status is automatically cleared — they are considered
  /// "back from vacation."
  ///
  /// [vacation] — `true` to mark as on vacation, `false` to return.
  void setVacation(bool vacation) {
    onVacation = vacation;
  }

  /// Whether this person has the admin role.
  bool get isAdmin => role == PersonRole.admin;

  /// Whether this person can request a task swap (has tokens remaining).
  bool get canSwap => swapTokensRemaining > 0;

  /// Consumes one swap token after an accepted swap.
  ///
  /// Throws [StateError] if no tokens remain.
  void consumeSwapToken() {
    if (swapTokensRemaining <= 0) {
      throw StateError('No swap tokens remaining.');
    }
    swapTokensRemaining--;
  }

  /// Resets swap tokens to the per-semester default.
  ///
  /// Called by the token-reset Cloud Function at the start of each
  /// ETH semester.
  void resetSwapTokens() {
    swapTokensRemaining = Strings.defaultSwapTokensPerSemester;
  }

  // ---------------------------------------------------------------------------
  // Firestore serialization
  // ---------------------------------------------------------------------------

  /// Creates a [Person] instance from a Firestore document snapshot.
  ///
  /// [data] — the `Map<String, dynamic>` from `DocumentSnapshot.data()`.
  /// Expects fields matching [Strings] field name constants.
  factory Person.fromFirestore(Map<String, dynamic> data) {
    return Person(
      uid: data[Strings.fieldUid] as String? ?? '',
      name: data[Strings.fieldName] as String? ?? '',
      email: data[Strings.fieldEmail] as String? ?? '',
      role: PersonRole.fromFirestore(data[Strings.fieldRole] as String?),
      onVacation: data[Strings.fieldOnVacation] as bool? ?? false,
      swapTokensRemaining: data[Strings.fieldSwapTokensRemaining] as int? ??
          Strings.defaultSwapTokensPerSemester,
    );
  }

  /// Serializes this [Person] to a `Map<String, dynamic>` for Firestore writes.
  Map<String, dynamic> toFirestore() {
    return {
      Strings.fieldUid: uid,
      Strings.fieldName: name,
      Strings.fieldEmail: email,
      Strings.fieldRole: role.toFirestore(),
      Strings.fieldOnVacation: onVacation,
      Strings.fieldSwapTokensRemaining: swapTokensRemaining,
    };
  }
}
