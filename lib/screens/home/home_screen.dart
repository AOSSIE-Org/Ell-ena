import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/navigation/models/home_tab.dart';
import '../../router/app_routes.dart';
import '../../shell/app_shell.dart';
import '../../shell/desktop_shell.dart';
import '../../shell/shell_destination.dart';
import '../calendar/calendar_screen.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_screen.dart';
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

  @override
  Widget build(BuildContext context) {
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

    if (AppShell.isDesktop(context)) {
      return DesktopShell(
        selectedDestination: ShellDestination.values[selectedTab.index],
        onDestinationSelected: (destination) => _selectTab(destination.index),
        child: content,
      );
    }

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
