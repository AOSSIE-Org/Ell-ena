import 'package:ell_ena/l10n/app_localizations.dart';
import 'package:ell_ena/shell/desktop_shell.dart';
import 'package:ell_ena/shell/shell_destination.dart';
import 'package:ell_ena/shell/widgets/shell_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    ShellDestination selected = ShellDestination.dashboard,
    ValueChanged<ShellDestination>? onDestinationSelected,
    Future<void> Function()? onRefresh,
    ShellPageAction? pageAction,
    Widget child = const Text('page body'),
  }) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DesktopShell(
          selectedDestination: selected,
          onDestinationSelected: onDestinationSelected,
          onRefresh: onRefresh,
          pageAction: pageAction,
          child: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sidebar lists tasks, tickets and meetings as pages',
      (tester) async {
    await pumpShell(tester);

    for (final label in [
      'Dashboard',
      'Calendar',
      'Tasks',
      'Tickets',
      'Meetings',
      'Chat',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('Workspace'), findsNothing);
    expect(find.text('page body'), findsOneWidget);
  });

  testWidgets('no longer shows the placeholder account footer', (tester) async {
    await pumpShell(tester);

    expect(find.text('Account'), findsNothing);
    expect(find.text('Signed in'), findsNothing);
  });

  testWidgets('top bar titles the selected page', (tester) async {
    await pumpShell(tester, selected: ShellDestination.tickets);

    // Once in the sidebar, once as the top bar title.
    expect(find.text('Tickets'), findsNWidgets(2));
  });

  testWidgets('sidebar taps report the destination', (tester) async {
    ShellDestination? tapped;
    await pumpShell(tester, onDestinationSelected: (d) => tapped = d);

    await tester.tap(find.text('Meetings'));

    expect(tapped, ShellDestination.meetings);
  });

  testWidgets('refresh button runs the page refresh', (tester) async {
    var refreshes = 0;
    await pumpShell(tester, onRefresh: () async => refreshes++);

    await tester.tap(find.byTooltip('Refresh (R)'));
    await tester.pumpAndSettle();

    expect(refreshes, 1);
  });

  testWidgets('refresh button is hidden when the page has nothing to refresh',
      (tester) async {
    await pumpShell(tester, selected: ShellDestination.chat);

    expect(find.byTooltip('Refresh (R)'), findsNothing);
  });

  testWidgets('page action replaces the floating add button', (tester) async {
    var opened = 0;
    await pumpShell(
      tester,
      selected: ShellDestination.tasks,
      pageAction: ShellPageAction(
        label: 'New Task',
        icon: Icons.add,
        onPressed: () => opened++,
      ),
    );

    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'New Task'));

    expect(opened, 1);
  });

  testWidgets('pages without an action show no action button', (tester) async {
    await pumpShell(tester, selected: ShellDestination.dashboard);

    expect(find.byType(FilledButton), findsNothing);
  });

  group('keyboard shortcuts', () {
    ShellPageAction action(VoidCallback onPressed) => ShellPageAction(
          label: 'New Task',
          icon: Icons.add,
          onPressed: onPressed,
        );

    testWidgets('N runs the page action and R refreshes', (tester) async {
      var created = 0;
      var refreshed = 0;
      await pumpShell(
        tester,
        selected: ShellDestination.tasks,
        pageAction: action(() => created++),
        onRefresh: () async => refreshed++,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pumpAndSettle();

      expect(created, 1);
      expect(refreshed, 1);
    });

    testWidgets('typing in a field does not trigger shortcuts', (tester) async {
      var created = 0;
      await pumpShell(
        tester,
        selected: ShellDestination.tasks,
        pageAction: action(() => created++),
        child: const TextField(),
      );

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'n');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.pump();

      expect(created, 0);
    });

    testWidgets('modifier combinations are left to the browser',
        (tester) async {
      var refreshed = 0;
      await pumpShell(tester, onRefresh: () async => refreshed++);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(refreshed, 0);
    });

    testWidgets('shortcuts are off while a dialog is open', (tester) async {
      var created = 0;
      await pumpShell(
        tester,
        selected: ShellDestination.tasks,
        pageAction: action(() => created++),
      );

      showDialog<void>(
        context: tester.element(find.text('page body')),
        builder: (_) => const AlertDialog(content: Text('form')),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.pump();

      expect(created, 0);
    });
  });
}
