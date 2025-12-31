import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/navigation_service.dart';
import '../workspace/workspace_screen.dart';
import '../calendar/calendar_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_screen.dart';
import 'dashboard_screen.dart';

import 'package:get/get.dart';
import '../../controllers/language_controller.dart';
import '../../utils/language/sentence_manager.dart';

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
  final LanguageController _languageController = Get.find<LanguageController>();

  List<Widget> _screens = [];

  // ... (initState and other methods remain the same)

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

    // Initialize screens
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

        // Handle initial message for chat screen
        if (widget.arguments!.containsKey('initial_message') &&
            widget.arguments!['initial_message'] is String &&
            _selectedIndex == 3) {
          // Update the chat screen with the initial message
          setState(() {
            _screens[3] = ChatScreen(arguments: {
              'initial_message': widget.arguments!['initial_message']
            });
          });
        }
      }
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
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Obx(() {
        final s = SentenceManager(
                currentLanguage: _languageController.selectedLanguage.value)
            .sentences;
        return BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF2D2D2D),
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.white70,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard),
              label: s.dashboard,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_today),
              label: s.calendar,
            ),
            BottomNavigationBarItem(
                icon: const Icon(Icons.work), label: s.workspace),
            BottomNavigationBarItem(
              icon: const Icon(Icons.chat_bubble_outline),
              label: s.chat,
            ),
            BottomNavigationBarItem(
                icon: const Icon(Icons.person), label: s.profile),
          ],
        );
      }),
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
