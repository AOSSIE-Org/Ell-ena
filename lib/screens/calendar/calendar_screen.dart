import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../tasks/create_task_screen.dart';
import '../tickets/create_ticket_screen.dart';
import '../meetings/create_meeting_screen.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_widgets.dart';
import '../meetings/meeting_detail_screen.dart';
import '../tasks/task_detail_screen.dart';
import '../tickets/ticket_detail_screen.dart';
import '../chat/chat_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  TimeOfDay? _selectedTime;
  final Map<DateTime, List<CalendarEvent>> _events = {};
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  String? _currentUserId;
  bool _isAdmin = false;

  // Cache keys
  static const String _tasksKey = 'calendar_tasks';
  static const String _ticketsKey = 'calendar_tickets';
  static const String _meetingsKey = 'calendar_meetings';
  static const String _lastFetchTimeKey = 'calendar_last_fetch_time';

  // Cache duration (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadCurrentUserInfo();
  }

  Future<void> _loadCurrentUserInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userProfile = await _supabaseService.getCurrentUserProfile();
      if (userProfile != null) {
        _currentUserId = _supabaseService.client.auth.currentUser?.id;
        _isAdmin = userProfile['role'] == 'admin';
      }

      await _loadEventsWithCache();
    } catch (e) {
      debugPrint('Error loading user info: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Check if cache is valid
  Future<bool> _isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFetchTimeStr = prefs.getString(_lastFetchTimeKey);

      if (lastFetchTimeStr == null) return false;

      final lastFetchTime = DateTime.parse(lastFetchTimeStr);
      final now = DateTime.now();

      return now.difference(lastFetchTime) < _cacheDuration;
    } catch (e) {
      debugPrint('Error checking cache validity: $e');
      return false;
    }
  }

  // Load events from cache or network
  Future<void> _loadEventsWithCache() async {
    try {
      if (!mounted) return;

      setState(() {
        _isLoading = true;
      });

      // Clear existing events
      _events.clear();

      // Check if cache is valid
      final isCacheValid = await _isCacheValid();

      if (isCacheValid) {
        // Load from cache
        await _loadEventsFromCache();
      } else {
        // Load from network
        await _loadEventsFromNetwork();

        // Save to cache
        await _saveEventsToCache();
      }
    } catch (e) {
      debugPrint('Error loading events with cache: $e');
      // Fallback to network if cache fails
      await _loadEventsFromNetwork();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Load events from SharedPreferences cache
  Future<void> _loadEventsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load tasks
      final tasksJson = prefs.getString(_tasksKey);
      if (tasksJson != null) {
        final tasks = List<Map<String, dynamic>>.from(
            jsonDecode(tasksJson).map((x) => Map<String, dynamic>.from(x)));
        _processTasksData(tasks);
      }

      // Load tickets
      final ticketsJson = prefs.getString(_ticketsKey);
      if (ticketsJson != null) {
        final tickets = List<Map<String, dynamic>>.from(
            jsonDecode(ticketsJson).map((x) => Map<String, dynamic>.from(x)));
        _processTicketsData(tickets);
      }

      // Load meetings
      final meetingsJson = prefs.getString(_meetingsKey);
      if (meetingsJson != null) {
        final meetings = List<Map<String, dynamic>>.from(
            jsonDecode(meetingsJson).map((x) => Map<String, dynamic>.from(x)));
        _processMeetingsData(meetings);
      }

      debugPrint('Events loaded from cache');
    } catch (e) {
      debugPrint('Error loading events from cache: $e');
      // If cache loading fails, fall back to network
      await _loadEventsFromNetwork();
    }
  }

  // Save events to SharedPreferences cache
  Future<void> _saveEventsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save last fetch time
      await prefs.setString(
          _lastFetchTimeKey, DateTime.now().toIso8601String());

      // Tasks, tickets, and meetings are saved in their respective methods
    } catch (e) {
      debugPrint('Error saving events to cache: $e');
    }
  }

  // Load events from network
  Future<void> _loadEventsFromNetwork() async {
    try {
      // Load tasks, tickets, and meetings in parallel
      final results = await Future.wait([
        _loadTasks(),
        _loadTickets(),
        _loadMeetings(),
      ]);

      debugPrint('Events loaded from network');
    } catch (e) {
      debugPrint('Error loading events from network: $e');
    }
  }

  // Load tasks
  Future<void> _loadTasks() async {
    try {
      final tasks = await _supabaseService.getTasks();

      // Filter tasks for current user (created by or assigned to)
      final filteredTasks = tasks.where((task) {
        final createdBy = task['created_by'];
        final assignedTo = task['assigned_to'];
        return _isAdmin ||
            createdBy == _currentUserId ||
            assignedTo == _currentUserId ||
            assignedTo == null;
      }).toList();

      // Process tasks data
      _processTasksData(filteredTasks);

      // Save to cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tasksKey, jsonEncode(filteredTasks));
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    }
  }

  // Process tasks data
  void _processTasksData(List<Map<String, dynamic>> tasks) {
    for (var task in tasks) {
      if (task['due_date'] != null) {
        final dueDate = DateTime.parse(task['due_date']);
        final dateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);

        if (!_events.containsKey(dateOnly)) {
          _events[dateOnly] = [];
        }

        _events[dateOnly]!.add(CalendarEvent(
          title: task['title'] ?? 'Untitled Task',
          startTime: const TimeOfDay(hour: 23, minute: 0),
          endTime: const TimeOfDay(hour: 23, minute: 59),
          type: EventType.task,
          id: task['id'],
        ));
      }
    }
  }

  // Load tickets
  Future<void> _loadTickets() async {
    try {
      final tickets = await _supabaseService.getTickets();

      // Filter tickets for current user (created by or assigned to)
      final filteredTickets = tickets.where((ticket) {
        final createdBy = ticket['created_by'];
        final assignedTo = ticket['assigned_to'];
        return _isAdmin ||
            createdBy == _currentUserId ||
            assignedTo == _currentUserId ||
            assignedTo == null;
      }).toList();

      // Process tickets data
      _processTicketsData(filteredTickets);

      // Save to cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ticketsKey, jsonEncode(filteredTickets));
    } catch (e) {
      debugPrint('Error loading tickets: $e');
    }
  }

  // Process tickets data
  void _processTicketsData(List<Map<String, dynamic>> tickets) {
    for (var ticket in tickets) {
      if (ticket['created_at'] != null) {
        final createdAt = DateTime.parse(ticket['created_at']);
        final dateOnly =
            DateTime(createdAt.year, createdAt.month, createdAt.day);

        if (!_events.containsKey(dateOnly)) {
          _events[dateOnly] = [];
        }

        _events[dateOnly]!.add(CalendarEvent(
          title: ticket['title'] ?? 'Untitled Ticket',
          startTime: TimeOfDay(hour: createdAt.hour, minute: createdAt.minute),
          endTime:
              TimeOfDay(hour: createdAt.hour + 1, minute: createdAt.minute),
          type: EventType.ticket,
          id: ticket['id'],
        ));
      }
    }
  }

  // Load meetings
  Future<void> _loadMeetings() async {
    try {
      final meetings = await _supabaseService.getMeetings();

      // Process meetings data (all meetings are visible to everyone)
      _processMeetingsData(meetings);

      // Save to cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_meetingsKey, jsonEncode(meetings));
    } catch (e) {
      debugPrint('Error loading meetings: $e');
    }
  }

  // Process meetings data
  void _processMeetingsData(List<Map<String, dynamic>> meetings) {
    for (var meeting in meetings) {
      if (meeting['meeting_date'] != null) {
        final meetingDate = DateTime.parse(meeting['meeting_date']);
        final dateOnly =
            DateTime(meetingDate.year, meetingDate.month, meetingDate.day);

        if (!_events.containsKey(dateOnly)) {
          _events[dateOnly] = [];
        }

        // For meetings, assume 1 hour duration
        _events[dateOnly]!.add(CalendarEvent(
          title: meeting['title'] ?? 'Untitled Meeting',
          startTime:
              TimeOfDay(hour: meetingDate.hour, minute: meetingDate.minute),
          endTime:
              TimeOfDay(hour: meetingDate.hour + 1, minute: meetingDate.minute),
          type: EventType.meeting,
          id: meeting['id'],
        ));
      }
    }
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const CalendarLoadingSkeleton()
          : SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildCalendar(),
                  const SizedBox(height: 12),
                  Expanded(child: _buildTimeScale()),
                ],
              ),
            ),
    );
  }

  Widget _buildCalendar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TableCalendar(
          firstDay: DateTime.utc(2024, 1, 1),
          lastDay: DateTime.utc(2025, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: _getEventsForDay,
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              if (events.isEmpty) return const SizedBox.shrink();
              final isLight = Theme.of(context).brightness == Brightness.light;
              final markerOpacity = isLight ? 0.55 : 0.3;
              return Positioned(
                bottom: 1,
                child: Container(
                  height: 16,
                  width: events.length > 3 ? 35 : (events.length * 8 + 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(markerOpacity),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${events.length}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          calendarStyle: CalendarStyle(
            defaultTextStyle: TextStyle(color: colorScheme.onSurface),
            weekendTextStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            selectedTextStyle: TextStyle(color: colorScheme.onPrimary),
            todayTextStyle: TextStyle(color: colorScheme.onSurface),
            outsideTextStyle:
                TextStyle(color: colorScheme.onSurface.withOpacity(0.38)),
            selectedDecoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Colors.green.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            markersMaxCount: 0,
            markerDecoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            leftChevronIcon:
                Icon(Icons.chevron_left, color: colorScheme.onSurface),
            rightChevronIcon:
                Icon(Icons.chevron_right, color: colorScheme.onSurface),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: colorScheme.onSurface),
            weekendStyle: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeScale() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 24,
      itemBuilder: (context, index) {
        final hour = index;
        final time = TimeOfDay(hour: hour, minute: 0);
        final events = _getEventsForHour(hour);

        // Calculate dynamic height based on number of events (minimum 60)
        final double timeSlotHeight =
            events.isEmpty ? 60 : max(60, events.length * 40.0);

        return InkWell(
          onTap: () {
            setState(() => _selectedTime = time);
            _showCreateDialog(time);
          },
          child: Container(
            height: timeSlotHeight,
            margin: const EdgeInsets.only(bottom: 1),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    '${time.format(context).toLowerCase()}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: events.isEmpty
                        ? Container() // Empty container if no events
                        : ListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: events.length,
                            itemBuilder: (context, index) {
                              return _buildEventCard(events[index]);
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<CalendarEvent> _getEventsForHour(int hour) {
    if (_selectedDay == null) return [];
    final dayEvents = _getEventsForDay(_selectedDay!);
    return dayEvents.where((event) => event.startTime.hour == hour).toList();
  }

  Widget _buildEventCard(CalendarEvent event) {
    return GestureDetector(
      onTap: () => _handleEventTap(event),
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: event.type.color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: event.type.color, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(event.type.icon, color: event.type.color, size: 16),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                event.title,
                style: TextStyle(
                  color: event.type.color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${event.startTime.format(context)} - ${event.endTime.format(context)}',
              style: TextStyle(color: event.type.color, fontSize: 10),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.edit,
              color: event.type.color,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleEventTap(CalendarEvent event) async {
    dynamic result;

    switch (event.type) {
      case EventType.meeting:
        // Navigate to meeting detail screen
        result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MeetingDetailScreen(meetingId: event.id),
          ),
        );
        break;
      case EventType.task:
        // Navigate to task detail screen
        result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskDetailScreen(taskId: event.id),
          ),
        );
        break;
      case EventType.ticket:
        // Navigate to ticket detail screen
        result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TicketDetailScreen(ticketId: event.id),
          ),
        );
        break;
    }

    // Refresh events if something was updated
    if (result == true) {
      await _loadEventsWithCache(); // Use cache loading
    }
  }

  void _showCreateDialog(TimeOfDay selectedTime) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Create at ${selectedTime.format(context)}',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogOption(
              'Schedule a Meeting',
              Icons.people,
              Colors.blue,
              () => _handleCreate(EventType.meeting, selectedTime),
            ),
            const SizedBox(height: 8),
            _buildDialogOption(
              'Create a Task',
              Icons.task,
              Colors.green,
              () => _handleCreate(EventType.task, selectedTime),
            ),
            const SizedBox(height: 8),
            _buildDialogOption(
              'Create a Ticket',
              Icons.confirmation_number,
              Colors.orange,
              () => _handleCreate(EventType.ticket, selectedTime),
            ),
            const SizedBox(height: 8),
            _buildDialogOption(
              'Create with Ell-ena AI',
              Icons.smart_toy,
              Colors.purple,
              () => _handleCreateWithAI(selectedTime),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogOption(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreate(EventType type, TimeOfDay selectedTime) async {
    Navigator.of(context).pop(); // Close dialog

    if (_selectedDay == null) return;

    final selectedDateTime = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    dynamic result;

    switch (type) {
      case EventType.meeting:
        result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CreateMeetingScreen(),
          ),
        );
        break;
      case EventType.task:
        result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CreateTaskScreen(),
          ),
        );
        break;
      case EventType.ticket:
        result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CreateTicketScreen(),
          ),
        );
        break;
    }

    // Refresh events if something was created
    if (result == true) {
      await _loadEventsWithCache(); // Use cache loading
    }
  }

  // Handle creation with AI assistant
  void _handleCreateWithAI(TimeOfDay selectedTime) {
    Navigator.of(context).pop(); // Close dialog

    if (_selectedDay == null) return;

    final selectedDateTime = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    // Format the date for the AI
    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDateTime);
    final formattedTime = selectedTime.format(context);
    final message =
        'I need to create a task for $formattedDate at $formattedTime';

    // Use the NavigationService to navigate to the chat screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatScreen(arguments: {'initial_message': message}),
      ),
    );
  }
}

class CalendarEvent {
  final String title;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final EventType type;
  final String id;

  CalendarEvent({
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.type,
    required this.id,
  });
}

enum EventType {
  meeting(Icons.people, Colors.blue, 'Meeting'),
  task(Icons.task, Colors.green, 'Task'),
  ticket(Icons.confirmation_number, Colors.orange, 'Ticket');

  final IconData icon;
  final MaterialColor color;
  final String label;

  const EventType(this.icon, this.color, this.label);
}
