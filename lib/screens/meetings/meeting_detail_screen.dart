import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_widgets.dart';

class MeetingDetailScreen extends StatefulWidget {
  final String meetingId;

  const MeetingDetailScreen({
    super.key,
    required this.meetingId,
  });

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  final _supabaseService = SupabaseService();
  Map<String, dynamic>? _meeting;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isAdmin = false;
  bool _isCreator = false;
  bool _isCallingBot = false;
  bool _isFetchingSummary = false;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _urlController = TextEditingController();
  final _transcriptionController = TextEditingController();
  final _aiSummaryController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  DateTime? _meetingDate;
  TimeOfDay? _meetingTime;

  @override
  void initState() {
    super.initState();
    _loadMeetingDetails();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    _transcriptionController.dispose();
    _aiSummaryController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _callBot() async {
    final meeting = _meeting;
    final meetingUrl = meeting?['meeting_url']?.toString() ?? '';
    if (meeting == null || meetingUrl.isEmpty || _isCallingBot) return;

    setState(() => _isCallingBot = true);
    try {
      final result = await _supabaseService.startBot(
        meetingId: widget.meetingId,
        meetingUrl: meetingUrl,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bot called'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadMeetingDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?.toString() ?? 'Failed to call bot'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to call bot: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCallingBot = false);
    }
  }

  Future<void> _fetchSummary() async {
    final meeting = _meeting;
    final meetingUrl = meeting?['meeting_url']?.toString() ?? '';
    if (meeting == null || meetingUrl.isEmpty || _isFetchingSummary) return;

    setState(() => _isFetchingSummary = true);
    try {
      final result = await _supabaseService.fetchAndProcessTranscript(
        meetingId: widget.meetingId,
        meetingUrl: meetingUrl,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Summary ready'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['error']?.toString() ?? 'Failed to fetch summary',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to fetch summary: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      Map<String, dynamic>? updatedMeeting;
      try {
        updatedMeeting =
            await _supabaseService.getMeetingDetails(widget.meetingId);
      } catch (e) {
        debugPrint('Error refreshing meeting after summary: $e');
      }
      if (mounted) {
        setState(() {
          _isFetchingSummary = false;
          if (updatedMeeting != null) {
            _meeting = updatedMeeting;
            _aiSummaryController.text =
                updatedMeeting['ai_summary']?.toString() ?? '';
          }
        });
      }
    }
  }

  Future<void> _loadMeetingDetails() async {
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

      // Get meeting details
      final meetingDetails =
          await _supabaseService.getMeetingDetails(widget.meetingId);

      if (mounted && meetingDetails != null) {
        final userId = _supabaseService.client.auth.currentUser?.id;
        final isCreator = meetingDetails['created_by'] == userId;

        // Parse meeting date and time
        final meetingDateTime = DateTime.parse(meetingDetails['meeting_date']);

        setState(() {
          _meeting = meetingDetails;
          _isCreator = isCreator;
          _meetingDate = meetingDateTime;
          _meetingTime = TimeOfDay.fromDateTime(meetingDateTime);

          // Set initial values for editing
          _titleController.text = meetingDetails['title'] ?? '';
          _descriptionController.text = meetingDetails['description'] ?? '';
          _urlController.text = meetingDetails['meeting_url'] ?? '';
          _transcriptionController.text = meetingDetails['transcription'] ?? '';
          _aiSummaryController.text = meetingDetails['ai_summary'] ?? '';
          _durationController.text =
              meetingDetails['duration_minutes']?.toString() ?? '60';

          _isLoading = false;
        });
      } else {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.meetingNotFound),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading meeting details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context).meetingErrorLoadingDetails('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteMeeting() async {
    final l10n = AppLocalizations.of(context);
    try {
      final result = await _supabaseService.deleteMeeting(widget.meetingId);

      if (mounted) {
        if (result['success']) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.meetingErrorDeleting('${result['error']}')),
              backgroundColor: Colors.red,
            ),
          );
        }
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

  Future<void> _updateMeeting() async {
    final l10n = AppLocalizations.of(context);
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.meetingTitleEmpty),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_meetingDate == null || _meetingTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.meetingSelectDateTime),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Combine date and time
      final meetingDateTime = DateTime(
        _meetingDate!.year,
        _meetingDate!.month,
        _meetingDate!.day,
        _meetingTime!.hour,
        _meetingTime!.minute,
      );

      // Parse duration
      int? duration;
      if (_durationController.text.trim().isNotEmpty) {
        try {
          duration = int.parse(_durationController.text.trim());
          if (duration <= 0) duration = 60;
        } catch (e) {
          // Default to 60 if parsing fails
          duration = 60;
        }
      }

      final result = await _supabaseService.updateMeeting(
        meetingId: widget.meetingId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        meetingDate: meetingDateTime,
        meetingUrl: _urlController.text.trim().isNotEmpty
            ? _urlController.text.trim()
            : null,
        transcription: _transcriptionController.text.trim().isNotEmpty
            ? _transcriptionController.text.trim()
            : null,
        aiSummary: _aiSummaryController.text.trim().isNotEmpty
            ? _aiSummaryController.text.trim()
            : null,
        durationMinutes: duration,
      );

      if (mounted) {
        if (result['success']) {
          setState(() {
            _isEditing = false;
            _isLoading = false;
          });

          // Reload meeting details
          _loadMeetingDetails();
        } else {
          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.meetingErrorUpdating('${result['error']}')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating meeting: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.meetingErrorUpdating('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchMeetingUrl() async {
    if (_meeting == null || _meeting!['meeting_url'] == null) return;

    final l10n = AppLocalizations.of(context);
    final url = Uri.parse(_meeting!['meeting_url']);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
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
  }

  Future<void> _createTicketFromAction(Map<String, dynamic> action) async {
    final l10n = AppLocalizations.of(context);
    try {
      final title = (action['item']?.toString() ?? 'Action Item');
      final description =
          'Created from meeting action item. Owner: ${action['owner'] ?? 'N/A'} • Deadline: ${action['deadline'] ?? 'N/A'}';
      const category = 'Meeting Discussion';
      const priority = 'medium';
      final result = await _supabaseService.createTicket(
        title: title,
        description: description,
        priority: priority,
        category: category,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.meetingTicketCreated),
              backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(l10n.meetingFailedToCreateTicket('${result['error']}')),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n.meetingErrorGeneric('$e')),
            backgroundColor: Colors.red),
      );
    }
  }

