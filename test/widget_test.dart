import 'package:flutter_test/flutter_test.dart';

import 'package:flatorg/main.dart';

void main() {
  testWidgets('FlatOrg smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FlatOrgApp());
    expect(find.byType(FlatOrgApp), findsOneWidget);
  });
}
