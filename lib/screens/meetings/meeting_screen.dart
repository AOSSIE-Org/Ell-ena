import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';
import '../../controllers/language_controller.dart';
import '../../utils/language/sentence_manager.dart';
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
  final LanguageController languageController = Get.find<LanguageController>();
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
    final s = SentenceManager.instance;
    try {
      final result = await _supabaseService.deleteMeeting(meetingId);

      if (mounted && !result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.errorDeletingMeeting}: ${result['error']}'),
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
            content: Text('${s.errorDeletingMeeting}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchMeetingUrl(String? url) async {
    final s = SentenceManager.instance;
    if (url == null || url.isEmpty) return;

    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(s.errorLaunchingUrl),
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
            content: Text('${s.errorLaunchingUrl}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: Center(child: CustomLoading()),
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

    return Obx(() {
      final s = SentenceManager.instance;
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
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
              s: s,
            ),
            const SizedBox(height: 12),
            _buildFilterTabs(s),
            Expanded(
              child: _buildMeetingList(filteredMeetings, s),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildHeader({
    required int upcomingCount,
    required int pastCount,
    required dynamic s,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D2D),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMeetingStat(
            label: s.upcomingMeetings,
            value: upcomingCount,
            icon: Icons.calendar_today,
            color: Colors.blue.shade400,
          ),
          _buildMeetingStat(
            label: s.pastMeetings,
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
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFilterTabs(dynamic s) {
    final filterOptions = [
      {'id': 'upcoming', 'label': s.upcomingMeetings, 'color': Colors.blue},
      {'id': 'past', 'label': s.pastMeetings, 'color': Colors.purple},
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
                    color: isSelected ? color : Colors.white70,
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

  Widget _buildMeetingList(
      List<Map<String, dynamic>> filteredMeetings, dynamic s) {
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
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'upcoming'
                  ? s.noUpcomingMeetings
                  : s.noPastMeetings,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'upcoming'
                  ? s.createMeetingPrompt
                  : s.pastMeetingsPrompt,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
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
          s: s,
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
  final dynamic s;

  const _MeetingCard({
    required this.meeting,
    required this.isAdmin,
    required this.isUpcoming,
    required this.onDelete,
    required this.onJoin,
    required this.onTap,
    required this.s,
  });

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
    final title = (meeting['title'] ?? s.untitledMeeting).length > 25
        ? '${(meeting['title'] ?? s.untitledMeeting).substring(0, 25)}...'
        : (meeting['title'] ?? s.untitledMeeting);

    // Get creator name
    String creatorName = 'Unknown';
    if (meeting['creator'] != null && meeting['creator']['full_name'] != null) {
      creatorName = meeting['creator']['full_name'];
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF2D2D2D),
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
                      style: const TextStyle(
                        color: Colors.white,
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
                      tooltip: s.cancelMeetingTooltip,
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
                        color: Colors.grey.shade400,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isUpcoming
                            ? '${dateFormat.format(meetingDate)}, ${timeFormat.format(meetingDate)}'
                            : 'Yesterday, ${timeFormat.format(meetingDate)}',
                        style: TextStyle(
                          color: Colors.grey.shade300,
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
                        '${s.meetingCreatedBy} $creatorName',
                        style: TextStyle(
                          color: Colors.grey.shade400,
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
                          child: Text(
                            s.joinMeetingBtn,
                            style: const TextStyle(fontSize: 13),
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
                                s.transcription,
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
                                s.aiSummary,
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
