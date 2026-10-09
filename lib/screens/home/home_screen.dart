import 'package:flutter/material.dart';
import '../workspace/workspace_screen.dart';
import '../calendar/calendar_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? arguments;

  const HomeScreen({super.key, this.arguments});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _chatTabIndex = 3;
  static const int _tabCount = 5;

  int _selectedIndex = 0;
  bool _chatInitialized = false;
  Map<String, dynamic>? _chatArgs;

  @override
  void initState() {
    super.initState();

    // Parse arguments synchronously before first build so ChatScreen
    // receives _chatArgs on its very first render with no race condition.
    final args = widget.arguments;
    if (args != null) {
      final int targetIndex =
          (args['screen'] is int) ? args['screen'] as int : _selectedIndex;

      _selectedIndex = (targetIndex >= 0 && targetIndex < _tabCount)
          ? targetIndex
          : _selectedIndex;

      // Always capture initial_message regardless of which tab is targeted,
      // so the message is available when the user navigates to the chat tab.
      final dynamic initialMessage = args['initial_message'];
      if (initialMessage is String && initialMessage.trim().isNotEmpty) {
        _chatArgs = {'initial_message': initialMessage.trim()};
      }
    }

    // If starting on chat tab, initialize it immediately.
    if (_selectedIndex == _chatTabIndex) {
      _chatInitialized = true;
    }
  }

  void _onTap(int index) {
    setState(() {
      _selectedIndex = index;
      // Lazy-load ChatScreen only when user first visits the chat tab.
      // This avoids unnecessary startup cost from eager IndexedStack init.
      if (index == _chatTabIndex) {
        _chatInitialized = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final screens = <Widget>[
      const DashboardScreen(),
      const CalendarScreen(),
      const WorkspaceScreen(),

      // Lazy-load ChatScreen: only initialize when user first visits chat tab.
      _chatInitialized
          ? ChatScreen(
              key: const PageStorageKey('chat_screen'),
              arguments: _chatArgs,
            )
          : const SizedBox.shrink(),

      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTap,
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