import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/issue.dart';
import '../constants/strings.dart';

/// Repository for SwapRequest documents under flats/{flatId}/swapRequests.
class SwapRequestRepository {
  final FirebaseFirestore _db;

  SwapRequestRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _swapCollection(String flatId) {
    return _db
        .collection(collectionFlats)
        .doc(flatId)
        .collection(collectionSwapRequests);
  }

  CollectionReference<Map<String, dynamic>> _tasksCollection(String flatId) {
    return _db
        .collection(collectionFlats)
        .doc(flatId)
        .collection(collectionTasks);
  }

  CollectionReference<Map<String, dynamic>> _membersCollection(String flatId) {
    return _db
        .collection(collectionFlats)
        .doc(flatId)
        .collection(collectionMembers);
  }

  /// Returns pending swap requests where the target task is currently assigned
  /// to [uid]. This drives the notification panel.
  Stream<List<SwapRequest>> watchPendingRequestsForUser(
    String flatId,
    String uid,
  ) {
    return _swapCollection(flatId)
        .where(fieldSwapStatus, isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snap) async {
      final requests = snap.docs
          .map((d) => SwapRequest.fromFirestore(d))
          .toList();

      // Filter to only requests targeting a task currently assigned to uid.
      final filtered = <SwapRequest>[];
      for (final req in requests) {
        final taskDoc = await _tasksCollection(flatId).doc(req.targetTaskId).get();
        if (taskDoc.exists) {
          final assignedTo = taskDoc.data()?[fieldTaskAssignedTo] as String? ?? '';
          if (assignedTo == uid) {
            filtered.add(req);
          }
        }
      }
      return filtered;
    });
  }

  /// Creates a new swap request document.
  Future<void> createSwapRequest(String flatId, SwapRequest request) async {
    await _swapCollection(flatId).doc(request.id).set(request.toFirestore());
  }

  /// Responds to a swap request (accepted or declined).
  ///
  /// On accept: swaps assigned_to on both task documents and decrements
  /// the requester's swap_tokens_remaining by 1 — all in a single batch.
  Future<void> respondToSwapRequest(
    String flatId,
    SwapRequest request,
    SwapRequestStatus response,
  ) async {
    final batch = _db.batch();

    // Update swap request status.
    batch.update(
      _swapCollection(flatId).doc(request.id),
      {fieldSwapStatus: _swapStatusToString(response)},
    );

    if (response == SwapRequestStatus.accepted) {
      final requesterTaskRef = _tasksCollection(flatId).doc(request.requesterTaskId);
      final targetTaskRef    = _tasksCollection(flatId).doc(request.targetTaskId);

      final requesterTaskSnap = await requesterTaskRef.get();
      final targetTaskSnap    = await targetTaskRef.get();

      final requesterUid = requesterTaskSnap.data()?[fieldTaskAssignedTo] as String? ?? '';
      final targetUid    = targetTaskSnap.data()?[fieldTaskAssignedTo] as String? ?? '';

      // Swap assigned_to on both tasks.
      batch.update(requesterTaskRef, {fieldTaskAssignedTo: targetUid});
      batch.update(targetTaskRef,    {fieldTaskAssignedTo: requesterUid});

      // Deduct one swap token from the requester.
      final requesterRef = _membersCollection(flatId).doc(request.requesterUid);
      final requesterSnap = await requesterRef.get();
      final currentTokens = requesterSnap.data()?[fieldPersonSwapTokens] as int? ?? 0;
      batch.update(requesterRef, {fieldPersonSwapTokens: (currentTokens - 1).clamp(0, 999)});
    }

    await batch.commit();
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
