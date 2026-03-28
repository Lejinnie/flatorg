import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Wraps Firebase Auth and exposes auth state to the widget tree.
///
/// Subscribes to [FirebaseAuth.instance.authStateChanges] on construction
/// and calls [notifyListeners] whenever the signed-in user changes.
class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth;

  User? _currentUser;
  bool _isLoading = false;
  String _errorMessage = '';

  AuthProvider({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance {
    // Sync initial value and listen for future changes.
    _currentUser = _auth.currentUser;
    _auth.authStateChanges().listen((user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get isSignedIn => _currentUser != null;
  bool get isEmailVerified => _currentUser?.emailVerified ?? false;

  // ── Auth operations ───────────────────────────────────────────────────────

  /// Signs the user in with email and password.
  /// Returns the signed-in [User] on success, or null on failure
  /// (error is stored in [errorMessage]).
  Future<User?> signIn(String email, String password) async {
    _setLoading(true);
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _errorMessage = '';
      return credential.user;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _humaniseAuthError(e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Registers a new user with email and password.
  /// Does NOT set display name — that is written to Firestore by the caller.
  Future<User?> register(String email, String password) async {
    _setLoading(true);
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _errorMessage = '';
      return credential.user;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _humaniseAuthError(e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Sends an email-verification link to the current user's address.
  ///
  /// Returns an empty string on success, or a human-readable error message on
  /// failure (e.g. rate-limited, no network). Never throws.
  Future<String> sendVerificationEmail() async {
    try {
      // _currentUser is set via the async authStateChanges() stream and may
      // still be null immediately after registration; _auth.currentUser is
      // updated synchronously by Firebase after account creation.
      final user = _currentUser ?? _auth.currentUser;
      if (user == null) return 'No signed-in user found. Please sign in again.';
      await user.sendEmailVerification();
      debugPrint('[AuthProvider] Verification email sent to ${user.email}');
      return '';
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthProvider] sendEmailVerification error: ${e.code} — ${e.message}');
      return _humaniseAuthError(e);
    } catch (e) {
      debugPrint('[AuthProvider] sendEmailVerification unexpected error: $e');
      return 'Failed to send verification email. Please try again.';
    }
  }

  /// Reloads the current user's auth state from Firebase.
  /// Call this to refresh [isEmailVerified] after the user taps the link.
  Future<void> reloadUser() async {
    await _currentUser?.reload();
    _currentUser = _auth.currentUser;
    notifyListeners();
  }

  /// Sends a password-reset link to [email].
  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true);
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      _errorMessage = '';
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _humaniseAuthError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Maps Firebase error codes to user-friendly messages.
  String _humaniseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'too-many-requests':
        return 'Too many attempts, try again later.';
      case 'network-request-failed':
        return 'No network connection. Please check your internet.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
