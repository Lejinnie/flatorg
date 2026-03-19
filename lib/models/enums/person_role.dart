/// Roles available to flat members.
///
/// The admin (flat creator) has additional permissions such as removing
/// members, modifying tasks, and editing app settings. Admin rights
/// can be transferred to another member.
enum PersonRole {
  /// Full control: remove members, modify tasks, edit settings.
  admin,

  /// Standard member: mark own task done, set vacation, swap tasks,
  /// read/write shopping list and issue list.
  member;

  /// Firestore string representation of this role.
  String toFirestore() {
    switch (this) {
      case PersonRole.admin:
        return 'admin';
      case PersonRole.member:
        return 'member';
    }
  }

  /// Parses a Firestore string into a [PersonRole].
  ///
  /// Returns [PersonRole.member] if the value is null or unrecognized.
  static PersonRole fromFirestore(String? value) {
    switch (value) {
      case 'admin':
        return PersonRole.admin;
      case 'member':
        return PersonRole.member;
      default:
        return PersonRole.member;
    }
  }
}
