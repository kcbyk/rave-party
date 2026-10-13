import 'package:flutter_test/flutter_test.dart';
import 'package:party_rave/main.dart';

void main() {
  testWidgets('Rave App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RavePartyApp());
    expect(find.byType(RavePartyApp), findsOneWidget);
  });
}
