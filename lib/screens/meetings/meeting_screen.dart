import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_widgets.dart';
import 'create_meeting_screen.dart';
import 'meeting_detail_screen.dart';
import 'meeting_insights_screen.dart';

class MeetingScreen extends StatefulWidget {
  static final GlobalKey<_MeetingScreenState> globalKey =
      GlobalKey<_MeetingScreenState>();

  const MeetingScreen({Key? key}) : super(key: key);

  static void refreshMeetings() {
    globalKey.currentState?._loadInitialData();
  }

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  bool _isAdmin = false;
  String _selectedFilter = 'upcoming';
  List<Map<String, dynamic>> _meetings = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if user is admin
      final userProfile = await _supabaseService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _isAdmin = userProfile?['role'] == 'admin';
        });
      }

      // Initial load of meetings
      final meetings = await _supabaseService.getMeetings();

      if (mounted) {
        setState(() {
          _meetings = meetings;
          _isLoading = false;
        });
      }

      debugPrint('Meetings loaded: ${meetings.length}');
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteMeeting(String meetingId) async {
    try {
      final result = await _supabaseService.deleteMeeting(meetingId);

      if (mounted && !result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting meeting: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        _loadInitialData();
      }
    } catch (e) {
      debugPrint('Error deleting meeting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchMeetingUrl(String? url) async {
    if (url == null || url.isEmpty) return;

    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not launch meeting URL'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching URL: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CustomLoading()),
      );
    }

    // Make sure the key is properly associated with this instance
    if (MeetingScreen.globalKey.currentState != this) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        MeetingScreen.refreshMeetings();
      });
    }

    final now = DateTime.now();

    // Filter meetings based on selected filter
    final filteredMeetings = _meetings.where((meeting) {
      final meetingDate = DateTime.parse(meeting['meeting_date']);
      if (_selectedFilter == 'upcoming') {
        return meetingDate.isAfter(now);
      } else {
        return meetingDate.isBefore(now);
      }
    }).toList();

    final upcomingCount = _meetings
        .where((m) => DateTime.parse(m['meeting_date']).isAfter(now))
        .length;
    final pastCount = _meetings
        .where((m) => DateTime.parse(m['meeting_date']).isBefore(now))
        .length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateMeetingScreen(),
            ),
          );

          if (result == true) {
            // Meeting was created, refresh meetings
            _loadInitialData();
          }
        },
        backgroundColor: Colors.green.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          _buildHeader(
            upcomingCount: upcomingCount,
            pastCount: pastCount,
          ),
          const SizedBox(height: 12),
          _buildFilterTabs(),
          Expanded(
            child: _buildMeetingList(filteredMeetings),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required int upcomingCount,
    required int pastCount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMeetingStat(
            label: 'Upcoming',
            value: upcomingCount,
            icon: Icons.calendar_today,
            color: Colors.blue.shade400,
          ),
          _buildMeetingStat(
            label: 'Past',
            value: pastCount,
            icon: Icons.history,
            color: Colors.purple.shade400,
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingStat({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: color.withOpacity(0.2),
          child: Icon(
            icon,
            color: color,
            size: 22,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value.toString(),
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    final filterOptions = [
      {'id': 'upcoming', 'label': 'Upcoming', 'color': Colors.blue},
      {'id': 'past', 'label': 'Past', 'color': Colors.purple},
    ];

    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: filterOptions.map((filter) {
          final isSelected = filter['id'] == _selectedFilter;
          final color = filter['color'] as MaterialColor;

          return Expanded(
            child: GestureDetector(
              onTap: () =>
                  setState(() => _selectedFilter = filter['id'] as String),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      isSelected ? color.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Text(
                  filter['label'] as String,
                  style: TextStyle(
                    color: isSelected
                        ? color
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMeetingList(List<Map<String, dynamic>> filteredMeetings) {
    if (filteredMeetings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedFilter == 'upcoming'
                  ? Icons.calendar_today
                  : Icons.history,
              size: 70,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${_selectedFilter == 'upcoming' ? 'upcoming' : 'past'} meetings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'upcoming'
                  ? 'Create new meetings to get started'
                  : 'Past meetings will appear here',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredMeetings.length,
      itemBuilder: (context, index) {
        final meeting = filteredMeetings[index];
        final meetingDate = DateTime.parse(meeting['meeting_date']);
        final isUpcoming = meetingDate.isAfter(DateTime.now());

        return _MeetingCard(
          meeting: meeting,
          isAdmin: _isAdmin,
          isUpcoming: isUpcoming,
          onDelete: _deleteMeeting,
          onJoin: _launchMeetingUrl,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MeetingDetailScreen(meetingId: meeting['id']),
              ),
            );

            if (result == true) {
              // Meeting was updated in detail screen, refresh meetings
              _loadInitialData();
            }
          },
        );
      },
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final Map<String, dynamic> meeting;
  final bool isAdmin;
  final bool isUpcoming;
  final Function(String) onDelete;
  final Function(String?) onJoin;
  final VoidCallback onTap;

  const _MeetingCard({
    required this.meeting,
    required this.isAdmin,
    required this.isUpcoming,
    required this.onDelete,
    required this.onJoin,
    required this.onTap,
  });

  String _getRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == tomorrow) {
      return 'Tomorrow';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else if (isUpcoming) {
      return DateFormat('E, MMM d, yyyy').format(date);
    } else {
      final difference = today.difference(dateOnly).inDays;
      if (difference > 0 && difference < 30) {
        return '$difference days ago';
      } else {
        return DateFormat('MMM d, yyyy').format(date);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meetingDate = DateTime.parse(meeting['meeting_date']);
    final dateFormat = DateFormat('E, MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final hasUrl = meeting['meeting_url'] != null &&
        meeting['meeting_url'].toString().isNotEmpty;
    final isCreator = meeting['creator'] != null &&
        meeting['creator']['id'] ==
            SupabaseService().client.auth.currentUser?.id;
    final canCancel = isUpcoming && (isAdmin || isCreator);

    // Limit title to 25 characters
    final title = (meeting['title'] ?? 'Untitled Meeting').length > 25
        ? '${(meeting['title'] ?? 'Untitled Meeting').substring(0, 25)}...'
        : (meeting['title'] ?? 'Untitled Meeting');

    // Get creator name
    String creatorName = 'Unknown';
    if (meeting['creator'] != null && meeting['creator']['full_name'] != null) {
      creatorName = meeting['creator']['full_name'];
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade400.withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isUpcoming ? Icons.calendar_today : Icons.event_available,
                    color: isUpcoming
                        ? Colors.green.shade400
                        : Colors.grey.shade400,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (canCancel)
                    IconButton(
                      onPressed: () => onDelete(meeting['id']),
                      icon:
                          const Icon(Icons.delete, color: Colors.red, size: 18),
                      tooltip: 'Cancel Meeting',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),

            // Meeting details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date and time
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_getRelativeDate(meetingDate)}, ${timeFormat.format(meetingDate)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      if (!isUpcoming && meeting['duration'] != null)
                        Row(
                          children: [
                            const SizedBox(width: 8),
                            Icon(
                              Icons.timer,
                              color: Colors.orange.shade400,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${meeting['duration']} min',
                              style: TextStyle(
                                color: Colors.orange.shade400,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Creator info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.green.shade700,
                        child: Text(
                          creatorName.isNotEmpty
                              ? creatorName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Created by $creatorName',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      if (isUpcoming && hasUrl)
                        ElevatedButton(
                          onPressed: () => onJoin(meeting['meeting_url']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(70, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Join',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                  ),

                  // Transcription and AI Summary buttons for past meetings with URL
                  if (!isUpcoming && hasUrl)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MeetingInsightsScreen(
                                      meetingId: meeting['id'],
                                      initialTab: 'transcript',
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(
                                Icons.description,
                                color: Colors.green.shade400,
                                size: 14,
                              ),
                              label: Text(
                                'Transcription',
                                style: TextStyle(
                                  color: Colors.green.shade400,
                                  fontSize: 12,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.green.shade400),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MeetingInsightsScreen(
                                      meetingId: meeting['id'],
                                      initialTab: 'summary',
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(
                                Icons.auto_awesome,
                                color: Colors.blue.shade400,
                                size: 14,
                              ),
                              label: Text(
                                'AI Summary',
                                style: TextStyle(
                                  color: Colors.blue.shade400,
                                  fontSize: 12,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.blue.shade400),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
