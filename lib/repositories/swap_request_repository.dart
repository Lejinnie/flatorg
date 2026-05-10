import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/strings.dart';
import '../models/issue.dart';

/// Repository for SwapRequest documents under flats/{flatId}/swapRequests.
class SwapRequestRepository {
  final FirebaseFirestore _db;

  SwapRequestRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _swapCollection(String flatId) =>
      _db
          .collection(collectionFlats)
          .doc(flatId)
          .collection(collectionSwapRequests);

  CollectionReference<Map<String, dynamic>> _tasksCollection(String flatId) =>
      _db
          .collection(collectionFlats)
          .doc(flatId)
          .collection(collectionTasks);

  CollectionReference<Map<String, dynamic>> _membersCollection(String flatId) =>
      _db
          .collection(collectionFlats)
          .doc(flatId)
          .collection(collectionMembers);

  /// Returns pending swap requests where the target task is currently assigned
  /// to [uid]. This drives the notification panel.
  Stream<List<SwapRequest>> watchPendingRequestsForUser(
    String flatId,
    String uid,
  ) =>
      _swapCollection(flatId)
          .where(fieldSwapStatus, isEqualTo: 'pending')
          .snapshots()
          .asyncMap((snap) async {
            final requests = snap.docs
                .map(SwapRequest.fromFirestore)
                .toList();

            // Fetch all target task docs in parallel instead of sequentially.
            final taskDocs = await Future.wait(
              requests.map((req) => _tasksCollection(flatId).doc(req.targetTaskId).get()),
            );

            final filtered = <SwapRequest>[];
            for (var i = 0; i < requests.length; i++) {
              final doc = taskDocs[i];
              if (doc.exists) {
                final assignedTo = doc.data()?[fieldTaskAssignedTo] as String? ?? '';
                if (assignedTo == uid) {
                  filtered.add(requests[i]);
                }
              }
            }
            return filtered;
          });

  /// Returns pending swap requests created BY [requesterUid]. Drives the
  /// outgoing-request tile and the "disable swap buttons while pending" UI.
  Stream<List<SwapRequest>> watchOutgoingPendingRequests(
    String flatId,
    String requesterUid,
  ) =>
      _swapCollection(flatId)
          .where(fieldSwapRequesterUid, isEqualTo: requesterUid)
          .where(fieldSwapStatus, isEqualTo: 'pending')
          .snapshots()
          .map((snap) => snap.docs.map(SwapRequest.fromFirestore).toList());

  /// Creates a new swap request document.
  Future<void> createSwapRequest(String flatId, SwapRequest request) async {
    await _swapCollection(flatId).doc(request.id).set(request.toFirestore());
  }

  /// Deletes a swap request document.  Called when the requester withdraws
  /// their pending request — the deletion makes B's incoming-tile stream
  /// drop the request automatically.
  Future<void> withdrawSwapRequest(String flatId, String requestId) =>
      _swapCollection(flatId).doc(requestId).delete();

  /// Declines all pending swap requests targeting [targetTaskId] except
  /// [acceptedRequestId] (used when [acceptedRequestId] is being accepted —
  /// any competing requests for the same target task are auto-rejected).
  ///
  /// Returns the requesterUids of declined requests so the caller can write
  /// rejection notifications to each.
  Future<List<String>> declineAllOtherPendingForTarget(
    String flatId,
    String targetTaskId,
    String acceptedRequestId,
  ) async {
    final snap = await _swapCollection(flatId)
        .where(fieldSwapStatus, isEqualTo: 'pending')
        .get();
    final others = snap.docs
        .map(SwapRequest.fromFirestore)
        .where((r) => r.targetTaskId == targetTaskId && r.id != acceptedRequestId)
        .toList();
    if (others.isEmpty) {
      return const <String>[];
    }
    final batch = _db.batch();
    for (final r in others) {
      batch.update(
        _swapCollection(flatId).doc(r.id),
        {fieldSwapStatus: 'declined'},
      );
    }
    await batch.commit();
    return others.map((r) => r.requesterUid).toList();
  }

  /// Responds to a swap request (accepted or declined).
  ///
  /// On accept: swaps assigned_to on both task documents in a single batch.
  /// Deducts 1 swap token from the requester only when request.isVacationSwap
  /// is true — mutual non-vacation swaps are free.
  Future<void> respondToSwapRequest(
    String flatId,
    SwapRequest request,
    SwapRequestStatus response,
  ) async {
    final batch = _db.batch()
      ..update(
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
      batch
        ..update(requesterTaskRef, {fieldTaskAssignedTo: targetUid})
        ..update(targetTaskRef,    {fieldTaskAssignedTo: requesterUid});

      // Only vacation swaps cost a token (determined at request creation time).
      if (request.isVacationSwap) {
        final requesterRef  = _membersCollection(flatId).doc(request.requesterUid);
        final requesterSnap = await requesterRef.get();
        final currentTokens = requesterSnap.data()?[fieldPersonSwapTokens] as int? ?? 0;
        batch.update(requesterRef, {fieldPersonSwapTokens: (currentTokens - 1).clamp(0, 999)});
      }
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
