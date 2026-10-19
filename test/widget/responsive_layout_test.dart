import 'package:ell_ena/core/responsive/breakpoints.dart';
import 'package:ell_ena/core/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveLayout(
          mobile: Text('mobile-layout'),
          desktop: Text('desktop-layout'),
        ),
      ),
    );
  }

  testWidgets('widths below the mobile breakpoint render the mobile child',
      (tester) async {
    expect(Breakpoints.mobileMax, lessThan(768));

    await pumpAt(tester, const Size(500, 800));

    expect(find.text('mobile-layout'), findsOneWidget);
    expect(find.text('desktop-layout'), findsNothing);
  });

  testWidgets(
      'widths at or above the desktop breakpoint render the desktop child',
      (tester) async {
    expect(Breakpoints.tabletMax, 1024);

    await pumpAt(tester, const Size(1024, 800));

    expect(find.text('desktop-layout'), findsOneWidget);
    expect(find.text('mobile-layout'), findsNothing);
  });

  testWidgets('tablet widths use the desktop child when no tablet child is set',
      (tester) async {
    await pumpAt(tester, const Size(800, 800));

    expect(find.text('desktop-layout'), findsOneWidget);
    expect(find.text('mobile-layout'), findsNothing);
  });
}
