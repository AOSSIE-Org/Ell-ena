import 'package:ell_ena/shell/app_shell.dart';
import 'package:ell_ena/shell/desktop_shell.dart';
import 'package:ell_ena/shell/shell_destination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

void main() {
  Future<void> pumpShell(
    WidgetTester tester,
    double width, {
    ValueChanged<ShellDestination>? onSelected,
  }) async {
    await pumpApp(
      tester,
      AppShell(
        selectedDestination: ShellDestination.calendar,
        onDestinationSelected: onSelected,
        mobile: const Text('phone layout'),
        child: const Text('wide page'),
      ),
      size: Size(width, 900),
    );
    await tester.pump();
  }

  testWidgets('below the breakpoint shows the phone layout', (tester) async {
    await pumpShell(tester, AppShell.desktopBreakpoint - 1);

    expect(find.text('phone layout'), findsOneWidget);
    expect(find.byType(DesktopShell), findsNothing);
    expect(find.text('wide page'), findsNothing);
  });

  testWidgets('at the breakpoint wraps the page in the desktop shell',
      (tester) async {
    ShellDestination? selected;
    await pumpShell(
      tester,
      AppShell.desktopBreakpoint,
      onSelected: (d) => selected = d,
    );

    expect(find.text('phone layout'), findsNothing);
    expect(find.text('wide page'), findsOneWidget);
    final shell = tester.widget<DesktopShell>(find.byType(DesktopShell));
    expect(shell.selectedDestination, ShellDestination.calendar);

    await tester.tap(find.text('Tickets'));
    expect(selected, ShellDestination.tickets);
  });

  testWidgets('isDesktop follows the window width', (tester) async {
    late bool narrow;
    late bool wide;
    Widget probe(double width, void Function(bool) report) => MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Builder(builder: (context) {
            report(AppShell.isDesktop(context));
            return const SizedBox();
          }),
        );

    await tester.pumpWidget(probe(1023.9, (v) => narrow = v));
    await tester.pumpWidget(probe(1024, (v) => wide = v));

    expect(narrow, isFalse);
    expect(wide, isTrue);
  });
}
