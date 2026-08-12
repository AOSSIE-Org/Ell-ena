import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../providers/navigation/models/home_tab.dart';
import '../../router/app_routes.dart';
import '../workspace/workspace_screen.dart';
import '../calendar/calendar_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_screen.dart';
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
  HomeTab get _selectedTab => AppRoutes.homeTabForPath(widget.location);

  int get _workspaceTabIndex =>
      AppRoutes.workspaceTabIndexForPath(widget.location) ?? 0;

  void _selectTab(int index) {
    final path = AppRoutes.pathForHomeTab(HomeTab.fromIndex(index));
    if (widget.location != path) {
      context.go(path);
    }
  }

  void _onWorkspaceTabSelected(int index) {
    final path = AppRoutes.pathForWorkspaceTabIndex(index);
    if (widget.location != path) {
      context.go(path);
    }
  }

  Map<String, dynamic>? get _chatArguments {
    final message = widget.queryParameters['message'];
    if (message == null || message.isEmpty) {
      return null;
    }
    return {'initial_message': message};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedTab = _selectedTab;
    final chatMessage = widget.queryParameters['message'];

    final screens = <Widget>[
      const DashboardScreen(),
      const CalendarScreen(),
      WorkspaceScreen(
        key: ValueKey<int>(_workspaceTabIndex),
        initialTabIndex: _workspaceTabIndex,
        onTabSelected: _onWorkspaceTabSelected,
      ),
      ChatScreen(
        key: ValueKey<String?>(chatMessage),
        arguments: _chatArguments,
      ),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: selectedTab.index,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedTab.index,
        onTap: _selectTab,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurfaceVariant,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work),
            label: 'Workspace',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
