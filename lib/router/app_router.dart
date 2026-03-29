import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/flat_provider.dart';
import '../screens/create_flat_screen.dart';
import '../screens/entry_screen.dart';
import '../screens/issues_screen.dart';
import '../screens/join_flat_screen.dart';
import '../screens/login_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/shopping_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/verify_email_screen.dart';

// ── Route path constants ──────────────────────────────────────────────────────

const routeLogin       = '/login';
const routeVerifyEmail = '/verify-email';
const routeEntry       = '/entry';
const routeCreateFlat  = '/create-flat';
const routeJoinFlat    = '/join-flat';
const routeTasks       = '/tasks';
const routeShopping    = '/shopping';
const routeIssues      = '/issues';
const routeSettings    = '/settings';

/// Builds a [GoRouter] that reads auth and flat state from providers and
/// redirects accordingly.
///
/// Redirect precedence (checked on every navigation event):
/// 1. Not signed in → [routeLogin]
/// 2. Signed in but email not verified → [routeVerifyEmail]
/// 3. Signed in, verified, no flat joined → [routeEntry]
/// 4. Otherwise → allow navigation (default destination: [routeTasks])
GoRouter buildAppRouter(BuildContext context) {
  final authProvider = context.read<AuthProvider>();
  final flatProvider = context.read<FlatProvider>();

  return GoRouter(
    initialLocation: routeTasks,
    refreshListenable: _CombinedListenable([authProvider, flatProvider]),
    redirect: (context, state) {
      final auth = context.read<AuthProvider>();
      final flat = context.read<FlatProvider>();

      final signedIn       = auth.isSignedIn;
      final emailVerified  = auth.isEmailVerified;
      final hasFlat        = flat.hasFlat;
      final path           = state.uri.path;

      // Not signed in — send to login (unless already going there).
      if (!signedIn) {
        return path == routeLogin ? null : routeLogin;
      }

      // Signed in but email not yet verified.
      if (!emailVerified) {
        return path == routeVerifyEmail ? null : routeVerifyEmail;
      }

      // Verified but hasn't joined a flat yet.
      if (!hasFlat) {
        if (path == routeEntry ||
            path == routeCreateFlat ||
            path == routeJoinFlat) {
          return null;
        }
        return routeEntry;
      }

      // Fully authenticated — redirect away from auth-only screens.
      if (path == routeLogin || path == routeVerifyEmail || path == routeEntry) {
        return routeTasks;
      }

      return null; // no redirect needed
    },
    routes: [
      GoRoute(path: routeLogin,       builder: (_, __) => const LoginScreen()),
      GoRoute(path: routeVerifyEmail, builder: (_, __) => const VerifyEmailScreen()),
      GoRoute(path: routeEntry,       builder: (_, __) => const EntryScreen()),
      GoRoute(path: routeCreateFlat,  builder: (_, __) => const CreateFlatScreen()),
      GoRoute(path: routeJoinFlat,    builder: (_, __) => const JoinFlatScreen()),
      GoRoute(path: routeTasks,       builder: (_, __) => const TasksScreen()),
      GoRoute(path: routeShopping,    builder: (_, __) => const ShoppingScreen()),
      GoRoute(path: routeIssues,      builder: (_, __) => const IssuesScreen()),
      GoRoute(path: routeSettings,    builder: (_, __) => const SettingsScreen()),
    ],
  );
}

/// Combines multiple [Listenable]s into one so `GoRouter.refreshListenable`
/// reacts to any provider change.
class _CombinedListenable extends ChangeNotifier {
  final List<Listenable> _listenables;

  _CombinedListenable(this._listenables) {
    for (final l in _listenables) {
      l.addListener(notifyListeners);
    }
  }

  @override
  void dispose() {
    for (final l in _listenables) {
      l.removeListener(notifyListeners);
    }
    super.dispose();
  }
}
