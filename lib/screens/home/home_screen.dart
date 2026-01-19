import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/navigation_service.dart';
import '../../services/app_shortcuts_service.dart'; // Add this import
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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isListening = false;
  int _selectedIndex = 0;
  bool _isFabExpanded = false;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

  List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _initializeScreens();

    // Handle initial arguments if provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.arguments != null) {
        if (widget.arguments!.containsKey('screen') &&
            widget.arguments!['screen'] is int) {
          setState(() {
            _selectedIndex = widget.arguments!['screen'];
          });
        }

        if (widget.arguments!.containsKey('initial_message') &&
            widget.arguments!['initial_message'] is String &&
            _selectedIndex == 3) {
          setState(() {
            _screens[3] = ChatScreen(
              arguments: {'initial_message': widget.arguments!['initial_message']},
            );
          });
        }
      }
    });

    // Initialize shortcuts handler
    AppShortcutsService.init((route) {
      _handleShortcut(route);
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

  void _handleShortcut(String route) {
    int index = 0;
    
    switch (route) {
      case 'dashboard':
        index = 0;
        break;
      case 'calendar':
        index = 1;
        // Reset calendar screen if needed
        if (_screens[1] is CalendarScreen) {
          setState(() {
            _screens[1] = CalendarScreen();
          });
        }
        break;
      case 'workspace':
        index = 2;
        break;
      case 'chat':
        index = 3;
        // Reset chat screen if needed
        setState(() {
          _screens[3] = ChatScreen();
        });
        break;
      case 'profile':
        index = 4;
        break;
      default:
        index = 0;
    }

    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: _messageController.text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _messageController.clear();
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
    });
  }

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF2D2D2D),
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Workspace'),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.green.shade400 : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(message.text, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}