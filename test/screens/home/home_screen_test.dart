import 'package:ell_ena/router/app_routes.dart';
import 'package:ell_ena/screens/calendar/calendar_screen.dart';
import 'package:ell_ena/screens/chat/chat_screen.dart';
import 'package:ell_ena/screens/home/dashboard_screen.dart';
import 'package:ell_ena/screens/home/home_screen.dart';
import 'package:ell_ena/screens/meetings/create_meeting_screen.dart';
import 'package:ell_ena/screens/profile/profile_screen.dart';
import 'package:ell_ena/screens/tasks/create_task_screen.dart';
import 'package:ell_ena/screens/tickets/create_ticket_screen.dart';
import 'package:ell_ena/screens/workspace/workspace_screen.dart';
import 'package:ell_ena/shell/desktop_shell.dart';
import 'package:ell_ena/shell/shell_destination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/test_harness.dart';
import '../chat/speech_mock.dart';

void main() {
  setUpAll(setUpFakeSupabase);
  setUp(() async {
    mockSpeech();
    await resetFakeSupabase();
  });

  /// The app's shell route: one HomeScreen kept across every tab path.
  Future<GoRouter> pumpHome(
    WidgetTester tester,
    String location, {
    Size size = phoneSize,
  }) async {
    final router = await pumpRouted(
      tester,
      size: size,
      initialLocation: location,
      routes: [
        ShellRoute(
          builder: (context, state, child) => HomeScreen(
            location: state.uri.path,
            queryParameters: state.uri.queryParameters,
          ),
          routes: [
            for (final path in AppRoutes.shellPaths)
              GoRoute(path: path, builder: (_, __) => const SizedBox()),
          ],
        ),
      ],
    );
    await settle(tester);
    return router;
  }

  String path(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  BottomNavigationBar bottomBar(WidgetTester tester) =>
      tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));

  group('phone', () {
    testWidgets('bottom bar follows the route and navigates on tap',
        (tester) async {
      final router = await pumpHome(tester, AppRoutes.home);

      expect(bottomBar(tester).currentIndex, 0);
      expect(find.byType(DesktopShell), findsNothing);
      expect(find.byType(DashboardScreen), findsOneWidget);

      await tester.tap(find.text('Calendar'));
      await settle(tester);
      expect(path(router), AppRoutes.calendar);
      expect(bottomBar(tester).currentIndex, 1);

      await tester.tap(find.text('Profile'));
      await settle(tester);
      expect(path(router), AppRoutes.profile);
      expect(bottomBar(tester).currentIndex, 4);

      // Tapping the open tab again stays put.
      await tester.tap(find.text('Profile'));
      await settle(tester);
      expect(path(router), AppRoutes.profile);

      await tester.tap(find.text('Chat'));
      await settle(tester);
      expect(path(router), AppRoutes.chat);
      expect(bottomBar(tester).currentIndex, 3);
    });

    testWidgets('workspace deep links open the matching tab', (tester) async {
      final router = await pumpHome(tester, AppRoutes.tickets);

      expect(bottomBar(tester).currentIndex, 2);
      final workspace =
          tester.widget<WorkspaceScreen>(find.byType(WorkspaceScreen));
      expect(workspace.initialTabIndex, 1);
      final state = tester.state(find.byType(WorkspaceScreen));

      await settle(tester);
      await tester.tap(find.text('Meetings'));
      await settle(tester);
      expect(path(router), AppRoutes.meetings);

      // The plain workspace path opens the first tab.
      router.go(AppRoutes.workspace);
      await settle(tester);
      // Tab routes move the same workspace rather than rebuilding it.
      expect(tester.state(find.byType(WorkspaceScreen)), same(state));
      expect(
        tester
            .widget<WorkspaceScreen>(find.byType(WorkspaceScreen))
            .initialTabIndex,
        0,
      );
      await tester.tap(find.text('Tasks'));
      await settle(tester);
      expect(path(router), AppRoutes.workspace);
    });

    testWidgets('a chat link sends its message', (tester) async {
      await withFakeHttp(() async {
        backend.geminiHandler = (_) => FakeBackend.geminiText('On it');
        await pumpHome(tester, '${AppRoutes.chat}?message=Plan%20my%20day');

        final chat = tester.widget<ChatScreen>(find.byType(ChatScreen));
        expect(chat.arguments, {'initial_message': 'Plan my day'});

        await tester.pump(const Duration(milliseconds: 1100));
        await settle(tester);
        expect(find.text('Plan my day'), findsOneWidget);
        expect(find.text('On it'), findsOneWidget);
      });
    });

    testWidgets('an empty message is ignored', (tester) async {
      await pumpHome(tester, '${AppRoutes.chat}?message=');

      final chat = tester.widget<ChatScreen>(find.byType(ChatScreen));
      expect(chat.arguments, isNull);
    });
  });

  group('wide', () {
    DesktopShell shell(WidgetTester tester) =>
        tester.widget<DesktopShell>(find.byType(DesktopShell));

    testWidgets('sidebar selects pages and routes', (tester) async {
      final router = await pumpHome(tester, AppRoutes.tasks, size: wideSize);

      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(shell(tester).selectedDestination, ShellDestination.tasks);
      expect(shell(tester).pageAction?.label, 'New Task');

      await tester.tap(find.text('Meetings').first);
      await settle(tester);
      expect(path(router), AppRoutes.meetings);
      expect(shell(tester).selectedDestination, ShellDestination.meetings);
      expect(shell(tester).pageAction?.label, 'New Meeting');

      // Already there: no navigation.
      await tester.tap(find.text('Meetings').first);
      await settle(tester);
      expect(path(router), AppRoutes.meetings);

      await tester.tap(find.text('Chat').first);
      await settle(tester);
      expect(shell(tester).selectedDestination, ShellDestination.chat);
      // Chat has neither a page action nor a refresh button.
      expect(shell(tester).pageAction, isNull);
      expect(shell(tester).onRefresh, isNull);

      await tester.tap(find.text('Dashboard').first);
      await settle(tester);
      expect(path(router), AppRoutes.home);
      expect(shell(tester).pageAction, isNull);
    });

    for (final entry in {
      AppRoutes.tasks: CreateTaskScreen,
      AppRoutes.tickets: CreateTicketScreen,
      AppRoutes.meetings: CreateMeetingScreen,
    }.entries) {
      testWidgets('page action on ${entry.key} opens the create form',
          (tester) async {
        await pumpHome(tester, entry.key, size: wideSize);

        shell(tester).pageAction!.onPressed();
        await settle(tester);

        expect(find.byType(entry.value), findsOneWidget);
      });
    }

    testWidgets('refresh reloads the open page', (tester) async {
      final router = await pumpHome(tester, AppRoutes.home, size: wideSize);

      for (final destination in [
        ShellDestination.dashboard,
        ShellDestination.calendar,
        ShellDestination.tasks,
        ShellDestination.tickets,
        ShellDestination.meetings,
        ShellDestination.profile,
      ]) {
        router.go(destination.path);
        await settle(tester);
        backend.log.clear();

        await tester.tap(find.byIcon(Icons.refresh));
        await settle(tester, frames: 20);

        expect(
          backend.log,
          isNotEmpty,
          reason: '${destination.name} should reload',
        );
      }
    });

    testWidgets('switching team reloads every page', (tester) async {
      backend.seedSecondTeam();
      await pumpHome(tester, AppRoutes.home, size: wideSize);

      await tester.tap(find.text('Analytical Engines').last);
      await settle(tester);
      backend.moveUserToSecondTeam();
      backend.log.clear();
      await tester.tap(find.text('Difference Engines'));
      await settle(tester, frames: 20);

      // Tasks, tickets and meetings each reload, not just the open page.
      expect(backend.log, contains('GET /rest/v1/tasks'));
      expect(backend.log, contains('GET /rest/v1/tickets'));
      expect(backend.log, contains('GET /rest/v1/meetings'));
    });

    testWidgets('account menu opens the profile page', (tester) async {
      final router = await pumpHome(tester, AppRoutes.home, size: wideSize);

      await tester.tap(find.byTooltip('Ada'));
      await settle(tester);
      await tester.tap(find.text('Profile').last);
      await settle(tester);

      expect(path(router), AppRoutes.profile);
      expect(shell(tester).selectedDestination, ShellDestination.profile);
      expect(find.byType(ProfileScreen), findsOneWidget);
      // Other pages stay alive, offstage, keeping their state.
      expect(find.byType(CalendarScreen), findsNothing);
      expect(
        find.byType(CalendarScreen, skipOffstage: false),
        findsOneWidget,
      );
    });
  });
}
