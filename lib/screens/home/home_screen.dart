import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/navigation/models/home_tab.dart';
import '../../providers/navigation_provider.dart';
import '../workspace/workspace_screen.dart';
import '../calendar/calendar_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? arguments;

  const HomeScreen({super.key, this.arguments});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _initializeScreens();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyRouteArguments();
    });
  }

  void _initializeScreens() {
    _screens = [
      const DashboardScreen(),
      const CalendarScreen(),
      const WorkspaceScreen(),
      const ChatScreen(),
      const ProfileScreen(),
    ];
  }

  void _applyRouteArguments() {
    final args = widget.arguments;
    if (args == null) return;

    if (args.containsKey('screen') && args['screen'] is int) {
      ref.read(homeTabProvider.notifier).state =
          HomeTab.fromIndex(args['screen'] as int);
    }

    if (args.containsKey('initial_message') &&
        args['initial_message'] is String &&
        ref.read(homeTabProvider) == HomeTab.chat) {
      setState(() {
        _screens[HomeTab.chat.index] = ChatScreen(arguments: {
          'initial_message': args['initial_message'],
        });
      });
    }
  }

  void _selectTab(int index) {
    ref.read(homeTabProvider.notifier).state = HomeTab.fromIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedTab = ref.watch(homeTabProvider);

    return Scaffold(
      body: IndexedStack(
        index: selectedTab.index,
        children: _screens,
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
