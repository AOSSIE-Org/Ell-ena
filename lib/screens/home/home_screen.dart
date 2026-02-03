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
  Map<String, dynamic>? _chatArgs;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = widget.arguments;
      if (args == null) return;

      final int targetIndex =
          (args['screen'] is int) ? args['screen'] as int : _selectedIndex;

      final dynamic initialMessage = args['initial_message'];

      if (!mounted) return;

      setState(() {
        _selectedIndex = (targetIndex >= 0 && targetIndex < _tabCount)
            ? targetIndex
            : _selectedIndex;

        if (_selectedIndex == _chatTabIndex &&
            initialMessage is String &&
            initialMessage.trim().isNotEmpty) {
          _chatArgs = {'initial_message': initialMessage.trim()};
        }
      });
    });
  }

  void _onTap(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const DashboardScreen(),
      const CalendarScreen(),
      const WorkspaceScreen(),

      // chatScreen owns all chat state.
      // Home only forwards the initial_message args.
      ChatScreen(
        key: const PageStorageKey('chat_screen'),
        arguments: _chatArgs,
      ),

      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF2D2D2D),
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Workspace'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
