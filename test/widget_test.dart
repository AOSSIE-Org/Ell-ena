import 'package:flutter_test/flutter_test.dart';
import 'package:ell_ena/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Basic smoke test: app loads
    expect(find.byType(MyApp), findsOneWidget);
  });
}
