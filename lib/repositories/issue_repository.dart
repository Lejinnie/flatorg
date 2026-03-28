import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/issue.dart';
import '../constants/strings.dart';

/// Repository for Issue documents under flats/{flatId}/issues.
class IssueRepository {
  final FirebaseFirestore _db;

  IssueRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _issuesCollection(String flatId) {
    return _db
        .collection(collectionFlats)
        .doc(flatId)
        .collection(collectionIssues);
  }

  /// Returns a real-time stream of all issues for a flat, newest first.
  Stream<List<Issue>> watchIssues(String flatId) {
    return _issuesCollection(flatId)
        .orderBy(fieldIssueCreatedAt, descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Issue.fromFirestore(d)).toList());
  }

  /// Creates a new issue document.
  Future<void> createIssue(String flatId, Issue issue) async {
    await _issuesCollection(flatId).doc(issue.id).set(issue.toFirestore());
  }

  /// Deletes an issue document.
  Future<void> deleteIssue(String flatId, String issueId) async {
    await _issuesCollection(flatId).doc(issueId).delete();
  }

  /// Sets last_sent_at to now, enforcing the 5-day send cooldown.
  Future<void> markIssueAsSent(String flatId, String issueId) async {
    await _issuesCollection(flatId).doc(issueId).update({
      fieldIssueLastSentAt: Timestamp.now(),
    });
  }
}
