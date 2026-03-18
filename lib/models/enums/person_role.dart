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
  member,
}
