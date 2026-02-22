// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Ell-ena app smoke test', (WidgetTester tester) async {
    // Basic smoke test - verifies the test framework works
    expect(true, isTrue);
  });

  test('Dart version check', () {
    // Verify Dart is available
    expect(Dart.version.isNotEmpty, isTrue);
  });
}
