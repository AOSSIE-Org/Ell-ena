import 'package:flutter/material.dart';
import 'package:ell_ena/services/ai_service.dart';
import 'package:ell_ena/services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../tasks/task_detail_screen.dart';
import '../tickets/ticket_detail_screen.dart';
import '../meetings/meeting_detail_screen.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic>? arguments;
  const ChatScreen({super.key, this.arguments});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  final AIService _aiService = AIService();
  final SupabaseService _supabaseService = SupabaseService();

  List<Map<String, dynamic>> _teamMembers = [];
  List<Map<String, dynamic>> _userTasks = [];
  List<Map<String, dynamic>> _userTickets = [];

  bool _isProcessing = false;

  // Speech
  bool _isListening = false;
  late AnimationController _waveformController;
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListeningDialogOpen = false; // Track if dialog is open

  // Initial message safe handling
  bool _servicesReady = false;
  bool _initialMessageConsumed = false;
  String? _pendingMessage; // queue message when busy / not ready

  @override
  void initState() {
    super.initState();

    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _initSpeech();
    _initializeServices();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // consume arguments once
    if (_initialMessageConsumed) return;

    final args = widget.arguments;
    final initial = args?['initial_message'];

    if (initial is String && initial.trim().isNotEmpty) {
      _pendingMessage = initial.trim();
    }

    _initialMessageConsumed = true;

    // if services are ready already, flush now
    _flushPendingMessageIfPossible();
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
          // FIXED: Only pop if we know the dialog is open
          if (_isListeningDialogOpen && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            _isListeningDialogOpen = false;
          }
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _isListening = false);
        // FIXED: Only pop if we know the dialog is open
        if (_isListeningDialogOpen && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          _isListeningDialogOpen = false;
        }
      },
    );

    if (mounted) setState(() {});
  }

  Future<void> _initializeServices() async {
    try {
      if (!_aiService.isInitialized) await _aiService.initialize();
      if (!_supabaseService.isInitialized) await _supabaseService.initialize();

      if (_supabaseService.isInitialized) {
        final userProfile = await _supabaseService.getCurrentUserProfile();
        if (userProfile != null && userProfile['team_id'] != null) {
          await _loadTeamMembers(userProfile['team_id']);
          await _loadUserTasksAndTickets();
        }
      }

      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text: "Hello! I'm Ell-ena, your AI assistant. How can I help you today?",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });

      _servicesReady = true;
      _flushPendingMessageIfPossible();
    } catch (e) {
      debugPrint('Error initializing services: $e');
      // Even if init fails, avoid blocking forever
      _servicesReady = true;
      _flushPendingMessageIfPossible();
    }
  }

  Future<void> _loadTeamMembers(String teamId) async {
    try {
      final members = await _supabaseService.getTeamMembers(teamId);
      if (!mounted) return;
      setState(() => _teamMembers = members);
    } catch (e) {
      debugPrint('Error loading team members: $e');
    }
  }

  Future<void> _loadUserTasksAndTickets() async {
    try {
      final tasks = await _supabaseService.getTasks(filterByAssignment: true);
      final tickets = await _supabaseService.getTickets(filterByAssignment: true);

      if (!mounted) return;
      setState(() {
        _userTasks = tasks;
        _userTickets = tickets;
      });
    } catch (e) {
      debugPrint('Error loading tasks/tickets: $e');
    }
  }

  /// Safe: sends pending message only if services ready and not currently processing
  void _flushPendingMessageIfPossible() {
    if (!_servicesReady) return;
    if (_isProcessing) return;
    final msg = _pendingMessage?.trim();
    if (msg == null || msg.isEmpty) return;

    _pendingMessage = null; // consume
    _messageController.text = msg;
    _sendMessage();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (_isProcessing) {
      // queue latest input if user tries while busy
      _pendingMessage = text;
      return;
    }

    final userMessage = text;
    _messageController.clear();

    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(text: userMessage, isUser: true, timestamp: DateTime.now()));
      _isProcessing = true;
    });

    _scrollToBottom();

    try {
      final history = _getChatHistoryForAI();
      final response = await _aiService.generateChatResponse(
        userMessage,
        history,
        _teamMembers,
        userTasks: _userTasks,
        userTickets: _userTickets,
      );

      if (!mounted) return;

      if (response['type'] == 'function_call') {
        await _handleFunctionCall(
          response['function_name'],
          response['arguments'],
          response['raw_response'],
        );
      } else {
        setState(() {
          _messages.add(ChatMessage(
            text: response['content'],
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: "Sorry, I encountered an error. Please try again later.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isProcessing = false;
      });
    }

    _scrollToBottom();
    _flushPendingMessageIfPossible(); // send queued message if any
  }

  List<Map<String, String>> _getChatHistoryForAI() {
    final recent = _messages.length > 10 ? _messages.sublist(_messages.length - 10) : _messages;
    return recent.map((m) => {
      "role": m.isUser ? "user" : "assistant",
      "content": m.text,
    }).toList();
  }

  Future<void> _handleFunctionCall(
    String functionName,
    Map<String, dynamic> arguments,
    String rawResponse,
  ) async {
    if (!mounted) return;

    setState(() {
      _messages.add(ChatMessage(
        text: "I'll help you with that. Let me process your request...",
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });

    _scrollToBottom();

    try {
      Map<String, dynamic> result = {'success': false, 'error': 'Function not implemented'};

      switch (functionName) {
        case 'create_task':
          result = await _createTask(arguments);
          break;
        case 'create_ticket':
          result = await _createTicket(arguments);
          break;
        case 'create_meeting':
          result = await _createMeeting(arguments);
          break;
        case 'query_tasks':
          result = await _queryTasks(arguments);
          break;
        case 'query_tickets':
          result = await _queryTickets(arguments);
          break;
        case 'modify_item':
          result = await _modifyItem(arguments);
          break;
        default:
          result = {'success': false, 'error': 'Unknown function'};
      }

      final responseMessage = await _aiService.handleToolResponse(
        functionName: functionName,
        arguments: arguments,
        rawResponse: rawResponse,
        result: result,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: responseMessage,
          isUser: false,
          timestamp: DateTime.now(),
        ));

        if (result['success'] == true &&
            (functionName == 'create_task' ||
                functionName == 'create_ticket' ||
                functionName == 'create_meeting')) {
          _messages.add(ChatMessage(
            text: _getCardText(functionName, arguments, result),
            isUser: false,
            timestamp: DateTime.now(),
            isCard: true,
            cardType: _getCardType(functionName),
            cardData: result,
          ));
        }

        _isProcessing = false;
      });

      if (functionName == 'query_tasks' || functionName == 'query_tickets') {
        _loadUserTasksAndTickets();
      }
    } catch (e) {
      debugPrint('Error handling function call: $e');
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: "Sorry, I encountered an error while processing your request.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isProcessing = false;
      });
    }

    _scrollToBottom();
    _flushPendingMessageIfPossible();
  }

  // --- CRUD methods ---
  Future<Map<String, dynamic>> _createTask(Map<String, dynamic> arguments) async {
    try {
      if (!_supabaseService.isInitialized) return {'success': false, 'error': 'Service not initialized'};

      final title = arguments['title'] as String;
      final description = arguments['description'] as String?;

      DateTime? dueDate;
      if (arguments['due_date'] != null) {
        try { dueDate = DateTime.parse(arguments['due_date']); } catch (_) {}
      }

      String? assignedToUserId;
      final assignedTo = arguments['assigned_to'] as String?;
      if (assignedTo != null && assignedTo.isNotEmpty) {
        final uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
        if (uuid.hasMatch(assignedTo)) {
          assignedToUserId = assignedTo;
        } else {
          final matching = _teamMembers.firstWhere(
            (m) => m['full_name'].toString().toLowerCase() == assignedTo.toLowerCase(),
            orElse: () => {},
          );
          if (matching.isNotEmpty && matching['id'] != null) assignedToUserId = matching['id'];
        }
      }

      return await _supabaseService.createTask(
        title: title,
        description: description,
        dueDate: dueDate,
        assignedToUserId: assignedToUserId,
      );
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _createTicket(Map<String, dynamic> arguments) async {
    try {
      if (!_supabaseService.isInitialized) return {'success': false, 'error': 'Service not initialized'};

      final title = arguments['title'] as String;
      final description = arguments['description'] as String?;
      final priority = arguments['priority'] as String;
      final category = arguments['category'] as String;

      String? assignedToUserId;
      final assignedTo = arguments['assigned_to'] as String?;
      if (assignedTo != null && assignedTo.isNotEmpty) {
        final uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
        if (uuid.hasMatch(assignedTo)) {
          assignedToUserId = assignedTo;
        } else {
          final matching = _teamMembers.firstWhere(
            (m) => m['full_name'].toString().toLowerCase() == assignedTo.toLowerCase(),
            orElse: () => {},
          );
          if (matching.isNotEmpty && matching['id'] != null) assignedToUserId = matching['id'];
        }
      }

      return await _supabaseService.createTicket(
        title: title,
        description: description,
        priority: priority,
        category: category,
        assignedToUserId: assignedToUserId,
      );
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _createMeeting(Map<String, dynamic> arguments) async {
    try {
      if (!_supabaseService.isInitialized) return {'success': false, 'error': 'Service not initialized'};

      final title = arguments['title'] as String;
      final description = arguments['description'] as String?;
      final meetingUrl = arguments['meeting_url'] as String?;

      DateTime meetingDate;
      try { meetingDate = DateTime.parse(arguments['meeting_date']); }
      catch (_) { return {'success': false, 'error': 'Invalid meeting date format'}; }

      return await _supabaseService.createMeeting(
        title: title,
        description: description,
        meetingDate: meetingDate,
        meetingUrl: meetingUrl,
      );
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _queryTasks(Map<String, dynamic> arguments) async {
    try {
      if (!_supabaseService.isInitialized) return {'success': false, 'error': 'Service not initialized'};

      final status = arguments['status'] as String?;
      final dueDate = arguments['due_date'] as String?;
      final assignedToMe = arguments['assigned_to_me'] as bool? ?? false;
      final assignedToTeamMember = arguments['assigned_to_team_member'] as String?;

      String? teamMemberId;
      if (assignedToTeamMember != null && assignedToTeamMember.isNotEmpty) {
        final uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
        if (uuid.hasMatch(assignedToTeamMember)) {
          teamMemberId = assignedToTeamMember;
        } else {
          var match = _teamMembers.firstWhere(
            (m) => m['full_name'].toString().toLowerCase() == assignedToTeamMember.toLowerCase(),
            orElse: () => {},
          );
          if (match.isEmpty) {
            match = _teamMembers.firstWhere(
              (m) => m['full_name'].toString().toLowerCase().contains(assignedToTeamMember.toLowerCase()),
              orElse: () => {},
            );
          }
          if (match.isNotEmpty && match['id'] != null) teamMemberId = match['id'];
        }
      }

      List<Map<String, dynamic>> tasks;
      if (teamMemberId != null) {
        tasks = await _supabaseService.getTasks(
          filterByAssignment: false,
          filterByStatus: status != null && status != 'all' ? status : null,
          filterByDueDate: dueDate,
        );
        tasks = tasks.where((t) => t['assigned_to'] == teamMemberId).toList();
      } else {
        tasks = await _supabaseService.getTasks(
          filterByAssignment: assignedToMe,
          filterByStatus: status != null && status != 'all' ? status : null,
          filterByDueDate: dueDate,
        );
      }

      if (mounted) setState(() => _userTasks = tasks);
      return {'success': true, 'tasks': tasks, 'count': tasks.length};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _queryTickets(Map<String, dynamic> arguments) async {
    try {
      if (!_supabaseService.isInitialized) return {'success': false, 'error': 'Service not initialized'};

      final status = arguments['status'] as String?;
      final priority = arguments['priority'] as String?;
      final assignedToMe = arguments['assigned_to_me'] as bool? ?? false;
      final assignedToTeamMember = arguments['assigned_to_team_member'] as String?;

      String? teamMemberId;
      if (assignedToTeamMember != null && assignedToTeamMember.isNotEmpty) {
        final uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
        if (uuid.hasMatch(assignedToTeamMember)) {
          teamMemberId = assignedToTeamMember;
        } else {
          var match = _teamMembers.firstWhere(
            (m) => m['full_name'].toString().toLowerCase() == assignedToTeamMember.toLowerCase(),
            orElse: () => {},
          );
          if (match.isEmpty) {
            match = _teamMembers.firstWhere(
              (m) => m['full_name'].toString().toLowerCase().contains(assignedToTeamMember.toLowerCase()),
              orElse: () => {},
            );
          }
          if (match.isNotEmpty && match['id'] != null) teamMemberId = match['id'];
        }
      }

      List<Map<String, dynamic>> tickets;
      if (teamMemberId != null) {
        tickets = await _supabaseService.getTickets(
          filterByAssignment: false,
          filterByStatus: status != null && status != 'all' ? status : null,
          filterByPriority: priority != null && priority != 'all' ? priority : null,
        );
        tickets = tickets.where((t) => t['assigned_to'] == teamMemberId).toList();
      } else {
        tickets = await _supabaseService.getTickets(
          filterByAssignment: assignedToMe,
          filterByStatus: status != null && status != 'all' ? status : null,
          filterByPriority: priority != null && priority != 'all' ? priority : null,
        );
      }

      if (mounted) setState(() => _userTickets = tickets);
      return {'success': true, 'tickets': tickets, 'count': tickets.length};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _modifyItem(Map<String, dynamic> arguments) async {
    try {
      if (!_supabaseService.isInitialized) return {'success': false, 'error': 'Service not initialized'};

      final itemType = arguments['item_type'] as String;
      final itemId = arguments['item_id'] as String;
      final status = arguments['status'] as String?;
      final priority = arguments['priority'] as String?;
      final meetingDate = arguments['meeting_date'] as String?;
      final title = arguments['title'] as String?;
      final description = arguments['description'] as String?;

      Map<String, dynamic> result = {'success': false, 'error': 'No changes made'};

      switch (itemType) {
        case 'task':
          if (status != null) {
            result = await _supabaseService.updateTaskStatus(taskId: itemId, status: status);
          }
          break;

        case 'ticket':
          if (status != null) {
            result = await _supabaseService.updateTicketStatus(ticketId: itemId, status: status);
          } else if (priority != null) {
            result = await _supabaseService.updateTicketPriority(ticketId: itemId, priority: priority);
          }
          break;

        case 'meeting':
          final meetingDetails = await _supabaseService.getMeetingDetails(itemId);
          if (meetingDetails != null) {
            final updatedMeeting = await _supabaseService.updateMeeting(
              meetingId: itemId,
              title: title ?? meetingDetails['title'],
              description: description ?? meetingDetails['description'],
              meetingDate: meetingDate != null ? DateTime.parse(meetingDate) : DateTime.parse(meetingDetails['meeting_date']),
              meetingUrl: meetingDetails['meeting_url'],
            );
            result = updatedMeeting;
          }
          break;

        default:
          return {'success': false, 'error': 'Invalid item type'};
      }

      if (result['success'] == true) {
        _loadUserTasksAndTickets();
      }
      return result;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  String _getCardType(String functionName) {
    switch (functionName) {
      case 'create_task':
        return 'task';
      case 'create_ticket':
        return 'ticket';
      case 'create_meeting':
        return 'meeting';
      default:
        return 'generic';
    }
  }

  String _getCardText(String functionName, Map<String, dynamic> arguments, Map<String, dynamic> result) {
    switch (functionName) {
      case 'create_task':
      case 'create_ticket':
      case 'create_meeting':
        return arguments['title'] ?? 'Created';
      default:
        return 'Item created';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // FIXED: Race condition in speech listening
  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available on this device')),
      );
      return;
    }

    if (_speech.isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
      return;
    }

    if (!mounted) return;

    // set BEFORE dialog to avoid race
    setState(() => _isListening = true);

    _isListeningDialogOpen = true; // Mark dialog as open
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _buildListeningDialog(),
    ).then((_) async {
      _isListeningDialogOpen = false; // Mark dialog as closed
      
      // Always stop speech when dialog closes
      if (_speech.isListening) {
        await _speech.stop();
      }
      if (mounted) setState(() => _isListening = false);
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _messageController.text = result.recognizedWords);
      },
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: true,
    );
  }

  Widget _buildListeningDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 200,
        height: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.contain,
                child: AnimatedBuilder(
                  animation: _waveformController,
                  builder: (context, child) {
                    return Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green.withOpacity(0.1),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 100 * _waveformController.value,
                            height: 100 * _waveformController.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green.withOpacity(0.2 * (1 - _waveformController.value)),
                            ),
                          ),
                          Container(
                            width: 70 * _waveformController.value,
                            height: 70 * _waveformController.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green.withOpacity(0.3 * (1 - _waveformController.value)),
                            ),
                          ),
                          Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green,
                            ),
                            child: const Icon(Icons.mic, color: Colors.white, size: 24),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Listening...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Tap anywhere to cancel', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _waveformController.dispose();
    if (_speechAvailable && _speech.isListening) _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildChatList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy, color: Colors.green),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Chat with Ell-ena',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Your AI Assistant', style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.info_outline, color: Colors.green, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade700),
            const SizedBox(height: 16),
            Text('Start a conversation with Ell-ena',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isProcessing ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isProcessing && index == _messages.length) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(20),
              ),
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: Colors.green,
                size: 24,
              ),
            ),
          );
        }

        final message = _messages[index];
        if (message.isCard == true) {
          return _ItemCard(message: message, onViewItem: () => _navigateToItem(message));
        }
        return _ChatBubble(message: message);
      },
    );
  }

  void _navigateToItem(ChatMessage message) {
    try {
      if (message.cardType == 'task' && message.cardData?['task'] != null) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => TaskDetailScreen(taskId: message.cardData!['task']['id']),
        ));
      } else if (message.cardType == 'ticket' && message.cardData?['ticket'] != null) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => TicketDetailScreen(ticketId: message.cardData!['ticket']['id']),
        ));
      } else if (message.cardType == 'meeting' && message.cardData?['meeting'] != null) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => MeetingDetailScreen(meetingId: message.cardData!['meeting']['id']),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not navigate to the item. Details missing.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navigation error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _toggleListening,
              icon: Icon(_isListening ? Icons.stop : Icons.mic),
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _isProcessing ? null : _sendMessage,
              icon: const Icon(Icons.send),
              color: Colors.white,
            ),
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) _buildAvatar(isUser: false),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.green : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _buildFormattedText(message.text),
            ),
          ),
          const SizedBox(width: 8),
          if (message.isUser) _buildAvatar(isUser: true),
        ],
      ),
    );
  }

  Widget _buildFormattedText(String text) {
    final containsFormatting = text.contains('*') || text.contains('•') || text.contains('📅') || text.contains('🕒');

    if (!containsFormatting) return Text(text, style: const TextStyle(color: Colors.white));

    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      if (line.startsWith('*') && line.endsWith('*')) {
        final content = line.substring(1, line.length - 1).trim();
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(content, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ));
      } else if (line.startsWith('•')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4, left: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(child: Text(line.substring(1).trim(), style: const TextStyle(color: Colors.white))),
            ],
          ),
        ));
      } else if (line.startsWith('📅') || line.startsWith('🕒')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            line,
            style: TextStyle(
              color: Colors.white,
              fontWeight: line.startsWith('📅') ? FontWeight.bold : FontWeight.normal,
              fontSize: line.startsWith('📅') ? 16 : 14,
            ),
          ),
        ));
      } else if (line.contains('*')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(line.replaceAll('*', ''),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ));
      } else if (line.startsWith('---')) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(height: 1, color: Colors.grey.shade600),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(line, style: const TextStyle(color: Colors.white)),
        ));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _buildAvatar({required bool isUser}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isUser ? Colors.green.shade700 : Colors.grey.shade700,
        shape: BoxShape.circle,
        border: Border.all(color: isUser ? Colors.green.shade300 : Colors.grey.shade500, width: 1),
      ),
      child: Center(
        child: Icon(isUser ? Icons.person : Icons.smart_toy, color: Colors.white, size: 20),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onViewItem;

  const _ItemCard({required this.message, required this.onViewItem});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String title;

    switch (message.cardType) {
      case 'task':
        icon = Icons.task_alt;
        title = 'New Task';
        break;
      case 'ticket':
        icon = Icons.confirmation_number;
        title = 'New Ticket';
        break;
      case 'meeting':
        icon = Icons.calendar_today;
        title = 'New Meeting';
        break;
      default:
        icon = Icons.check_circle;
        title = 'Item Created';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (message.cardType == 'meeting' && message.cardData?['meeting'] != null)
                  Text(_formatDate(message.cardData!['meeting']['meeting_date']),
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12))
                else
                  Text('Created just now', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.text, style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onViewItem,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View ${message.cardType?.capitalize() ?? 'Item'}',
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward, color: Colors.green, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM d, yyyy • h:mm a').format(date);
    } catch (_) {
      return '';
    }
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isCard;
  final String? cardType;
  final Map<String, dynamic>? cardData;
  final String? avatarUrl;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isCard = false,
    this.cardType,
    this.cardData,
    this.avatarUrl,
  });
}

// FIXED: Added null-safety check for empty strings
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}