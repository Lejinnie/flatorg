import 'package:flatorg/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FlatOrg smoke test', (tester) async {
    await tester.pumpWidget(const FlatOrgApp());
    expect(find.byType(FlatOrgApp), findsOneWidget);
  });
}
