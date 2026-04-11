/// Sets up a minimal Firebase mock so that Firebase.initializeApp() succeeds
/// in widget tests without a real device or emulator.
///
/// Call setupFirebaseForTesting() before pumping any widget that depends on
/// Firebase. No packages beyond the transitive firebase_core_platform_interface
/// dependency are required.
library;

import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void setupFirebaseForTesting() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Seed a fake default Firebase app directly into the in-memory registry,
  // bypassing the Pigeon/platform-channel call that would fail in a test host.
  MethodChannelFirebase.appInstances[defaultFirebaseAppName] =
      MethodChannelFirebaseApp(
    defaultFirebaseAppName,
    const FirebaseOptions(
      apiKey: 'test-api-key',
      appId: 'test-app-id',
      messagingSenderId: 'test-sender-id',
      projectId: 'test-project',
    ),
  );
  MethodChannelFirebase.isCoreInitialized = true;
}
