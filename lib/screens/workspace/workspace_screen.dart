import 'package:flutter/material.dart';
import '../tasks/task_screen.dart';
import '../tasks/create_task_screen.dart';
import '../tickets/ticket_screen.dart';
import '../tickets/create_ticket_screen.dart';
import '../meetings/meeting_screen.dart';
import '../meetings/create_meeting_screen.dart';
import '../chat/chat_screen.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_widgets.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedPriority;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);

    // Simulate loading delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  void _showCreateDialog() {
    final currentTab = _tabController.index;
    if (currentTab == 0) {
      _showCreateTaskDialog();
    } else if (currentTab == 1) {
      _showCreateTicketDialog();
    } else if (currentTab == 2) {
      _showCreateMeetingDialog();
    }
  }

  void _showCreateTaskDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateTaskScreen()),
    ).then((result) async {
      if (result == true) {
        // Reload team members cache first
        final supabaseService = SupabaseService();
        final userProfile = await supabaseService.getCurrentUserProfile();
        if (userProfile != null && userProfile['team_id'] != null) {
          await supabaseService.loadTeamMembers(userProfile['team_id']);
        }

        // Force refresh of the task screen
        TaskScreen.refreshTasks();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _showCreateTicketDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateTicketScreen()),
    ).then((result) async {
      if (result == true) {
        // Reload team members cache first
        final supabaseService = SupabaseService();
        final userProfile = await supabaseService.getCurrentUserProfile();
        if (userProfile != null && userProfile['team_id'] != null) {
          await supabaseService.loadTeamMembers(userProfile['team_id']);
        }

        // Force refresh of the ticket screen
        TicketScreen.refreshTickets();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _showCreateMeetingDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateMeetingScreen()),
    ).then((result) async {
      if (result == true) {
        // Reload team members cache first
        final supabaseService = SupabaseService();
        final userProfile = await supabaseService.getCurrentUserProfile();
        if (userProfile != null && userProfile['team_id'] != null) {
          await supabaseService.loadTeamMembers(userProfile['team_id']);
        }

        // Force refresh of the meeting screen
        MeetingScreen.refreshMeetings();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const WorkspaceLoadingSkeleton(),
      );
    }

    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + statusBarHeight),
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: true,
            bottom: false,
            left: false,
            right: false,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.green,
              labelColor: Colors.green,
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
              tabs: const [
                Tab(icon: Icon(Icons.task), text: 'Tasks'),
                Tab(icon: Icon(Icons.confirmation_number), text: 'Tickets'),
                Tab(icon: Icon(Icons.group), text: 'Meetings'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          TaskScreen(key: TaskScreen.globalKey),
          TicketScreen(key: TicketScreen.globalKey),
          MeetingScreen(key: MeetingScreen.globalKey),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }
}
