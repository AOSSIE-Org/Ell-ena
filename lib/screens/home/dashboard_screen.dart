import 'package:flutter/material.dart';
import '../../widgets/custom_widgets.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../tasks/task_detail_screen.dart';
import '../tickets/ticket_detail_screen.dart';
import '../meetings/meeting_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _selectedTimeRange = 1; // 0: Week, 1: Month, 2: Year
  bool _isLoading = true;
  String? _userName;

  String? _currentTeamId;
  String? _currentTeamName;
  List<Map<String, dynamic>> _userTeams = [];

  int _tasksTotal = 0;
  int _tasksInProgress = 0;
  int _tasksCompleted = 0;
  int _ticketsOpen = 0;
  int _ticketsInProgress = 0;
  int _ticketsResolved = 0;
  // Deprecated: using unified _upcomingItems now
  List<Map<String, dynamic>> _recentTasks = [];
  List<Map<String, dynamic>> _recentTickets = [];
  List<FlSpot> _taskCompletionSpots = [];
  List<Map<String, dynamic>> _upcomingItems = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _loadData();

  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await _loadData();
  }
  
  void _showTeamSwitcher() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: const Text(
            'Switch Team',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _userTeams.length,
              itemBuilder: (context, index) {
                final team = _userTeams[index];
                final isCurrentTeam = team['id'] == _currentTeamId;
                
                return ListTile(
                  title: Text(
                    team['name'] ?? 'Team',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isCurrentTeam ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    'Team Code: ${team['team_code'] ?? 'N/A'}',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: isCurrentTeam 
                        ? Colors.green.shade400 
                        : Colors.grey.shade700,
                    child: Text(
                      (team['name'] as String? ?? 'T')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  trailing: isCurrentTeam 
                      ? Icon(Icons.check, color: Colors.green.shade400)
                      : null,
                  onTap: () {
                    if (!isCurrentTeam) {
                      _switchTeam(team['id']);
                    }
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _switchTeam(String teamId) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final supa = SupabaseService();
      final result = await supa.switchTeam(teamId);
      
      if (result['success'] == true) {
        // Reload data with new team
        await _loadData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error switching team: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error switching team: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error switching team: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final supa = SupabaseService();

      // Get user profile with team information
      final profile = await supa.getCurrentUserProfile(forceRefresh: true);
      
      // Set username
      _userName = (profile?['full_name'] as String?)?.trim();
      
      // Set current team
      if (profile != null && profile['team_id'] != null) {
        _currentTeamId = profile['team_id'];
        _currentTeamName = profile['teams']?['name'] ?? 'My Team';
      }
      
      // Fetch all teams associated with the user's email
      final userEmail = profile?['email'] as String?;
      if (userEmail != null) {
        try {
          final teamsResponse = await supa.getUserTeams(userEmail);
          if (teamsResponse['success'] == true && teamsResponse['teams'] != null) {
            _userTeams = List<Map<String, dynamic>>.from(teamsResponse['teams']);
          }
        } catch (e) {
          debugPrint('Error fetching user teams: $e');
        }
      }

      // Load other data
      final tasksFuture = supa.getTasks();
      final ticketsFuture = supa.getTickets();
      final meetingsFuture = supa.getMeetings();

      final results = await Future.wait([
        tasksFuture,
        ticketsFuture,
        meetingsFuture,
      ]);

      final tasks = List<Map<String, dynamic>>.from(results[0] as List);
      final tickets = List<Map<String, dynamic>>.from(results[1] as List);
      final meetings = List<Map<String, dynamic>>.from(results[2] as List);

      _tasksTotal = tasks.length;
      _tasksInProgress = tasks.where((t) => t['status'] == 'in_progress').length;
      _tasksCompleted = tasks.where((t) => t['status'] == 'completed').length;

      // Build completion series for last 7 days
      final now = DateTime.now();
      final Map<int, int> dayIndexToCompleted = {for (var i = 0; i < 7; i++) i: 0};
      for (final t in tasks) {
        if (t['status'] == 'completed') {
          final ts = (t['updated_at'] ?? t['created_at'])?.toString();
          if (ts != null) {
            final updated = DateTime.tryParse(ts);
            if (updated != null) {
              final diffDays = now
                  .difference(DateTime(updated.year, updated.month, updated.day))
                  .inDays;
              if (diffDays >= 0 && diffDays < 7) {
                final idx = 6 - diffDays; // earlier days on the left
                dayIndexToCompleted[idx] = (dayIndexToCompleted[idx] ?? 0) + 1;
              }
            }
          }
        }
      }
      _taskCompletionSpots = List.generate(
        7,
        (i) => FlSpot(i.toDouble(), (dayIndexToCompleted[i] ?? 0).toDouble()),
      );

      _ticketsOpen = tickets.where((t) => t['status'] == 'open').length;
      _ticketsInProgress = tickets.where((t) => t['status'] == 'in_progress').length;
      _ticketsResolved = tickets.where((t) => t['status'] == 'resolved').length;

      // Upcoming meetings (next 14 days)
      final upcoming = <Map<String, dynamic>>[];
      for (final m in meetings) {
        final md = DateTime.tryParse(m['meeting_date']?.toString() ?? '');
        if (md != null && md.isAfter(now.subtract(const Duration(days: 1))) && md.isBefore(now.add(const Duration(days: 14)))) {
          upcoming.add(m);
        }
      }
      upcoming.sort((a, b) {
        final ad = DateTime.tryParse(a['meeting_date']?.toString() ?? '') ?? now;
        final bd = DateTime.tryParse(b['meeting_date']?.toString() ?? '') ?? now;
        return ad.compareTo(bd);
      });
      // legacy meetings list no longer used

      // Recent
      tasks.sort((a, b) => (DateTime.tryParse((b['updated_at'] ?? b['created_at'])?.toString() ?? '') ?? now)
          .compareTo(DateTime.tryParse((a['updated_at'] ?? a['created_at'])?.toString() ?? '') ?? now));
      tickets.sort((a, b) => (DateTime.tryParse((b['updated_at'] ?? b['created_at'])?.toString() ?? '') ?? now)
          .compareTo(DateTime.tryParse((a['updated_at'] ?? a['created_at'])?.toString() ?? '') ?? now));
      _recentTasks = tasks.take(3).toList();
      _recentTickets = tickets.take(3).toList();

      // Build unified upcoming list: meetings (next 14d), tasks due today, tickets created today (approx due)
      final List<Map<String, dynamic>> items = [];
      for (final m in meetings) {
        final dt = DateTime.tryParse(m['meeting_date']?.toString() ?? '');
        if (dt != null && dt.isAfter(now.subtract(const Duration(days: 1))) && dt.isBefore(now.add(const Duration(days: 14)))) {
          items.add({
            'type': 'meeting',
            'id': m['id'],
            'title': m['title'] ?? 'Meeting',
            'at': dt,
            'icon': Icons.groups,
            'color': Colors.blue.shade400,
          });
        }
      }
      for (final t in tasks) {
        if (t['status'] == 'completed') continue;
        final due = DateTime.tryParse(t['due_date']?.toString() ?? '');
        if (due != null) {
          final sameDay = due.year == now.year && due.month == now.month && due.day == now.day;
          if (sameDay) {
            items.add({
              'type': 'task',
              'id': t['id'],
              'title': t['title'] ?? 'Task',
              'at': due,
              'icon': Icons.task_alt,
              'color': Colors.green.shade400,
              'status': t['status'],
            });
          }
        }
      }
      for (final tk in tickets) {
        // Tickets don't have due_date in schema; approximate with created today and open/in_progress
        final created = DateTime.tryParse(tk['created_at']?.toString() ?? '');
        final isActionable = tk['status'] == 'open' || tk['status'] == 'in_progress';
        if (created != null && isActionable) {
          final sameDay = created.year == now.year && created.month == now.month && created.day == now.day;
          if (sameDay) {
            items.add({
              'type': 'ticket',
              'id': tk['id'],
              'title': tk['title'] ?? 'Ticket',
              'at': created,
              'icon': Icons.confirmation_number,
              'color': Colors.orange.shade400,
              'status': tk['status'],
            });
          }
        }
      }
      items.sort((a, b) => (a['at'] as DateTime).compareTo(b['at'] as DateTime));
      _upcomingItems = items.take(8).toList();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final supa = SupabaseService();

      final profileFuture = supa.getCurrentUserProfile(forceRefresh: true);
      final tasksFuture = supa.getTasks();
      final ticketsFuture = supa.getTickets();
      final meetingsFuture = supa.getMeetings();

      final results = await Future.wait([
        profileFuture,
        tasksFuture,
        ticketsFuture,
        meetingsFuture,
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final tasks = List<Map<String, dynamic>>.from(results[1] as List);
      final tickets = List<Map<String, dynamic>>.from(results[2] as List);
      final meetings = List<Map<String, dynamic>>.from(results[3] as List);

      _userName = (profile?['full_name'] as String?)?.trim();

      _tasksTotal = tasks.length;
      _tasksInProgress = tasks.where((t) => t['status'] == 'in_progress').length;
      _tasksCompleted = tasks.where((t) => t['status'] == 'completed').length;

      // Build completion series for last 7 days
      final now = DateTime.now();
      final Map<int, int> dayIndexToCompleted = {for (var i = 0; i < 7; i++) i: 0};
      for (final t in tasks) {
        if (t['status'] == 'completed') {
          final ts = (t['updated_at'] ?? t['created_at'])?.toString();
          if (ts != null) {
            final updated = DateTime.tryParse(ts);
            if (updated != null) {
              final diffDays = now
                  .difference(DateTime(updated.year, updated.month, updated.day))
                  .inDays;
              if (diffDays >= 0 && diffDays < 7) {
                final idx = 6 - diffDays; // earlier days on the left
                dayIndexToCompleted[idx] = (dayIndexToCompleted[idx] ?? 0) + 1;
              }
            }
          }
        }
      }
      _taskCompletionSpots = List.generate(
        7,
        (i) => FlSpot(i.toDouble(), (dayIndexToCompleted[i] ?? 0).toDouble()),
      );

      _ticketsOpen = tickets.where((t) => t['status'] == 'open').length;
      _ticketsInProgress = tickets.where((t) => t['status'] == 'in_progress').length;
      _ticketsResolved = tickets.where((t) => t['status'] == 'resolved').length;

      // Upcoming meetings (next 14 days)
      final upcoming = <Map<String, dynamic>>[];
      for (final m in meetings) {
        final md = DateTime.tryParse(m['meeting_date']?.toString() ?? '');
        if (md != null && md.isAfter(now.subtract(const Duration(days: 1))) && md.isBefore(now.add(const Duration(days: 14)))) {
          upcoming.add(m);
        }
      }
      upcoming.sort((a, b) {
        final ad = DateTime.tryParse(a['meeting_date']?.toString() ?? '') ?? now;
        final bd = DateTime.tryParse(b['meeting_date']?.toString() ?? '') ?? now;
        return ad.compareTo(bd);
      });
      // legacy meetings list no longer used

      // Recent
      tasks.sort((a, b) => (DateTime.tryParse((b['updated_at'] ?? b['created_at'])?.toString() ?? '') ?? now)
          .compareTo(DateTime.tryParse((a['updated_at'] ?? a['created_at'])?.toString() ?? '') ?? now));
      tickets.sort((a, b) => (DateTime.tryParse((b['updated_at'] ?? b['created_at'])?.toString() ?? '') ?? now)
          .compareTo(DateTime.tryParse((a['updated_at'] ?? a['created_at'])?.toString() ?? '') ?? now));
      _recentTasks = tasks.take(3).toList();
      _recentTickets = tickets.take(3).toList();

      // Build unified upcoming list: meetings (next 14d), tasks due today, tickets created today (approx due)
      final List<Map<String, dynamic>> items = [];
      for (final m in meetings) {
        final dt = DateTime.tryParse(m['meeting_date']?.toString() ?? '');
        if (dt != null && dt.isAfter(now.subtract(const Duration(days: 1))) && dt.isBefore(now.add(const Duration(days: 14)))) {
          items.add({
            'type': 'meeting',
            'id': m['id'],
            'title': m['title'] ?? 'Meeting',
            'at': dt,
            'icon': Icons.groups,
            'color': Colors.blue.shade400,
          });
        }
      }
      for (final t in tasks) {
        if (t['status'] == 'completed') continue;
        final due = DateTime.tryParse(t['due_date']?.toString() ?? '');
        if (due != null) {
          final sameDay = due.year == now.year && due.month == now.month && due.day == now.day;
          if (sameDay) {
            items.add({
              'type': 'task',
              'id': t['id'],
              'title': t['title'] ?? 'Task',
              'at': due,
              'icon': Icons.task_alt,
              'color': Colors.green.shade400,
              'status': t['status'],
            });
          }
        }
      }
      for (final tk in tickets) {
        // Tickets don't have due_date in schema; approximate with created today and open/in_progress
        final created = DateTime.tryParse(tk['created_at']?.toString() ?? '');
        final isActionable = tk['status'] == 'open' || tk['status'] == 'in_progress';
        if (created != null && isActionable) {
          final sameDay = created.year == now.year && created.month == now.month && created.day == now.day;
          if (sameDay) {
            items.add({
              'type': 'ticket',
              'id': tk['id'],
              'title': tk['title'] ?? 'Ticket',
              'at': created,
              'icon': Icons.confirmation_number,
              'color': Colors.orange.shade400,
              'status': tk['status'],
            });
          }
        }
      }
      items.sort((a, b) => (a['at'] as DateTime).compareTo(b['at'] as DateTime));
      _upcomingItems = items.take(8).toList();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: DashboardLoadingSkeleton(),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: Colors.green,
        backgroundColor: const Color(0xFF2D2D2D),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            expandedHeight: 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF2E7D32),
                          const Color(0xFF1B5E20),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                  ),
                  CustomPaint(
                    painter: DotPatternPainter(
                      color: Colors.white.withOpacity(0.1),
                    ),
                    size: Size(MediaQuery.of(context).size.width, 160),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Welcome back,',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [

                                        Flexible(
                                          child: Text(
                                            _userName ?? '—',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,

                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.trending_up,
                                                color:
                                                    Colors.greenAccent.shade100,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '+${_tasksCompleted > 0 && _tasksTotal > 0 ? ((_tasksCompleted / (_tasksTotal == 0 ? 1 : _tasksTotal)) * 100).round() : 0}%',
                                                style: TextStyle(
                                                  color: Colors.greenAccent.shade100,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_userTeams.length > 1)
                                      GestureDetector(
                                        onTap: _showTeamSwitcher,
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _currentTeamName ?? 'My Team',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.9),
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.swap_horiz,
                                                color: Colors.white.withOpacity(0.9),
                                                size: 16,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverviewCards(),
                    const SizedBox(height: 24),
                    _buildAnalyticsSection(),
                    const SizedBox(height: 24),
                    _buildUpcomingSection(),
                    const SizedBox(height: 24),
                    _buildRecentActivity(),
                    const SizedBox(height: 24),
                    _buildPerformanceMetrics(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildOverviewCards() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today\'s Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade400.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      color: Colors.green.shade400,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+15%',
                      style: TextStyle(
                        color: Colors.green.shade400,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOverviewItem(
                _tasksTotal.toString(),
                'Total Tasks',
                Icons.task_alt,
                Colors.green.shade400,
              ),
              _buildOverviewItem(
                _tasksInProgress.toString(),
                'In Progress',
                Icons.pending_actions,
                Colors.orange.shade400,
              ),
              _buildOverviewItem(
                _tasksCompleted.toString(),
                'Completed',
                Icons.check_circle_outline,
                Colors.blue.shade400,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOverviewItem(
                _ticketsOpen.toString(),
                'Open Tickets',
                Icons.bug_report,
                Colors.red.shade400,
              ),
              _buildOverviewItem(
                _ticketsInProgress.toString(),
                'Tickets In Progress',
                Icons.hourglass_bottom,
                Colors.amber.shade400,
              ),
              _buildOverviewItem(
                _ticketsResolved.toString(),
                'Resolved',
                Icons.verified,
                Colors.teal.shade300,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewItem(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        ),
      ],
    );
  }

  Widget _buildAnalyticsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(

                'Task Completion by Day',

                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _timeRangeButton('Week', 0),
                    _timeRangeButton('Month', 1),
                    _timeRangeButton('Year', 2),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: _taskCompletionSpots.isEmpty
                ? Center(
                    child: Text(
                      'No completions yet',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.shade800,
                            strokeWidth: 1,
                          );
                        },
                      ),

                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              final now = DateTime.now();
                              final idx = value.toInt();
                              if (idx < 0 || idx > 6) return const SizedBox();
                              final day = now.subtract(Duration(days: 6 - idx));
                              return Text(
                                DateFormat('E').format(day),
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),

                      barGroups: _taskCompletionSpots.map((spot) {
                        return BarChartGroupData(
                          x: spot.x.toInt(),
                          barRods: [
                            BarChartRodData(
                              toY: spot.y,
                              color: Colors.green.shade400,
                              width: 16,
                              borderRadius: BorderRadius.circular(4),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: 5, // Maximum expected value or slightly higher
                                color: Colors.green.shade400.withOpacity(0.1),
                              ),
                            ),
                          ],
                        );
                      }).toList(),

                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _timeRangeButton(String text, int index) {
    final isSelected = _selectedTimeRange == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTimeRange = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade400 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade400,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upcoming',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(20),
          ),
          child: _upcomingItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Nothing due today or scheduled soon',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  ),
                )
              : Column(
                  children: List.generate(_upcomingItems.length, (index) {
                    final item = _upcomingItems[index];
                    final dt = item['at'] as DateTime?;
                    final timeLabel = dt != null ? DateFormat('MMM d • h:mm a').format(dt) : '';
                    final IconData icon = item['icon'] as IconData;
                    final Color color = item['color'] as Color;
                    return InkWell(
                      onTap: () => _openUpcomingItem(item),
                      child: Column(
                        children: [
                          _buildUpcomingItem(
                            (item['title'] as String?) ?? '',
                            timeLabel,
                            icon,
                            color,
                          ),
                          if (index < _upcomingItems.length - 1) const Divider(color: Colors.grey),
                        ],
                      ),
                    );
                  }),
                ),
        ),
      ],
    );
  }

  Widget _buildUpcomingItem(
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  void _openUpcomingItem(Map<String, dynamic> item) {
    final type = item['type'] as String?;
    final id = item['id'] as String?;
    if (type == null || id == null) return;
    if (type == 'task') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: id)),
      );
    } else if (type == 'ticket') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: id)),
      );
    } else if (type == 'meeting') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MeetingDetailScreen(meetingId: id)),
      );
    }
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(20),
          ),
          child: _buildDynamicActivityList(),
        ),
      ],
    );
  }

  Widget _buildDynamicActivityList() {
    final items = <Map<String, dynamic>>[];
    for (final t in _recentTasks) {
      items.add({
        'type': 'Task',
        'title': t['title'] ?? 'Task',
        'status': t['status'] ?? 'todo',
        'time': t['updated_at'] ?? t['created_at'],
        'icon': Icons.task_alt,
        'color': Colors.green.shade400,
      });
    }
    for (final tk in _recentTickets) {
      items.add({
        'type': 'Ticket',
        'title': tk['title'] ?? 'Ticket',
        'status': tk['status'] ?? 'open',
        'time': tk['updated_at'] ?? tk['created_at'],
        'icon': Icons.confirmation_number,
        'color': Colors.orange.shade400,
      });
    }
    items.sort((a, b) {
      final ta = DateTime.tryParse(a['time']?.toString() ?? '') ?? DateTime.now();
      final tb = DateTime.tryParse(b['time']?.toString() ?? '') ?? DateTime.now();
      return tb.compareTo(ta);
    });
    final limited = items.take(5).toList();

    if (limited.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('No recent activity', style: TextStyle(color: Colors.grey.shade400)),
        ),
      );
    }

    return Column(
      children: List.generate(limited.length, (index) {
        final a = limited[index];
        final date = DateTime.tryParse(a['time']?.toString() ?? '');
        final timeLabel = date != null ? DateFormat('MMM d, h:mm a').format(date) : '';
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (a['color'] as Color).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${a['type']}: ${a['title']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Status: ${a['status']}',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    timeLabel,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (index < limited.length - 1) const Divider(color: Colors.grey),
          ],
        );
      }),
    );
  }

  Widget _buildPerformanceMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Metrics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _buildMetricItem(
                'Task Completion Rate',
                _tasksTotal == 0 ? 0 : _tasksCompleted / _tasksTotal,
                Colors.green.shade400,
              ),
              const SizedBox(height: 16),
              _buildMetricItem('On-time Delivery', 0.92, Colors.blue.shade400),
              const SizedBox(height: 16),
              _buildMetricItem(
                'Team Collaboration',
                0.78,
                Colors.purple.shade400,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class DotPatternPainter extends CustomPainter {
  final Color color;

  DotPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

    const spacing = 30.0;
    const dotSize = 2.0;

    for (var x = 0.0; x < size.width; x += spacing) {
      for (var y = 0.0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotSize, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotPatternPainter oldDelegate) => false;
}
