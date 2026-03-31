import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/strings.dart';

/// An issue to be reported to the landlord (Livit).
/// Stored at flats/{flatId}/issues/{issueId}.
class Issue {
  /// Firestore document ID.
  final String id;

  /// Short summary displayed in the issue list.
  final String title;

  /// Full description shown in the detail view.
  final String description;

  /// UID of the member who created this issue.
  final String createdBy;

  /// When the issue was created.
  final Timestamp createdAt;

  /// Timestamp of the most recent send to Livit.
  /// Null when the issue has never been sent.
  /// Enforces the 5-day cooldown (issueSendCooldownDays).
  final Timestamp? lastSentAt;

  const Issue({
    required this.id,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.lastSentAt,
  });

  /// Returns true when the issue is on cooldown and cannot be sent.
  bool get isOnCooldown {
    if (lastSentAt == null) {
      return false;
    }
    final cooldownEnd = lastSentAt!.toDate().add(const Duration(days: 5));
    return DateTime.now().isBefore(cooldownEnd);
  }

  /// Creates an Issue from a Firestore document snapshot.
  factory Issue.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Issue(
      id: doc.id,
      title: (data[fieldIssueTitle] as String?) ?? '',
      description: (data[fieldIssueDescription] as String?) ?? '',
      createdBy: (data[fieldIssueCreatedBy] as String?) ?? '',
      createdAt: data[fieldIssueCreatedAt] as Timestamp,
      lastSentAt: data[fieldIssueLastSentAt] as Timestamp?,
    );
  }

  /// Converts this issue to a Firestore-compatible map (excludes [id]).
  Map<String, dynamic> toFirestore() => {
    fieldIssueTitle: title,
    fieldIssueDescription: description,
    fieldIssueCreatedBy: createdBy,
    fieldIssueCreatedAt: createdAt,
    fieldIssueLastSentAt: lastSentAt,
  };

  Issue copyWith({
    String? id,
    String? title,
    String? description,
    String? createdBy,
    Timestamp? createdAt,
    Timestamp? lastSentAt,
  }) => Issue(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    lastSentAt: lastSentAt ?? this.lastSentAt,
  );
}

/// Status of a task-swap request.
enum SwapRequestStatus {
  pending,
  accepted,
  declined,
}

/// A swap request between two flat members.
/// Stored at flats/{flatId}/swapRequests/{requestId}.
class SwapRequest {
  final String id;
  final String requesterUid;
  final String targetTaskId;
  final String requesterTaskId;
  final SwapRequestStatus status;
  final Timestamp createdAt;

  const SwapRequest({
    required this.id,
    required this.requesterUid,
    required this.targetTaskId,
    required this.requesterTaskId,
    required this.status,
    required this.createdAt,
  });

  factory SwapRequest.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return SwapRequest(
      id: doc.id,
      requesterUid: (data[fieldSwapRequesterUid] as String?) ?? '',
      targetTaskId: (data[fieldSwapTargetTaskId] as String?) ?? '',
      requesterTaskId: (data[fieldSwapRequesterTaskId] as String?) ?? '',
      status: _swapStatusFromString((data[fieldSwapStatus] as String?) ?? 'pending'),
      createdAt: data[fieldSwapCreatedAt] as Timestamp,
    );
  }

  Map<String, dynamic> toFirestore() => {
    fieldSwapRequesterUid: requesterUid,
    fieldSwapTargetTaskId: targetTaskId,
    fieldSwapRequesterTaskId: requesterTaskId,
    fieldSwapStatus: _swapStatusToString(status),
    fieldSwapCreatedAt: createdAt,
  };

  static SwapRequestStatus _swapStatusFromString(String value) {
    switch (value) {
      case 'accepted':
        return SwapRequestStatus.accepted;
      case 'declined':
        return SwapRequestStatus.declined;
      default:
        return SwapRequestStatus.pending;
    }
  }

  static String _swapStatusToString(SwapRequestStatus status) {
    switch (status) {
      case SwapRequestStatus.accepted:
        return 'accepted';
      case SwapRequestStatus.declined:
        return 'declined';
      case SwapRequestStatus.pending:
        return 'pending';
    }
  }
}

/// A shopping list item.
/// Stored at flats/{flatId}/shoppingItems/{itemId}.
class ShoppingItem {
  final String id;
  final String text;
  final String addedBy;
  final bool isBought;

  /// Null when not yet bought.
  final Timestamp? boughtAt;

  /// Position in the unbought list for manual reordering.
  /// Defaults to 0 for items created before this field was introduced.
  final int order;

  const ShoppingItem({
    required this.id,
    required this.text,
    required this.addedBy,
    required this.isBought,
    required this.boughtAt,
    this.order = 0,
  });

  factory ShoppingItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ShoppingItem(
      id: doc.id,
      text: (data[fieldShoppingText] as String?) ?? '',
      addedBy: (data[fieldShoppingAddedBy] as String?) ?? '',
      isBought: (data[fieldShoppingIsBought] as bool?) ?? false,
      boughtAt: data[fieldShoppingBoughtAt] as Timestamp?,
      order: (data[fieldShoppingOrder] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    fieldShoppingText: text,
    fieldShoppingAddedBy: addedBy,
    fieldShoppingIsBought: isBought,
    fieldShoppingBoughtAt: boughtAt,
    fieldShoppingOrder: order,
  };

  ShoppingItem copyWith({
    String? id,
    String? text,
    String? addedBy,
    bool? isBought,
    Timestamp? boughtAt,
    int? order,
  }) => ShoppingItem(
    id: id ?? this.id,
    text: text ?? this.text,
    addedBy: addedBy ?? this.addedBy,
    isBought: isBought ?? this.isBought,
    boughtAt: boughtAt ?? this.boughtAt,
    order: order ?? this.order,
  );
}
