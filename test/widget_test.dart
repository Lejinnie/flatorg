import 'package:firebase_core/firebase_core.dart';
import 'package:flatorg/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'firebase_test_setup.dart';

void main() {
  setUpAll(() async {
    setupFirebaseForTesting();
    await Firebase.initializeApp();
  });

  testWidgets('FlatOrg smoke test', (tester) async {
    await tester.pumpWidget(const FlatOrgApp());
    expect(find.byType(FlatOrgApp), findsOneWidget);
  });
}
