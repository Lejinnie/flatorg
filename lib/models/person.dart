import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/strings.dart';
import '../constants/task_constants.dart';

/// Role of a flat member. Controls which admin-only actions are permitted.
enum PersonRole {
  admin,
  member,
}

/// String representation stored in Firestore for [PersonRole].
extension PersonRoleJson on PersonRole {
  String toJson() {
    switch (this) {
      case PersonRole.admin:
        return 'admin';
      case PersonRole.member:
        return 'member';
    }
  }

  static PersonRole fromJson(String value) {
    if (value == 'admin') return PersonRole.admin;
    return PersonRole.member;
  }
}

/// A flat member. Maps 1-to-1 with a Firebase Auth user.
/// Stored at flats/{flatId}/members/{uid}.
class Person {
  /// Firebase Auth UID — primary key.
  final String uid;

  /// Display name shown in the app.
  final String name;

  /// Email used for login and invitations.
  final String email;

  /// Determines which admin-only actions this person may take.
  final PersonRole role;

  /// When true, the person is marked as away.
  /// Takes effect on the next week_reset() if set before it fires.
  final bool onVacation;

  /// Swap opportunities remaining this semester.
  /// Resets to [swapTokensPerSemester] at each ETH semester start.
  final int swapTokensRemaining;

  const Person({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.onVacation,
    required this.swapTokensRemaining,
  });

  /// Whether this person has admin privileges.
  bool get isAdmin => role == PersonRole.admin;

  /// Whether this person has swap tokens remaining.
  bool get canRequestSwap => swapTokensRemaining > 0;

  /// Creates a Person from a Firestore document snapshot.
  factory Person.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Person(
      uid: doc.id,
      name: (data[fieldPersonName] as String?) ?? '',
      email: (data[fieldPersonEmail] as String?) ?? '',
      role: PersonRoleJson.fromJson((data[fieldPersonRole] as String?) ?? 'member'),
      onVacation: (data[fieldPersonOnVacation] as bool?) ?? false,
      swapTokensRemaining: (data[fieldPersonSwapTokens] as int?) ?? 0,
    );
  }

  /// Converts this person to a Firestore-compatible map (excludes [uid]).
  Map<String, dynamic> toFirestore() {
    return {
      fieldPersonName: name,
      fieldPersonEmail: email,
      fieldPersonRole: role.toJson(),
      fieldPersonOnVacation: onVacation,
      fieldPersonSwapTokens: swapTokensRemaining,
    };
  }

  /// Returns a copy of this person with the specified fields replaced.
  Person copyWith({
    String? uid,
    String? name,
    String? email,
    PersonRole? role,
    bool? onVacation,
    int? swapTokensRemaining,
  }) {
    return Person(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      onVacation: onVacation ?? this.onVacation,
      swapTokensRemaining: swapTokensRemaining ?? this.swapTokensRemaining,
    );
  }
}
