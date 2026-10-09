import 'package:ell_ena/screens/home/dashboard_screen.dart';
import 'package:ell_ena/widgets/custom_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  testWidgets('loads the dashboard and switches the chart filter',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    expect(find.byType(DashboardLoadingSkeleton), findsOneWidget);

    await tester.pump();
    await tester.pump();

    expect(find.text('Welcome back,'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('Month'), 300);
    await tester.tap(find.text('Month'));
    await tester.pump();

    expect(
      find.text(DateFormat('MMMM yyyy').format(DateTime.now())),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
