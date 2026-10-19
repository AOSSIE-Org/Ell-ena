import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/navigation/models/home_tab.dart';
import '../../router/app_routes.dart';
import '../../shell/app_shell.dart';
import '../../shell/desktop_shell.dart';
import '../../shell/shell_destination.dart';
import '../../shell/shell_refreshable.dart';
import '../../shell/widgets/shell_top_bar.dart';
import '../calendar/calendar_screen.dart';
import '../chat/chat_screen.dart';
import '../meetings/meeting_screen.dart';
import '../profile/profile_screen.dart';
import '../tasks/task_screen.dart';
import '../tickets/ticket_screen.dart';
import '../workspace/workspace_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  final String location;
  final Map<String, String> queryParameters;

  const HomeScreen({
    super.key,
    this.location = AppRoutes.home,
    this.queryParameters = const {},
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String get _currentPath {
    final routePath = GoRouterState.of(context).uri.path;
    if (routePath.isNotEmpty) return routePath;
    return widget.location;
  }

  HomeTab get _selectedTab => AppRoutes.homeTabForPath(_currentPath);

  int get _workspaceTabIndex =>
      AppRoutes.workspaceTabIndexForPath(_currentPath) ?? 0;

  void _selectTab(int index) {
    final path = AppRoutes.pathForHomeTab(HomeTab.fromIndex(index));
    if (_currentPath != path) {
      context.go(path);
    }
  }

  void _onWorkspaceTabSelected(int index) {
    final path = AppRoutes.pathForWorkspaceTabIndex(index);
    if (_currentPath != path) {
      context.go(path);
    }
  }

  String? get _chatMessage {
    final fromRoute = GoRouterState.of(context).uri.queryParameters['message'];
    if (fromRoute != null && fromRoute.isNotEmpty) return fromRoute;
    final message = widget.queryParameters['message'];
    if (message == null || message.isEmpty) return null;
    return message;
  }

  Map<String, dynamic>? get _chatArguments {
    final message = _chatMessage;
    if (message == null) return null;
    return {'initial_message': message};
  }

  // Keep page state when the window crosses the wide breakpoint, and let the
  // top bar reach each page's refresh.
  final _dashboardKey = GlobalKey();
  final _calendarKey = GlobalKey();
  final _profileKey = GlobalKey();

  Future<void> _refresh(ShellDestination destination) async {
    switch (destination) {
      case ShellDestination.dashboard:
        await _refreshPage(_dashboardKey);
        break;
      case ShellDestination.calendar:
        await _refreshPage(_calendarKey);
        break;
      case ShellDestination.tasks:
        TaskScreen.refreshTasks();
        break;
      case ShellDestination.tickets:
        TicketScreen.refreshTickets();
        break;
      case ShellDestination.meetings:
        MeetingScreen.refreshMeetings();
        break;
      case ShellDestination.profile:
        await _refreshPage(_profileKey);
        break;
      case ShellDestination.chat:
        break;
    }
  }

  Future<void> _refreshPage(GlobalKey key) async {
    await (key.currentState as ShellRefreshable?)?.refreshFromShell();
  }

  /// Team data feeds every page, so all of them reload after a switch.
  void _refreshAllPages() {
    for (final destination in ShellDestination.values) {
      _refresh(destination);
    }
  }

  /// The phone's floating add button, as a top bar button on wide screens.
  ShellPageAction? _pageActionFor(ShellDestination destination) {
    final l10n = AppLocalizations.of(context);
    switch (destination) {
      case ShellDestination.tasks:
        return ShellPageAction(
          label: l10n.newTask,
          icon: Icons.add,
          onPressed: TaskScreen.openCreateTask,
        );
      case ShellDestination.tickets:
        return ShellPageAction(
          label: l10n.newTicket,
          icon: Icons.add,
          onPressed: TicketScreen.openCreateTicket,
        );
      case ShellDestination.meetings:
        return ShellPageAction(
          label: l10n.newMeeting,
          icon: Icons.add,
          onPressed: MeetingScreen.openCreateMeeting,
        );
      case ShellDestination.dashboard:
      case ShellDestination.calendar:
      case ShellDestination.chat:
      case ShellDestination.profile:
        return null;
    }
  }

  Widget _buildWideShell() {
    final selected = ShellDestination.fromPath(_currentPath);
    Widget pageFor(ShellDestination destination) {
      switch (destination) {
        case ShellDestination.dashboard:
          return DashboardScreen(key: _dashboardKey);
        case ShellDestination.calendar:
          return CalendarScreen(key: _calendarKey);
        case ShellDestination.tasks:
          return TaskScreen(key: TaskScreen.globalKey);
        case ShellDestination.tickets:
          return TicketScreen(key: TicketScreen.globalKey);
        case ShellDestination.meetings:
          return MeetingScreen(key: MeetingScreen.globalKey);
        case ShellDestination.chat:
          return ChatScreen(
            key: ValueKey<String?>(_chatMessage),
            arguments: _chatArguments,
          );
        case ShellDestination.profile:
          return ProfileScreen(key: _profileKey);
      }
    }

    return DesktopShell(
      selectedDestination: selected,
      onDestinationSelected: (destination) {
        if (_currentPath != destination.path) context.go(destination.path);
      },
      pageAction: _pageActionFor(selected),
      onRefresh: selected.canRefresh ? () => _refresh(selected) : null,
      onTeamChanged: _refreshAllPages,
      onOpenProfile: () => context.go(AppRoutes.profile),
      child: IndexedStack(
        index: selected.index,
        children: [
          for (final destination in ShellDestination.values)
            pageFor(destination),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppShell.isDesktop(context)) {
      return _buildWideShell();
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final selectedTab = _selectedTab;
    final screens = <Widget>[
      const DashboardScreen(),
      const CalendarScreen(),
      WorkspaceScreen(
        key: ValueKey<int>(_workspaceTabIndex),
        initialTabIndex: _workspaceTabIndex,
        onTabSelected: _onWorkspaceTabSelected,
      ),
      ChatScreen(
        key: ValueKey<String?>(_chatMessage),
        arguments: _chatArguments,
      ),
      const ProfileScreen(),
    ];
    final content = IndexedStack(index: selectedTab.index, children: screens);

    return Scaffold(
      body: content,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: selectedTab.index,
        onTap: _selectTab,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurfaceVariant,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard),
            label: l10n.dashboard,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.calendar_today),
            label: l10n.calendar,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.work),
            label: l10n.workspace,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline),
            label: l10n.chat,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: l10n.profile,
          ),
        ],
      ),
    );
  }
}
