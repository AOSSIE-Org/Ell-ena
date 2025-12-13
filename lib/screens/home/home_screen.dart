import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/navigation_service.dart';
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

  // Cache for initialized screens to avoid rebuilding
  final Map<int, Widget> _screenCache = {};

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
    
    // Handle initial arguments if provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.arguments != null) {
        if (widget.arguments!.containsKey('screen') && widget.arguments!['screen'] is int) {
          setState(() {
            _selectedIndex = widget.arguments!['screen'];
          });
        }
        
        // Handle initial message for chat screen
        if (widget.arguments!.containsKey('initial_message') && 
            widget.arguments!['initial_message'] is String && 
            _selectedIndex == 3) {
          // The chat screen will be built with arguments when accessed
        }
      }
    });
  }
  
  /// Get screen widget for the given index with lazy initialization
  Widget _getScreen(int index) {
    // Return cached screen if available
    if (_screenCache.containsKey(index)) {
      return _screenCache[index]!;
    }
    
    // Build screen on first access
    Widget screen;
    switch (index) {
      case 0:
        screen = const DashboardScreen();
        break;
      case 1:
        screen = const CalendarScreen();
        break;
      case 2:
        screen = const WorkspaceScreen();
        break;
      case 3:
        // Check if we need to pass initial message argument
        if (widget.arguments != null && 
            widget.arguments!.containsKey('initial_message') &&
            index == _selectedIndex) {
          screen = ChatScreen(
            arguments: {'initial_message': widget.arguments!['initial_message']}
          );
        } else {
          screen = const ChatScreen();
        }
        break;
      case 4:
        screen = const ProfileScreen();
        break;
      default:
        screen = const DashboardScreen();
    }
    
    // Cache the screen
    _screenCache[index] = screen;
    return screen;
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
    // TODO: Implement AI response
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
    // TODO: Implement voice recognition
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
      body: _getScreen(_selectedIndex),
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
