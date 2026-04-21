import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'constants/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/flat_provider.dart';
import 'providers/theme_mode_provider.dart';
import 'repositories/person_repository.dart';
import 'router/app_router.dart';

/// Top-level FCM background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised by the time this runs.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } on Exception catch (e) {
    // Surface Firebase config errors (e.g. missing/wrong GoogleService-Info.plist)
    // as a visible screen instead of a silent blank launch.
    debugPrint('Firebase.initializeApp() failed: $e');
    runApp(_FirebaseErrorApp(error: e.toString()));
    return;
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const FlatOrgApp());
}

class FlatOrgApp extends StatelessWidget {
  const FlatOrgApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => FlatProvider()),
      ChangeNotifierProvider(create: (_) => ThemeModeProvider()),
    ],
    child: const _RouterInitialiser(),
  );
}

/// Initialises [FlatProvider] once the auth state is known, then mounts the
/// router.  A separate widget is needed so we can read providers after they
/// have been inserted into the tree.
class _RouterInitialiser extends StatefulWidget {
  const _RouterInitialiser();

  @override
  State<_RouterInitialiser> createState() => _RouterInitialiserState();
}

class _RouterInitialiserState extends State<_RouterInitialiser> {
  late final GoRouterWrapper _routerWrapper;
  var _initialised = false;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    final authProvider = context.read<AuthProvider>();
    final flatProvider = context.read<FlatProvider>();
    final themeModeProvider = context.read<ThemeModeProvider>();

    // Restore persisted settings before the first frame renders.
    await Future.wait([
      flatProvider.init(authProvider.currentUser?.uid),
      themeModeProvider.init(),
    ]);

    // Request notification permission after the UI is visible so the system
    // dialog appears over the app rather than over the native launch screen.
    // Fire-and-forget — a denial must never block the app from launching.
    unawaited(FirebaseMessaging.instance.requestPermission());

    // Register this device's FCM token so Cloud Functions can send push
    // notifications to it. Fire-and-forget — a registration failure must
    // never block the app from launching.
    unawaited(_registerFcmToken(authProvider, flatProvider));

    if (mounted) {
      setState(() {
        _routerWrapper = GoRouterWrapper(context);
        _initialised = true;
      });
    }
  }

  /// Retrieves the FCM device token and persists it in Firestore so that
  /// Cloud Functions can send push notifications to this device.
  ///
  /// Only runs when both uid and flatId are available (i.e. the user is
  /// logged in and has already joined a flat).  Silently swallows errors
  /// because notification registration failure must not crash the app.
  Future<void> _registerFcmToken(
    AuthProvider authProvider,
    FlatProvider flatProvider,
  ) async {
    final uid    = authProvider.currentUser?.uid ?? '';
    final flatId = flatProvider.flatId;
    if (uid.isEmpty || flatId.isEmpty) {
      return;
    }
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await PersonRepository().saveFcmToken(flatId, uid, token);
      }
    } on Exception catch (e) {
      // Log but never throw — push notification setup is best-effort.
      debugPrint('FCM token registration failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeModeProvider>().mode;

    if (!_initialised) {
      // Show a minimal splash while providers initialise.
      return MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp.router(
      title: 'FlatOrg',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: _routerWrapper.router,
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Thin wrapper that builds and holds the [GoRouter] instance.
class GoRouterWrapper {
  GoRouterWrapper(this._context);
  late final GoRouter router = buildAppRouter(_context);
  final BuildContext _context;
}

/// Shown when Firebase fails to initialise so the error is visible on device
/// rather than appearing as a blank/frozen screen.
class _FirebaseErrorApp extends StatelessWidget {
  const _FirebaseErrorApp({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Firebase failed to initialise',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(error, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    ),
  );
}
