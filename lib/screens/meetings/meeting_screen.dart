import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/adaptive_create_flow.dart';
import '../../shell/app_shell.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/detail_side_panel.dart';
import 'create_meeting_screen.dart';
import 'meeting_detail_screen.dart';
import 'meeting_insights_screen.dart';

class MeetingScreen extends StatefulWidget {
  static final GlobalKey<State<MeetingScreen>> globalKey =
      GlobalKey<_MeetingScreenState>();

  const MeetingScreen({super.key});

  static void refreshMeetings() {
    (globalKey.currentState as _MeetingScreenState?)?._loadInitialData();
  }

  /// Opens the create-meeting screen; used by the wide shell's top bar.
  static void openCreateMeeting() {
    (globalKey.currentState as _MeetingScreenState?)?._openCreateMeeting();
  }

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;

  /// Meeting shown in the side panel on wide screens.
  String? _selectedMeetingId;
  bool _isAdmin = false;
  String _selectedFilter = 'upcoming';
  List<Map<String, dynamic>> _meetings = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  bool _isPastMeeting(Map<String, dynamic> meeting, DateTime now) {
    final start =
        DateTime.tryParse(meeting['meeting_date']?.toString() ?? '')?.toUtc();
    if (start == null) return false;
    final minutes = (meeting['duration_minutes'] as num?)?.toInt() ?? 60;
    final ended = !start.add(Duration(minutes: minutes)).isAfter(now.toUtc());

    final transcript = meeting['transcription']?.toString() ?? '';
    final summary = meeting['ai_summary']?.toString() ?? '';
    final hasRecord = transcript.isNotEmpty ||
        summary.isNotEmpty ||
        meeting['meeting_summary_json'] != null ||
        meeting['transcription_status'] == 'completed';

    return ended || hasRecord;
  }

  /// [showLoading] false reloads behind the current list instead of
  /// replacing it with a spinner, e.g. when the side panel closes.
  Future<void> _loadInitialData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

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
    final l10n = AppLocalizations.of(context);
    try {
      final result = await _supabaseService.deleteMeeting(meetingId);

      if (mounted && !result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.meetingErrorDeleting('${result['error']}')),
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
            content: Text(l10n.meetingErrorDeleting('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchMeetingUrl(String? url) async {
    if (url == null || url.isEmpty) return;

    final l10n = AppLocalizations.of(context);
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.meetingCouldNotLaunchUrl),
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
            content: Text(l10n.meetingErrorLaunchingUrl('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openCreateMeeting() async {
    final result = await openCreateFlow(context, CreateMeetingScreen());

    if (result == true) {
      // Meeting was created, refresh meetings
      _loadInitialData();
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
      final isPast = _isPastMeeting(meeting, now);
      if (_selectedFilter == 'upcoming') {
        return !isPast;
      }
      return isPast;
    }).toList();

    final pastCount =
        _meetings.where((meeting) => _isPastMeeting(meeting, now)).length;
    final upcomingCount = _meetings.length - pastCount;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Wide screens create from the shell's top bar instead.
      floatingActionButton: AppShell.isDesktop(context)
          ? null
          : FloatingActionButton(
              heroTag: 'meetings-add-button',
              onPressed: _openCreateMeeting,
              tooltip: AppLocalizations.of(context).newMeeting,
              backgroundColor: Colors.green.shade700,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: _withMeetingPanel(Column(
        children: [
          _buildHeader(
            upcomingCount: upcomingCount,
            pastCount: pastCount,
          ),
          const SizedBox(height: 12),
          _buildFilterTabs(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadInitialData(showLoading: false),
              child: _buildMeetingList(filteredMeetings),
            ),
          ),
        ],
      )),
    );
  }

  Widget _withMeetingPanel(Widget content) {
    final meetingId = _selectedMeetingId;
    return DetailPanelLayout(
      content: content,
      panel: meetingId == null || !AppShell.isDesktop(context)
          ? null
          : DetailSidePanel(
              itemKey: meetingId,
              onClose: _closeMeetingPanel,
              child: MeetingDetailScreen(meetingId: meetingId),
            ),
    );
  }

  /// Phones open the meeting as a page; wide screens show it in the side
  /// panel.
  Future<void> _openMeeting(Map<String, dynamic> meeting) async {
    if (AppShell.isDesktop(context)) {
      setState(() => _selectedMeetingId = meeting['id'] as String?);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MeetingDetailScreen(meetingId: meeting['id']),
      ),
    );

    // Reload even when the page closes without a result, so a finished
    // summary shows up in the list.
    _loadInitialData(showLoading: false);
  }

