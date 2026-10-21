import 'package:ell_ena/l10n/app_localizations.dart';
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

  Future<void> pumpDashboard(
    WidgetTester tester, {
    required Size size,
    Locale? locale,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  const overviewLabels = [
    'Total Tasks',
    'In Progress',
    'Completed',
    'Open Tickets',
    'Tickets In Progress',
    'Resolved',
  ];

  /// Labels in one row can sit a few pixels apart when one wraps to two
  /// lines, so positions within 40px count as the same row.
  int overviewRowCount(WidgetTester tester) {
    final tops = overviewLabels
        .map((label) => tester.getTopLeft(find.text(label)).dy)
        .toList()
      ..sort();
    var rows = 1;
    for (var i = 1; i < tops.length; i++) {
      if (tops[i] - tops[i - 1] > 40) rows++;
    }
    return rows;
  }

  for (final width in [1024.0, 1280.0, 1440.0, 1920.0]) {
    testWidgets('wide layout at ${width.toInt()}px shows the phone sections',
        (tester) async {
      await pumpDashboard(tester, size: Size(width, 1000));

      expect(tester.takeException(), isNull);
      // Same overview as the phone: title and all six numbers.
      expect(find.text("Today's Overview"), findsOneWidget);
      for (final label in overviewLabels) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Task Completion by Day'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('No recent activity'), 300);
      expect(find.text('Recent Activity'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await unmount(tester);
    });
  }

  testWidgets('wide overview puts all six numbers in one row',
      (tester) async {
    await pumpDashboard(tester, size: const Size(1440, 1000));

    final rows = overviewRowCount(tester);
    expect(rows, 1);

    await unmount(tester);
  });

  testWidgets('phone overview keeps two rows of three', (tester) async {
    await pumpDashboard(tester, size: const Size(390, 844));

    final rows = overviewRowCount(tester);
    expect(rows, 2);

    await unmount(tester);
  });

  testWidgets('phone dashboard is translated in Hindi', (tester) async {
    await pumpDashboard(
      tester,
      size: const Size(390, 844),
      locale: const Locale('hi'),
    );

    expect(find.text('वापसी पर स्वागत है,'), findsOneWidget);
    expect(find.text('आज का अवलोकन'), findsOneWidget);
    expect(find.text('Welcome back,'), findsNothing);
    expect(tester.takeException(), isNull);

    await unmount(tester);
  });

  testWidgets('fits beside the 289px sidebar at the 1024px breakpoint',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Row(
            children: [
              // Sidebar (288px) plus its divider, as in DesktopShell.
              SizedBox(width: 289),
              Expanded(child: DashboardScreen()),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    for (final label in overviewLabels) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    await tester.scrollUntilVisible(find.text('No recent activity'), 300);
    expect(tester.takeException(), isNull);

    await unmount(tester);
  });
}