  DateTime? _parseDeadline(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'n/a') return null;
    try {
      return DateTime.parse(str);
    } catch (_) {
      return null;
    }
  }

  Future<void> _createTaskFromFollowUp(Map<String, dynamic> followUp) async {
    final l10n = AppLocalizations.of(context);
    try {
      final title = (followUp['task']?.toString() ?? 'Follow-up Task');
      final due = _parseDeadline(followUp['deadline']);
      final result = await _supabaseService.createTask(
        title: title,
        description: 'Created from meeting follow-up task',
        dueDate: due,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.meetingTaskCreated),
              backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(l10n.meetingFailedToCreateTask('${result['error']}')),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n.meetingErrorGeneric('$e')),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _copyMeetingUrl() async {
    if (_meeting == null || _meeting!['meeting_url'] == null) return;

    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: _meeting!['meeting_url']));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.meetingUrlCopied),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _meetingDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => child!,
    );

    if (picked != null) {
      setState(() {
        _meetingDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _meetingTime ?? TimeOfDay.now(),
      builder: (context, child) => child!,
    );

    if (picked != null) {
      setState(() {
        _meetingTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CustomLoading()),
      );
    }

    if (_meeting == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: Text(l10n.meetingNotFound)),
      );
    }

    final meetingDateTime = DateTime.parse(_meeting!['meeting_date']);
    final isUpcoming = meetingDateTime.isAfter(DateTime.now());
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final canEdit = (_isAdmin || _isCreator) && isUpcoming;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title:
            Text(_isEditing ? l10n.meetingEditTitle : l10n.meetingDetailsTitle),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _updateMeeting,
              icon: const Icon(Icons.check),
              tooltip: l10n.meetingSaveChanges,
            )
          else if (canEdit)
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit),
              tooltip: l10n.meetingEditTitle,
            ),
          if (canEdit && !_isEditing)
            IconButton(
              onPressed: () => _showDeleteConfirmation(context),
              icon: const Icon(Icons.delete),
              tooltip: l10n.meetingDeleteTitle,
            ),
        ],
      ),
      body: _isEditing
          ? _buildEditForm()
          : _buildMeetingDetails(dateFormat, timeFormat, isUpcoming),
    );
  }

  Widget _buildMeetingDetails(
      DateFormat dateFormat, DateFormat timeFormat, bool isUpcoming) {
    final l10n = AppLocalizations.of(context);
    final meetingDateTime = DateTime.parse(_meeting!['meeting_date']);

    // Determine transcription status
    String transcriptionStatus = l10n.meetingStatusNotStarted;
    Color transcriptionStatusColor = Colors.grey.shade600;

    if (_meeting!['transcription'] != null &&
        _meeting!['transcription'].toString().isNotEmpty) {
      transcriptionStatus = l10n.meetingStatusCompleted;
      transcriptionStatusColor = Colors.green.shade400;
    } else if (_meeting!['transcription_attempted_at'] != null) {
      transcriptionStatus = l10n.meetingStatusAttempted;
      transcriptionStatusColor = Colors.orange.shade400;
    } else if (_meeting!['bot_started_at'] != null) {
      transcriptionStatus = l10n.meetingStatusInProgress;
      transcriptionStatusColor = Colors.blue.shade400;
    } else if (!isUpcoming &&
        _meeting!['meeting_url'] != null &&
        _meeting!['meeting_url'].toString().contains('meet.google.com')) {
      transcriptionStatus = l10n.meetingStatusPending;
      transcriptionStatusColor = Colors.yellow.shade700;
    } else if (!_meeting!['meeting_url']
        .toString()
        .contains('meet.google.com')) {
      transcriptionStatus = l10n.meetingStatusNotAvailable;
      transcriptionStatusColor = Colors.red.shade400;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Meeting number and status
        Row(
          children: [
            Text(
              _meeting!['meeting_number'] ?? 'MTG-???',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isUpcoming
                    ? Colors.green.shade400.withValues(alpha: 0.2)
                    : Colors.grey.shade600.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUpcoming ? Icons.event_available : Icons.event_busy,
                    color: isUpcoming
                        ? Colors.green.shade400
                        : Colors.grey.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isUpcoming
                        ? l10n.meetingBadgeUpcoming
                        : l10n.meetingBadgePast,
                    style: TextStyle(
                      color: isUpcoming
                          ? Colors.green.shade400
                          : Colors.grey.shade600,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Title
        Text(
          _meeting!['title'] ?? l10n.meetingUntitled,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Date and time
        Builder(
          builder: (context) {
            final cs = Theme.of(context).colorScheme;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_month,
                          color: Colors.blue.shade400, size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.meetingDate,
                                style: TextStyle(
                                    color: cs.onSurfaceVariant, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(dateFormat.format(meetingDateTime),
                                style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          color: Colors.orange.shade400, size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.meetingTime,
                                style: TextStyle(
                                    color: cs.onSurfaceVariant, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(timeFormat.format(meetingDateTime),
                                style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.timer,
                          color: Colors.purple.shade400, size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.meetingDuration,
                                style: TextStyle(
                                    color: cs.onSurfaceVariant, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                                l10n.meetingDurationMinutes(
                                    '${_meeting!['duration_minutes'] ?? 60}'),
                                style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Description
        if (_meeting!['description'] != null &&
            _meeting!['description'].toString().isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.meetingDescription,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _meeting!['description'],
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Meeting URL
        if (_meeting!['meeting_url'] != null &&
            _meeting!['meeting_url'].toString().isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.meetingUrl,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _meeting!['meeting_url'],
                        style: TextStyle(
                          color: Colors.blue.shade300,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _copyMeetingUrl,
                      icon: Icon(Icons.copy,
                          color: Theme.of(context).colorScheme.onSurface),
                      tooltip: l10n.meetingCopyUrl,
                    ),
                    IconButton(
                      onPressed: _launchMeetingUrl,
                      icon: Icon(Icons.open_in_new,
                          color: Theme.of(context).colorScheme.onSurface),
                      tooltip: l10n.meetingOpenUrl,
                    ),
                  ],
                ),

                // Show transcription status for Google Meet URLs
                if (_meeting!['meeting_url']
                    .toString()
                    .contains('meet.google.com')) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.record_voice_over,
                          color: transcriptionStatusColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.meetingTranscriptionStatus(transcriptionStatus),
                          style: TextStyle(
                            color: transcriptionStatusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_meeting!['bot_started_at'] == null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isCallingBot ? null : _callBot,
                        icon: _isCallingBot
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.smart_toy_outlined),
                        label: Text(
                          _isCallingBot ? 'Calling bot…' : 'Call Bot',
                        ),
                      ),
                    ),
                  if (_meeting!['bot_started_at'] != null || !isUpcoming)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isFetchingSummary ? null : _fetchSummary,
                          icon: _isFetchingSummary
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.summarize_outlined),
                          label: Text(
                            _isFetchingSummary
                                ? 'Fetching summary…'
                                : 'Fetch Summary',
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),

        const SizedBox(height: 16),

        _buildSummaryView(),

        // Manage from AI summary (action items and follow-ups).
        if (!isUpcoming) _buildManageSections(),

        const SizedBox(height: 24),

        // Join meeting button
        if (isUpcoming &&
            _meeting!['meeting_url'] != null &&
            _meeting!['meeting_url'].toString().isNotEmpty)
          ElevatedButton(
            onPressed: _launchMeetingUrl,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.video_call, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  l10n.meetingJoinMeeting,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEditForm() {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Title
        TextFormField(
          controller: _titleController,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: l10n.meetingTitleLabel,
            labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.green),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Description
        TextFormField(
          controller: _descriptionController,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: l10n.meetingDescription,
            labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.green),
            ),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        // Date and Time
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outline),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        _meetingDate == null
                            ? l10n.meetingSelectDate
                            : DateFormat('MMM dd, yyyy').format(_meetingDate!),
                        style: TextStyle(
                          color: _meetingDate == null
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: _selectTime,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outline),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time,
                          color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        _meetingTime == null
                            ? l10n.meetingSelectTime
                            : _meetingTime!.format(context),
                        style: TextStyle(
                          color: _meetingTime == null
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Duration
        TextFormField(
          controller: _durationController,
          style: TextStyle(color: colorScheme.onSurface),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.meetingDurationMinutesLabel,
            labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.green),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Meeting URL
        TextFormField(
          controller: _urlController,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: l10n.meetingUrl,
            labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.green),
            ),
            helperText: !_urlController.text.contains('meet.google.com') &&
                    _urlController.text.isNotEmpty
                ? l10n.meetingTranscriptionGoogleMeetOnly
                : null,
            helperStyle: TextStyle(color: Colors.red.shade300),
          ),
        ),
        const SizedBox(height: 16),

        // Save button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _updateMeeting,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              l10n.meetingSaveChanges,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic>? _summaryJson() {
    final raw = _meeting?['meeting_summary_json'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  Widget _buildSummaryView() {
    final summary = _summaryJson();
    final aiSummary = _meeting?['ai_summary']?.toString() ?? '';

    if (summary != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summarySection(
            title: 'Summary',
            child: Text(
              summary['overall_summary']?.toString() ?? '',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
          _summarySection(
            title: 'Highlights',
            child: _bulletList(summary['meeting_highlights']),
          ),
          _summarySection(
            title: 'Key Points',
            child: _bulletList(summary['key_discussion_points']),
          ),
          _summarySection(
            title: 'Action Items',
            child: _actionItemList(summary['action_items']),
          ),
        ],
      );
    }

    if (aiSummary.trim().isNotEmpty) {
      return _summarySection(
        title: 'Summary',
        child: MarkdownBody(
          data: aiSummary,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _summarySection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _bulletList(dynamic items) {
    final list = items is List ? items : const [];
    if (list.isEmpty) {
      return Text(
        'None',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: list.map<Widget>((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface)),
              Expanded(
                child: Text(
                  item?.toString() ?? '',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _actionItemList(dynamic items) {
    final list = items is List ? items : const [];
    if (list.isEmpty) {
      return Text(
        'None',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Column(
      children: list.map<Widget>((item) {
        final map = item is Map ? Map<String, dynamic>.from(item) : null;
        final title = map?['item']?.toString() ?? item?.toString() ?? '';
        final owner = map?['owner']?.toString();
        final deadline = map?['deadline']?.toString();
        final subtitle = [
          if (owner != null && owner.isNotEmpty) 'Owner: $owner',
          if (deadline != null && deadline.isNotEmpty) 'Deadline: $deadline',
        ].join('  •  ');
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_box_outline_blank,
                  size: 18, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildManageSections() {
    final l10n = AppLocalizations.of(context);
    final summary = _summaryJson();
    if (summary == null || summary.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16)),
        child: Text(l10n.meetingAiSummaryNotAvailable,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }

    final actionItems = (summary['action_items'] as List?) ?? [];
    final followUps = (summary['follow_up_tasks'] as List?) ?? [];

    Widget pill(
        {required Color color,
        required String title,
        required String subtitle,
        required VoidCallback onTap}) {
      return InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Icon(Icons.arrow_forward, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.topic, color: Colors.amber.shade400, size: 18),
                  const SizedBox(width: 8),
                  Text(l10n.meetingManageDiscussion,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              if (actionItems.isEmpty)
                Text(l10n.meetingNoActionItems,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant))
              else
                ...actionItems.map<Widget>((it) {
                  final map = Map<String, dynamic>.from(it as Map);
                  final title =
                      map['item']?.toString() ?? l10n.meetingActionItemFallback;
                  final subtitle = l10n.meetingOwnerDeadline(
                      '${map['owner'] ?? '—'}',
                      '${map['deadline'] ?? l10n.meetingNotApplicable}');
                  return pill(
                    color: Colors.amber.shade400,
                    title: title,
                    subtitle: subtitle,
                    onTap: () => _createTicketFromAction(map),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.task_alt, color: Colors.green.shade400, size: 18),
                  const SizedBox(width: 8),
                  Text(l10n.meetingManageTasks,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              if (followUps.isEmpty)
                Text(l10n.meetingNoFollowUps,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant))
              else
                ...followUps.map<Widget>((it) {
                  final map = Map<String, dynamic>.from(it as Map);
                  final title = map['task']?.toString() ??
                      l10n.meetingFollowUpTaskFallback;
                  final subtitle = l10n.meetingDeadline(
                      '${map['deadline'] ?? l10n.meetingNotApplicable}');
                  return pill(
                    color: Colors.green.shade400,
                    title: title,
                    subtitle: subtitle,
                    onTap: () => _createTaskFromFollowUp(map),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          AppLocalizations.of(context).meetingDeleteTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          AppLocalizations.of(context).meetingDeleteConfirm,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMeeting();
            },
            child: Text(
              AppLocalizations.of(context).meetingDelete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