  void _closeMeetingPanel() {
    setState(() => _selectedMeetingId = null);
    // The panel may have changed or deleted the meeting.
    _loadInitialData(showLoading: false);
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
            label: AppLocalizations.of(context).meetingUpcoming,
            value: upcomingCount,
            icon: Icons.calendar_today,
            color: Colors.blue.shade400,
          ),
          _buildMeetingStat(
            label: AppLocalizations.of(context).meetingPast,
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
          backgroundColor: color.withValues(alpha: 0.2),
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
    final l10n = AppLocalizations.of(context);
    final filterOptions = [
      {'id': 'upcoming', 'label': l10n.meetingUpcoming, 'color': Colors.blue},
      {'id': 'past', 'label': l10n.meetingPast, 'color': Colors.purple},
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
                  color: isSelected
                      ? color.withValues(alpha: 0.2)
                      : Colors.transparent,
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
      final l10n = AppLocalizations.of(context);
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
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
                  _selectedFilter == 'upcoming'
                      ? l10n.meetingNoUpcoming
                      : l10n.meetingNoPast,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedFilter == 'upcoming'
                      ? l10n.meetingEmptyUpcomingHint
                      : l10n.meetingEmptyPastHint,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (AppShell.isDesktop(context)) {
      return _buildMeetingGrid(filteredMeetings);
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: filteredMeetings.length,
      itemBuilder: (context, index) {
        final meeting = filteredMeetings[index];
        final isUpcoming = !_isPastMeeting(meeting, DateTime.now());

        return _MeetingCard(
          meeting: meeting,
          isAdmin: _isAdmin,
          isUpcoming: isUpcoming,
          onDelete: _deleteMeeting,
          onJoin: _launchMeetingUrl,
          onTap: () => _openMeeting(meeting),
        );
      },
    );
  }

  /// Wide screens: the same cards in rows of up to three, capped at 1440px
  /// and centered. Each row takes its tallest card's height.
  Widget _buildMeetingGrid(List<Map<String, dynamic>> meetings) {
    const gap = 16.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? 3
            : width >= 700
                ? 2
                : 1;
        final rowCount = (meetings.length / columns).ceil();
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: rowCount,
              itemBuilder: (context, row) {
                final start = row * columns;
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < columns; i++) ...[
                        if (i > 0) const SizedBox(width: gap),
                        Expanded(
                          child: start + i < meetings.length
                              ? _buildGridCard(meetings[start + i])
                              : const SizedBox(),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridCard(Map<String, dynamic> meeting) {
    final meetingDate = DateTime.parse(meeting['meeting_date']);
    return _MeetingCard(
      meeting: meeting,
      isAdmin: _isAdmin,
      isUpcoming: meetingDate.isAfter(DateTime.now()),
      selected: meeting['id'] == _selectedMeetingId,
      onDelete: _deleteMeeting,
      onJoin: _launchMeetingUrl,
      onTap: () => _openMeeting(meeting),
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

  /// Outlines the card whose meeting is open in the wide-screen side panel.
  final bool selected;

  const _MeetingCard({
    required this.meeting,
    required this.isAdmin,
    required this.isUpcoming,
    required this.onDelete,
    required this.onJoin,
    required this.onTap,
    this.selected = false,
  });

  String _getRelativeDate(DateTime date, AppLocalizations l10n) {
    // Ensure the date is converted to local time before making midnight comparisons
    final localDate = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(localDate.year, localDate.month, localDate.day);

    if (dateOnly == today) {
      return l10n.meetingToday;
    } else if (dateOnly == tomorrow) {
      return l10n.meetingTomorrow;
    } else if (dateOnly == yesterday) {
      return l10n.meetingYesterday;
    } else if (isUpcoming) {
      return DateFormat('E, MMM d, yyyy').format(localDate);
    } else {
      final difference = today.difference(dateOnly).inDays;
      if (difference > 0 && difference < 30) {
        return l10n.meetingDaysAgo(difference);
      } else {
        return DateFormat('MMM d, yyyy').format(localDate);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Parse the date and force it into the local timezone for rendering
    final meetingDate = DateTime.parse(meeting['meeting_date']).toLocal();
    final timeFormat = DateFormat('h:mm a');
    final hasUrl = meeting['meeting_url'] != null &&
        meeting['meeting_url'].toString().isNotEmpty;
    final isCreator = meeting['creator'] != null &&
        meeting['creator']['id'] ==
            SupabaseService().client.auth.currentUser?.id;
    final canCancel = isUpcoming && (isAdmin || isCreator);

    // Limit title to 25 characters
    final title = (meeting['title'] ?? l10n.meetingUntitled).length > 25
        ? '${(meeting['title'] ?? l10n.meetingUntitled).substring(0, 25)}...'
        : (meeting['title'] ?? l10n.meetingUntitled);

    // Get creator name
    String creatorName = l10n.meetingUnknownUser;
    if (meeting['creator'] != null && meeting['creator']['full_name'] != null) {
      creatorName = meeting['creator']['full_name'];
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
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
                color: Colors.green.shade400.withValues(alpha: 0.2),
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
                      tooltip: l10n.meetingCancelMeetingTooltip,
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
                        '${_getRelativeDate(meetingDate, l10n)}, ${timeFormat.format(meetingDate)}',
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
                              l10n.meetingDurationMin('${meeting['duration']}'),
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
                        l10n.meetingCreatedBy(creatorName),
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
                          child: Text(
                            l10n.meetingJoin,
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
                                l10n.meetingTranscription,
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
                                l10n.meetingAiSummary,
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
