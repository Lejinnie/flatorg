import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flat.dart';
import '../models/person.dart';
import '../repositories/flat_repository.dart';
import '../repositories/person_repository.dart';

/// Key used to persist the joined flat ID in SharedPreferences.
const String _prefKeyFlatId = 'flat_id';

/// Holds the current flat and the signed-in user's Person document.
///
/// On construction the provider restores any persisted [flatId] from
/// SharedPreferences and immediately begins watching the matching Firestore
/// documents.  When [setFlatId] is called (after create/join), the new ID is
/// saved and the streams are restarted.
class FlatProvider extends ChangeNotifier {
  final FlatRepository _flatRepo;
  final PersonRepository _personRepo;

  String _flatId = '';
  Flat? _flat;
  Person? _currentPerson;

  StreamSubscription<Flat?>? _flatSub;
  StreamSubscription<Person?>? _personSub;

  FlatProvider({
    FlatRepository? flatRepo,
    PersonRepository? personRepo,
  })  : _flatRepo = flatRepo ?? FlatRepository(),
        _personRepo = personRepo ?? PersonRepository();

  String get flatId => _flatId;
  Flat?   get flat   => _flat;
  Person? get currentPerson => _currentPerson;
  bool    get hasFlat => _flatId.isNotEmpty;

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Loads the persisted flat ID from SharedPreferences and starts streams.
  /// Must be awaited before the router runs its first redirect.
  Future<void> init(String? uid) async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_prefKeyFlatId) ?? '';
    if (savedId.isNotEmpty && uid != null) {
      await _startStreams(savedId, uid);
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Persists [flatId] and restarts Firestore streams for the new flat.
  Future<void> setFlatId(String flatId, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyFlatId, flatId);
    await _startStreams(flatId, uid);
  }

  /// Clears the persisted flat ID and disposes streams (called on sign-out).
  Future<void> clearFlat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyFlatId);
    await _flatSub?.cancel();
    await _personSub?.cancel();
    _flatId = '';
    _flat = null;
    _currentPerson = null;
    notifyListeners();
  }

  // ── Stream management ─────────────────────────────────────────────────────

  Future<void> _startStreams(String flatId, String uid) async {
    await _flatSub?.cancel();
    await _personSub?.cancel();

    _flatId = flatId;
    notifyListeners();

    _flatSub = _flatRepo.watchFlat(flatId).listen((flat) {
      _flat = flat;
      notifyListeners();
    });

    _personSub = _personRepo.watchMember(flatId, uid).listen((person) {
      _currentPerson = person;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _flatSub?.cancel();
    _personSub?.cancel();
    super.dispose();
  }
}
