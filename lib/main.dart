import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'constants/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/flat_provider.dart';
import 'router/app_router.dart';

/// Top-level FCM background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised by the time this runs.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permission (Android 13+, iOS).
  await FirebaseMessaging.instance.requestPermission();

  runApp(const FlatOrgApp());
}

class FlatOrgApp extends StatelessWidget {
  const FlatOrgApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => FlatProvider()),
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

    // Restore persisted flatId for the current user (if any).
    await flatProvider.init(authProvider.currentUser?.uid);

    if (mounted) {
      setState(() {
        _routerWrapper = GoRouterWrapper(context);
        _initialised = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialised) {
      // Show a minimal splash while providers initialise.
      return MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp.router(
      title: 'FlatOrg',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
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
