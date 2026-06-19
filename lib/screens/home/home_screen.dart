import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/navigation/models/home_tab.dart';
import '../../providers/navigation_provider.dart';
import '../../router/app_routes.dart';
import '../workspace/workspace_screen.dart';
import '../calendar/calendar_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String location;
  final Map<String, String> queryParameters;
  final Map<String, dynamic>? arguments;

  const HomeScreen({
    super.key,
    this.location = AppRoutes.home,
    this.queryParameters = const {},
    this.arguments,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _workspaceTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromRoute(widget.location);
      _applyLegacyArguments();
    });
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location ||
        oldWidget.queryParameters != widget.queryParameters) {
      _syncFromRoute(widget.location);
    }
  }

  void _syncFromRoute(String location) {
    final tab = AppRoutes.homeTabForPath(location);
    if (ref.read(homeTabProvider) != tab) {
      ref.read(homeTabProvider.notifier).state = tab;
    }

    final workspaceTab = AppRoutes.workspaceTabIndexForPath(location);
    if (workspaceTab != null && _workspaceTabIndex != workspaceTab) {
      setState(() => _workspaceTabIndex = workspaceTab);
    }
  }

  void _applyLegacyArguments() {
    final args = widget.arguments;
    if (args == null) return;

    if (args.containsKey('screen') && args['screen'] is int) {
      final tab = HomeTab.fromIndex(args['screen'] as int);
      ref.read(homeTabProvider.notifier).state = tab;
      final path = AppRoutes.pathForHomeTab(tab);
      if (widget.location != path) {
        context.go(path);
      }
    }
  }

  void _selectTab(int index) {
    final tab = HomeTab.fromIndex(index);
    ref.read(homeTabProvider.notifier).state = tab;

    final path = AppRoutes.pathForHomeTab(tab);
    if (widget.location != path) {
      context.go(path);
    }
  }

  void _onWorkspaceTabSelected(int index) {
    if (_workspaceTabIndex != index) {
      setState(() => _workspaceTabIndex = index);
    }

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
    final selectedTab = ref.watch(homeTabProvider);
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
