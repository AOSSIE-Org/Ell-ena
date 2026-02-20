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
  bool _isProcessing = false;
  bool _isListening = false; // toggles mic icon state
  late AnimationController _waveformController;
  late final stt.SpeechToText _speech;
  bool _speechAvailable = false;

  // Services
  final AIService _aiService = AIService();
  final SupabaseService _supabaseService = SupabaseService();

  // Team members for assignment
  List<Map<String, dynamic>> _teamMembers = [];
  List<Map<String, dynamic>> _userTasks = [];
  List<Map<String, dynamic>> _userTickets = [];

  @override
  void initState() {
    super.initState();
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _initializeServices();
    _initSpeech();

    // Handle initial message if provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.arguments != null &&
          widget.arguments!.containsKey('initial_message') &&
          widget.arguments!['initial_message'] is String) {
        // Set a small delay to ensure services are initialized
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _messageController.text =
                widget.arguments!['initial_message'] as String;
            _sendMessage();
          }
        });
      }
    });
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() => _isListening = false);
            // Dismiss dialog if open
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          }
        }
      },
      onError: (error) {
        setState(() => _isListening = false);
        if (mounted) {
          setState(() => _isListening = false);
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      },
    );

    if (mounted) setState(() {});
  }

  Future<void> _initializeServices() async {
    try {
      if (!_aiService.isInitialized) {
        await _aiService.initialize();
      }

      if (!_supabaseService.isInitialized) {
        await _supabaseService.initialize();
      }

      if (_supabaseService.isInitialized) {
        final userProfile = await _supabaseService.getCurrentUserProfile();
        if (userProfile != null && userProfile['team_id'] != null) {
          await _loadTeamMembers(userProfile['team_id']);

          await _loadUserTasksAndTickets();
        }
      }

      setState(() {
        _messages.add(
          ChatMessage(
            text:
                "Hello! I'm Ell-ena, your AI assistant. How can I help you today?",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } catch (e) {
      debugPrint('Error initializing services: $e');
    }
  }

  Future<void> _loadTeamMembers(String teamId) async {
    try {
      final members = await _supabaseService.getTeamMembers(teamId);
      if (mounted) {
        setState(() {
          _teamMembers = members;
        });
      }
    } catch (e) {
      debugPrint('Error loading team members: $e');
    }
  }

  Future<void> _loadUserTasksAndTickets() async {
    try {
      final tasks = await _supabaseService.getTasks(filterByAssignment: true);

      final tickets =
          await _supabaseService.getTickets(filterByAssignment: true);

      if (mounted) {
        setState(() {
          _userTasks = tasks;
          _userTickets = tickets;
        });
      }
    } catch (e) {
      debugPrint('Error loading user tasks and tickets: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _waveformController.dispose();
    if (_speechAvailable && _speech.isListening) {
      _speech.stop();
    }
    super.dispose();
  }

  // Build the listening animation dialog
  Widget _buildListeningDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 200,
        height: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Sound wave animation
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
                          // Outer ripple
                          Container(
                            width: 100 * _waveformController.value,
                            height: 100 * _waveformController.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green.withOpacity(
                                  0.2 * (1 - _waveformController.value)),
                            ),
                          ),
                          // Middle ripple
                          Container(
                            width: 70 * _waveformController.value,
                            height: 70 * _waveformController.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green.withOpacity(
                                  0.3 * (1 - _waveformController.value)),
                            ),
                          ),
                          // Inner circle with mic icon
                          Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green,
                            ),
                            child: const Icon(
                              Icons.mic,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Listening...',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap anywhere to cancel',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    if (_isProcessing) return;

    final userMessage = _messageController.text;
    _messageController.clear();

    setState(() {
      _messages.add(
        ChatMessage(text: userMessage, isUser: true, timestamp: DateTime.now()),
      );
      _isProcessing = true;
    });

    _scrollToBottom();

    try {
      final chatHistory = _getChatHistoryForAI();

      final response = await _aiService.generateChatResponse(
        userMessage,
        chatHistory,
        _teamMembers,
        userTasks: _userTasks,
        userTickets: _userTickets,
      );

      if (response['type'] == 'function_call') {
        await _handleFunctionCall(
          response['function_name'],
          response['arguments'],
          response['raw_response'],
        );
      } else {
        setState(() {
          _messages.add(
            ChatMessage(
              text: response['content'],
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      setState(() {
        _messages.add(
          ChatMessage(
            text: "Sorry, I encountered an error. Please try again later.",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isProcessing = false;
      });
    }

    _scrollToBottom();
  }

  List<Map<String, String>> _getChatHistoryForAI() {
    final recentMessages = _messages.length > 10
        ? _messages.sublist(_messages.length - 10)
        : _messages;

    return recentMessages.map((message) {
      return {
        "role": message.isUser ? "user" : "assistant",
        "content": message.text,
      };
    }).toList();
  }

  Future<void> _handleFunctionCall(
    String functionName,
    Map<String, dynamic> arguments,
    String rawResponse,
  ) async {
    setState(() {
      _messages.add(
        ChatMessage(
          text: "I'll help you with that. Let me process your request...",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });

    _scrollToBottom();

    try {
      Map<String, dynamic> result = {
        'success': false,
        'error': 'Function not implemented'
      };

      // Execute the appropriate function based on the function name
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

      // Get a user-friendly response from the AI
      final responseMessage = await _aiService.handleToolResponse(
        functionName: functionName,
        arguments: arguments,
        rawResponse: rawResponse,
        result: result,
      );

      // Add the response to the chat
      setState(() {
        _messages.add(
          ChatMessage(
            text: responseMessage,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );

        // Add card if successful for creation functions
        if (result['success'] == true &&
            (functionName == 'create_task' ||
                functionName == 'create_ticket' ||
                functionName == 'create_meeting')) {
          _messages.add(
            ChatMessage(
              text: _getCardText(functionName, arguments, result),
              isUser: false,
              timestamp: DateTime.now(),
              isCard: true,
              cardType: _getCardType(functionName),
              cardData: result,
            ),
          );
        }

        _isProcessing = false;
      });

      // Refresh tasks and tickets if we just queried them
      if (functionName == 'query_tasks' || functionName == 'query_tickets') {
        _loadUserTasksAndTickets();
      }
    } catch (e) {
      debugPrint('Error handling function call: $e');
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                "Sorry, I encountered an error while processing your request.",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isProcessing = false;
      });
    }

    _scrollToBottom();
  }

  // Create a task using the Supabase service
  Future<Map<String, dynamic>> _createTask(
      Map<String, dynamic> arguments) async {
    try {
      if (!_supabaseService.isInitialized) {
        return {'success': false, 'error': 'Service not initialized'};
      }

      final title = arguments['title'] as String;
      final description = arguments['description'] as String?;

      // Parse due date if provided
      DateTime? dueDate;
      if (arguments['due_date'] != null) {
        try {
          dueDate = DateTime.parse(arguments['due_date']);
        } catch (e) {
          debugPrint('Error parsing due date: $e');
        }
      }

      // Get assigned user ID if provided
      String? assignedToUserId;
      final assignedTo = arguments['assigned_to'] as String?;

      if (assignedTo != null && assignedTo.isNotEmpty) {
        // Check if the value is already a valid UUID
        final uuidPattern = RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            caseSensitive: false);

        if (uuidPattern.hasMatch(assignedTo)) {
          // It's already a UUID
          assignedToUserId = assignedTo;
        } else {
          // Try to find the user by name
          final matchingMember = _teamMembers.firstWhere(
            (member) =>
                member['full_name'].toString().toLowerCase() ==
                assignedTo.toLowerCase(),
            orElse: () => {},
          );

          if (matchingMember.isNotEmpty && matchingMember['id'] != null) {
            assignedToUserId = matchingMember['id'];
          }
        }
      }

      // Create the task
      final result = await _supabaseService.createTask(
        title: title,
        description: description,
        dueDate: dueDate,
        assignedToUserId: assignedToUserId,
      );

      return result;
    } catch (e) {
      debugPrint('Error creating task: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Create a ticket using the Supabase service
  Future<Map<String, dynamic>> _createTicket(
      Map<String, dynamic> arguments) async {
    try {
      if (!_supabaseService.isInitialized) {
        return {'success': false, 'error': 'Service not initialized'};
      }

      final title = arguments['title'] as String;
      final description = arguments['description'] as String?;
      final priority = arguments['priority'] as String;
      final category = arguments['category'] as String;

      // Get assigned user ID if provided
      String? assignedToUserId;
      final assignedTo = arguments['assigned_to'] as String?;

      if (assignedTo != null && assignedTo.isNotEmpty) {
        // Check if the value is already a valid UUID
        final uuidPattern = RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            caseSensitive: false);

        if (uuidPattern.hasMatch(assignedTo)) {
          // It's already a UUID
          assignedToUserId = assignedTo;
        } else {
          // Try to find the user by name
          final matchingMember = _teamMembers.firstWhere(
            (member) =>
                member['full_name'].toString().toLowerCase() ==
                assignedTo.toLowerCase(),
            orElse: () => {},
          );

          if (matchingMember.isNotEmpty && matchingMember['id'] != null) {
            assignedToUserId = matchingMember['id'];
          }
        }
      }

      // Create the ticket
      final result = await _supabaseService.createTicket(
        title: title,
        description: description,
        priority: priority,
        category: category,
        assignedToUserId: assignedToUserId,
      );

      return result;
    } catch (e) {
      debugPrint('Error creating ticket: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Create a meeting using the Supabase service
  Future<Map<String, dynamic>> _createMeeting(
      Map<String, dynamic> arguments) async {
    try {
      if (!_supabaseService.isInitialized) {
        return {'success': false, 'error': 'Service not initialized'};
      }

      final title = arguments['title'] as String;
      final description = arguments['description'] as String?;

      // Parse meeting date
      DateTime meetingDate;
      try {
        meetingDate = DateTime.parse(arguments['meeting_date']);
      } catch (e) {
        debugPrint('Error parsing meeting date: $e');
        return {'success': false, 'error': 'Invalid meeting date format'};
      }

      final meetingUrl = arguments['meeting_url'] as String?;

      // Create the meeting
      final result = await _supabaseService.createMeeting(
        title: title,
        description: description,
        meetingDate: meetingDate,
        meetingUrl: meetingUrl,
      );

      return result;
    } catch (e) {
      debugPrint('Error creating meeting: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Query tasks based on filters
  Future<Map<String, dynamic>> _queryTasks(
      Map<String, dynamic> arguments) async {
    try {
      if (!_supabaseService.isInitialized) {
        return {'success': false, 'error': 'Service not initialized'};
      }

      final status = arguments['status'] as String?;
      final dueDate = arguments['due_date'] as String?;
      final assignedToMe = arguments['assigned_to_me'] as bool? ?? false;
      final assignedToTeamMember =
          arguments['assigned_to_team_member'] as String?;

      // Find team member ID if name was provided
      String? teamMemberId;
      if (assignedToTeamMember != null && assignedToTeamMember.isNotEmpty) {
        // Check if it's already a UUID
        final uuidPattern = RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            caseSensitive: false);

        if (uuidPattern.hasMatch(assignedToTeamMember)) {
          teamMemberId = assignedToTeamMember;
        } else {
          // Try to find by name - more flexible matching
          // First try exact match
          var matchingMember = _teamMembers.firstWhere(
            (member) =>
                member['full_name'].toString().toLowerCase() ==
                assignedToTeamMember.toLowerCase(),
            orElse: () => {},
          );

          // If no exact match, try partial match
          if (matchingMember.isEmpty) {
            matchingMember = _teamMembers.firstWhere(
              (member) => member['full_name']
                  .toString()
                  .toLowerCase()
                  .contains(assignedToTeamMember.toLowerCase()),
              orElse: () => {},
            );
          }

          // Try matching first name only
          if (matchingMember.isEmpty) {
            for (var member in _teamMembers) {
              final fullName = member['full_name'].toString().toLowerCase();
              final firstName = fullName.split(' ').first;
              if (firstName == assignedToTeamMember.toLowerCase()) {
                matchingMember = member;
                break;
              }
            }
          }

          if (matchingMember.isNotEmpty && matchingMember['id'] != null) {
            teamMemberId = matchingMember['id'];
            debugPrint(
                'Found team member: ${matchingMember['full_name']} with ID: $teamMemberId');
          } else {
            debugPrint(
                'Could not find team member with name: $assignedToTeamMember');
            debugPrint(
                'Available team members: ${_teamMembers.map((m) => m['full_name']).join(', ')}');
          }
        }
      }

      // Get tasks with filters
      List<Map<String, dynamic>> tasks;

      if (teamMemberId != null) {
        // For team member queries, we need to manually filter results
        tasks = await _supabaseService.getTasks(
          filterByAssignment: false, // Don't filter by current user
          filterByStatus: status != null && status != 'all' ? status : null,
          filterByDueDate: dueDate,
        );

        // Filter by assigned team member
        tasks =
            tasks.where((task) => task['assigned_to'] == teamMemberId).toList();
      } else {
        tasks = await _supabaseService.getTasks(
          filterByAssignment: assignedToMe,
          filterByStatus: status != null && status != 'all' ? status : null,
          filterByDueDate: dueDate,
        );
      }

      // Update local cache
      if (mounted) {
        setState(() {
          _userTasks = tasks;
        });
      }

      return {
        'success': true,
        'tasks': tasks,
        'count': tasks.length,
      };
    } catch (e) {
      debugPrint('Error querying tasks: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Query tickets based on filters
  Future<Map<String, dynamic>> _queryTickets(
      Map<String, dynamic> arguments) async {
    try {
      if (!_supabaseService.isInitialized) {
        return {'success': false, 'error': 'Service not initialized'};
      }

      final status = arguments['status'] as String?;
      final priority = arguments['priority'] as String?;
      final assignedToMe = arguments['assigned_to_me'] as bool? ?? false;
      final assignedToTeamMember =
          arguments['assigned_to_team_member'] as String?;

      // Find team member ID if name was provided
      String? teamMemberId;
      if (assignedToTeamMember != null && assignedToTeamMember.isNotEmpty) {
        // Check if it's already a UUID
        final uuidPattern = RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            caseSensitive: false);

        if (uuidPattern.hasMatch(assignedToTeamMember)) {
          teamMemberId = assignedToTeamMember;
        } else {
          // Try to find by name - more flexible matching
          // First try exact match
          var matchingMember = _teamMembers.firstWhere(
            (member) =>
                member['full_name'].toString().toLowerCase() ==
                assignedToTeamMember.toLowerCase(),
            orElse: () => {},
          );

          // If no exact match, try partial match
          if (matchingMember.isEmpty) {
            matchingMember = _teamMembers.firstWhere(
              (member) => member['full_name']
                  .toString()
                  .toLowerCase()
                  .contains(assignedToTeamMember.toLowerCase()),
              orElse: () => {},
            );
          }

          // Try matching first name only
          if (matchingMember.isEmpty) {
            for (var member in _teamMembers) {
              final fullName = member['full_name'].toString().toLowerCase();
              final firstName = fullName.split(' ').first;
              if (firstName == assignedToTeamMember.toLowerCase()) {
                matchingMember = member;
                break;
              }
            }
          }

          if (matchingMember.isNotEmpty && matchingMember['id'] != null) {
            teamMemberId = matchingMember['id'];
            debugPrint(
                'Found team member: ${matchingMember['full_name']} with ID: $teamMemberId');
          } else {
            debugPrint(
                'Could not find team member with name: $assignedToTeamMember');
            debugPrint(
                'Available team members: ${_teamMembers.map((m) => m['full_name']).join(', ')}');
          }
        }
      }

      // Get tickets with filters
      List<Map<String, dynamic>> tickets;

      if (teamMemberId != null) {
        // For team member queries, we need to manually filter results
        tickets = await _supabaseService.getTickets(
          filterByAssignment: false, // Don't filter by current user
          filterByStatus: status != null && status != 'all' ? status : null,
          filterByPriority:
              priority != null && priority != 'all' ? priority : null,
        );

        // Filter by assigned team member
        tickets = tickets
            .where((ticket) => ticket['assigned_to'] == teamMemberId)
            .toList();
      } else {
        tickets = await _supabaseService.getTickets(
          filterByAssignment: assignedToMe,
          filterByStatus: status != null && status != 'all' ? status : null,
          filterByPriority:
              priority != null && priority != 'all' ? priority : null,
        );
      }

      // Update local cache
      if (mounted) {
        setState(() {
          _userTickets = tickets;
        });
      }

      return {
        'success': true,
        'tickets': tickets,
        'count': tickets.length,
      };
    } catch (e) {
      debugPrint('Error querying tickets: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Modify an existing task, ticket, or meeting
  Future<Map<String, dynamic>> _modifyItem(
      Map<String, dynamic> arguments) async {
    try {
      if (!_supabaseService.isInitialized) {
        return {'success': false, 'error': 'Service not initialized'};
      }

      final itemType = arguments['item_type'] as String;
      final itemId = arguments['item_id'] as String;
      final title = arguments['title'] as String?;
      final description = arguments['description'] as String?;
      final status = arguments['status'] as String?;
      final dueDate = arguments['due_date'] as String?;
      final priority = arguments['priority'] as String?;
      final meetingDate = arguments['meeting_date'] as String?;
      final assignedTo = arguments['assigned_to'] as String?;

      // Get assigned user ID if provided
      String? assignedToUserId;
      if (assignedTo != null && assignedTo.isNotEmpty) {
        // Check if the value is already a valid UUID
        final uuidPattern = RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            caseSensitive: false);

        if (uuidPattern.hasMatch(assignedTo)) {
          // It's already a UUID
          assignedToUserId = assignedTo;
        } else {
          // Try to find by name - more flexible matching
          // First try exact match
          var matchingMember = _teamMembers.firstWhere(
            (member) =>
                member['full_name'].toString().toLowerCase() ==
                assignedTo.toLowerCase(),
            orElse: () => {},
          );

          // If no exact match, try partial match
          if (matchingMember.isEmpty) {
            matchingMember = _teamMembers.firstWhere(
              (member) => member['full_name']
                  .toString()
                  .toLowerCase()
                  .contains(assignedTo.toLowerCase()),
              orElse: () => {},
            );
          }

          // Try matching first name only
          if (matchingMember.isEmpty) {
            for (var member in _teamMembers) {
              final fullName = member['full_name'].toString().toLowerCase();
              final firstName = fullName.split(' ').first;
              if (firstName == assignedTo.toLowerCase()) {
                matchingMember = member;
                break;
              }
            }
          }

          if (matchingMember.isNotEmpty && matchingMember['id'] != null) {
            assignedToUserId = matchingMember['id'];
            debugPrint(
                'Found team member: ${matchingMember['full_name']} with ID: $assignedToUserId');
          } else {
            debugPrint('Could not find team member with name: $assignedTo');
            debugPrint(
                'Available team members: ${_teamMembers.map((m) => m['full_name']).join(', ')}');
          }
        }
      }

      // Prepare update data based on item type
      Map<String, dynamic> updateData = {};

      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (status != null) updateData['status'] = status;
      if (assignedToUserId != null)
        updateData['assigned_to'] = assignedToUserId;

      // Add type-specific fields
      switch (itemType) {
        case 'task':
          if (dueDate != null) {
            try {
              final parsedDate = DateTime.parse(dueDate);
              updateData['due_date'] = parsedDate.toIso8601String();
            } catch (e) {
              return {'success': false, 'error': 'Invalid due date format'};
            }
          }
          break;

        case 'ticket':
          if (priority != null) updateData['priority'] = priority;
          break;

        case 'meeting':
          if (meetingDate != null) {
            try {
              final parsedDate = DateTime.parse(meetingDate);
              updateData['meeting_date'] = parsedDate.toIso8601String();
            } catch (e) {
              return {'success': false, 'error': 'Invalid meeting date format'};
            }
          }
          break;

        default:
          return {'success': false, 'error': 'Invalid item type'};
      }

      if (updateData.isEmpty) {
        return {'success': false, 'error': 'No changes specified'};
      }

      // Update the item in the database
      Map<String, dynamic> result = {
        'success': false,
        'error': 'No changes made'
      };

      switch (itemType) {
        case 'task':
          // For tasks, we need to handle different update methods based on what's changing
          if (status != null) {
            result = await _supabaseService.updateTaskStatus(
              taskId: itemId,
              status: status,
            );
          }

          // Handle other task updates as needed
          // Note: This is a simplified implementation - for a complete solution,
          // you would need to add methods to SupabaseService to handle all fields

          break;

        case 'ticket':
          // For tickets, we need to handle different update methods based on what's changing
          if (status != null) {
            result = await _supabaseService.updateTicketStatus(
              ticketId: itemId,
              status: status,
            );
          } else if (priority != null) {
            result = await _supabaseService.updateTicketPriority(
              ticketId: itemId,
              priority: priority,
            );
          }

          // Handle other ticket updates as needed

          break;

        case 'meeting':
          // For meetings, we need to get the current meeting details first
          final meetingDetails =
              await _supabaseService.getMeetingDetails(itemId);
          if (meetingDetails != null) {
            // Update with new values, keeping existing ones if not provided
            final updatedMeeting = await _supabaseService.updateMeeting(
              meetingId: itemId,
              title: title ?? meetingDetails['title'],
              description: description ?? meetingDetails['description'],
              meetingDate: meetingDate != null
                  ? DateTime.parse(meetingDate)
                  : DateTime.parse(meetingDetails['meeting_date']),
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
      debugPrint('Error modifying item: $e');
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

  // Get card text based on function name and arguments
  String _getCardText(String functionName, Map<String, dynamic> arguments,
      Map<String, dynamic> result) {
    switch (functionName) {
      case 'create_task':
        return arguments['title'] ?? 'New Task';
      case 'create_ticket':
        return arguments['title'] ?? 'New Ticket';
      case 'create_meeting':
        return arguments['title'] ?? 'New Meeting';
      default:
        return 'Item created';
    }
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

  void _navigateToItem(ChatMessage message) {
    try {
      if (message.cardType == 'task' &&
          message.cardData != null &&
          message.cardData!['task'] != null) {
        // Navigate to task detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TaskDetailScreen(taskId: message.cardData!['task']['id']),
          ),
        );
      } else if (message.cardType == 'ticket' &&
          message.cardData != null &&
          message.cardData!['ticket'] != null) {
        // Navigate to ticket detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TicketDetailScreen(ticketId: message.cardData!['ticket']['id']),
          ),
        );
      } else if (message.cardType == 'meeting' &&
          message.cardData != null &&
          message.cardData!['meeting'] != null) {
        // Navigate to meeting detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MeetingDetailScreen(
                meetingId: message.cardData!['meeting']['id']),
          ),
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not navigate to the item. Details missing.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error navigating to item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigation error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Speech recognition not available on this device')),
      );
      return;
    }
    if (_speech.isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    // Show the listening animation dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => _buildListeningDialog(),
      ).then((_) {
        // Stop listening if dialog was dismissed
        if (_isListening && _speech.isListening) {
          _speech.stop();
          setState(() => _isListening = false);
        }
      });
    }

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _messageController.text = result.recognizedWords;
        });
      },
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: true,
      onSoundLevelChange: (level) {
        // You can use this to update animation intensity if needed
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.2),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Chat with Ell-ena',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Your AI Assistant',
                        style: TextStyle(
                            color: colorScheme.onSurfaceVariant, fontSize: 14),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation with Ell-ena',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isProcessing ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isProcessing && index == _messages.length) {
                        // Show typing indicator
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant,
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
                        return _ItemCard(
                          message: message,
                          onViewItem: () => _navigateToItem(message),
                        );
                      }
                      return _ChatBubble(message: message);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: colorScheme.onSurface),
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle:
                            TextStyle(color: colorScheme.onSurfaceVariant),
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
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleTextColor =
        message.isUser ? Colors.white : colorScheme.onSurface;
    final bubbleColor =
        message.isUser ? Colors.green : colorScheme.surfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) _buildAvatar(context, isUser: false),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child:
                  _buildFormattedText(context, message.text, bubbleTextColor),
            ),
          ),
          const SizedBox(width: 8),
          if (message.isUser) _buildAvatar(context, isUser: true),
        ],
      ),
    );
  }

  // Build formatted text that handles markdown-like formatting
  Widget _buildFormattedText(
      BuildContext context, String text, Color textColor) {
    // Check if text contains formatting indicators
    final containsFormatting = text.contains('*') ||
        text.contains('•') ||
        text.contains('📅') ||
        text.contains('🕒');

    if (!containsFormatting) {
      // Simple text without formatting
      return Text(text, style: TextStyle(color: textColor));
    }

    // Split the text by lines to handle each line separately
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Handle empty lines
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Handle headers (lines with asterisks)
      if (line.startsWith('*') && line.endsWith('*')) {
        final content = line.substring(1, line.length - 1).trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              content,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      }
      // Handle bullet points
      else if (line.startsWith('•')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•',
                    style: TextStyle(
                        color: textColor, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line.substring(1).trim(),
                    style: TextStyle(color: textColor),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // Handle emoji indicators (like meeting date/time)
      else if (line.startsWith('📅') || line.startsWith('🕒')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: TextStyle(
                color: textColor,
                fontWeight:
                    line.startsWith('📅') ? FontWeight.bold : FontWeight.normal,
                fontSize: line.startsWith('📅') ? 16 : 14,
              ),
            ),
          ),
        );
      }
      // Handle section headers (lines with asterisks like *Key Points:*)
      else if (line.contains('*')) {
        // Replace asterisks with empty string and make bold
        final content = line.replaceAll('*', '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              content,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
      // Handle separator lines
      else if (line.startsWith('---')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              height: 1,
              color: Theme.of(context).dividerColor,
            ),
          ),
        );
      }
      // Regular text
      else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: TextStyle(color: textColor),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildAvatar(BuildContext context, {required bool isUser}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isUser ? Colors.green.shade700 : colorScheme.surfaceVariant,
        shape: BoxShape.circle,
        border: Border.all(
          color: isUser ? Colors.green.shade300 : colorScheme.outline,
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          isUser ? Icons.person : Icons.smart_toy,
          color: isUser ? Colors.white : colorScheme.onSurface,
          size: 20,
        ),
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
    // Set icon and title based on card type
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

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (message.cardType == 'task' || message.cardType == 'ticket')
                  Text(
                    'Created just now',
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                if (message.cardType == 'meeting' &&
                    message.cardData != null &&
                    message.cardData!['meeting'] != null)
                  Text(
                    _formatDate(message.cardData!['meeting']['meeting_date']),
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onViewItem,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.green.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View ${message.cardType?.capitalize() ?? 'Item'}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward,
                            color: Colors.green,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';

    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM d, yyyy • h:mm a').format(date);
    } catch (e) {
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
  final String? avatarUrl; // Add avatar URL for profile pictures

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

// Extension to capitalize first letter of a string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
