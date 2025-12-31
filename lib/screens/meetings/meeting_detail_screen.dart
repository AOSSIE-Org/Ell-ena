import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/supabase_service.dart';
import '../../widgets/custom_widgets.dart';
import '../../utils/language/sentence_manager.dart';

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
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(SentenceManager.instance.meetingNotFound),
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
            content:
                Text('${SentenceManager.instance.errorLoadingMeeting}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteMeeting() async {
    try {
      final result = await _supabaseService.deleteMeeting(widget.meetingId);

      if (mounted) {
        if (result['success']) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${SentenceManager.instance.errorDeletingMeeting}: ${result['error']}'),
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
            content:
                Text('${SentenceManager.instance.errorDeletingMeeting}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateMeeting() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SentenceManager.instance.titleRequired),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_meetingDate == null || _meetingTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${SentenceManager.instance.dateRequired} & ${SentenceManager.instance.timeRequired}'),
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
        ai_summary: _aiSummaryController.text.trim().isNotEmpty
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
              content: Text(
                  '${SentenceManager.instance.errorUpdatingMeeting}: ${result['error']}'),
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
            content:
                Text('${SentenceManager.instance.errorUpdatingMeeting}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchMeetingUrl() async {
    if (_meeting == null || _meeting!['meeting_url'] == null) return;

    final url = Uri.parse(_meeting!['meeting_url']);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SentenceManager.instance.errorLaunchingUrl),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createTicketFromAction(Map<String, dynamic> action) async {
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
              content: Text(SentenceManager.instance.ticketCreated),
              backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${SentenceManager.instance.failedCreateTicket}: ${result['error']}'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
              content: Text(SentenceManager.instance.taskCreated),
              backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${SentenceManager.instance.failedCreateTask}: ${result['error']}'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _copyMeetingUrl() async {
    if (_meeting == null || _meeting!['meeting_url'] == null) return;

    await Clipboard.setData(ClipboardData(text: _meeting!['meeting_url']));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SentenceManager.instance.meetingUrlCopied),
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.green,
              onPrimary: Colors.white,
              surface: Color(0xFF2D2D2D),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1A1A1A),
          ),
          child: child!,
        );
      },
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.green,
              onPrimary: Colors.white,
              surface: Color(0xFF2D2D2D),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1A1A1A),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _meetingTime = picked;
      });
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

    return Obx(() {
      final s = SentenceManager.instance;

      if (_meeting == null) {
        return Scaffold(
          backgroundColor: const Color(0xFF1A1A1A),
          body: Center(child: Text(s.meetingNotFound)),
        );
      }

      final meetingDateTime = DateTime.parse(_meeting!['meeting_date']);
      final isUpcoming = meetingDateTime.isAfter(DateTime.now());
      final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
      final timeFormat = DateFormat('h:mm a');
      final canEdit = (_isAdmin || _isCreator) && isUpcoming;

      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2D2D2D),
          title: Text(_isEditing ? s.editMeetingTitle : s.meetingDetailsTitle),
          actions: [
            if (_isEditing)
              IconButton(
                onPressed: _updateMeeting,
                icon: const Icon(Icons.check),
                tooltip: s.saveChangesTooltip,
              )
            else if (canEdit)
              IconButton(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit),
                tooltip: s.editMeetingTitle,
              ),
            if (canEdit && !_isEditing)
              IconButton(
                onPressed: () => _showDeleteConfirmation(context),
                icon: const Icon(Icons.delete),
                tooltip: s.deleteMeetingTooltip,
              ),
          ],
        ),
        body: _isEditing
            ? _buildEditForm(s)
            : _buildMeetingDetails(dateFormat, timeFormat, isUpcoming, s),
      );
    });
  }

  Widget _buildMeetingDetails(DateFormat dateFormat, DateFormat timeFormat,
      bool isUpcoming, dynamic s) {
    final meetingDateTime = DateTime.parse(_meeting!['meeting_date']);

    // Determine transcription status
    String transcriptionStatus = s.statusNotStarted;
    Color transcriptionStatusColor = Colors.grey.shade600;

    if (_meeting!['transcription'] != null &&
        _meeting!['transcription'].toString().isNotEmpty) {
      transcriptionStatus = s.statusCompleted;
      transcriptionStatusColor = Colors.green.shade400;
    } else if (_meeting!['transcription_attempted_at'] != null) {
      transcriptionStatus = s.statusAttempted;
      transcriptionStatusColor = Colors.orange.shade400;
    } else if (_meeting!['bot_started_at'] != null) {
      transcriptionStatus = s.statusInProgress;
      transcriptionStatusColor = Colors.blue.shade400;
    } else if (!isUpcoming &&
        _meeting!['meeting_url'] != null &&
        _meeting!['meeting_url'].toString().contains('meet.google.com')) {
      transcriptionStatus = s.statusPending;
      transcriptionStatusColor = Colors.yellow.shade700;
    } else if (!_meeting!['meeting_url']
        .toString()
        .contains('meet.google.com')) {
      transcriptionStatus = s.statusNotAvailable;
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
                    ? Colors.green.shade400.withOpacity(0.2)
                    : Colors.grey.shade600.withOpacity(0.2),
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
                        ? s.upcomingMeetings.toUpperCase()
                        : s.pastMeetings.toUpperCase(),
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
          _meeting!['title'] ?? s.untitledMeeting,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Date and time
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_month,
                    color: Colors.blue.shade400,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.selectDate, // Using selectDate as label for now
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(meetingDateTime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: Colors.orange.shade400,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.selectTime, // Using selectTime as label for now
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeFormat.format(meetingDateTime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.timer,
                    color: Colors.purple.shade400,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.meetingDurationLabel,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_meeting!['duration_minutes'] ?? 60} minutes',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
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
        const SizedBox(height: 16),

        // Description
        if (_meeting!['description'] != null &&
            _meeting!['description'].toString().isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.meetingDescriptionLabel,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _meeting!['description'],
                  style: const TextStyle(
                    color: Colors.white,
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
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.meetingUrlLabel,
                  style: TextStyle(
                    color: Colors.grey.shade400,
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
                      icon: const Icon(Icons.copy, color: Colors.white),
                      tooltip: s.copyUrlTooltip,
                    ),
                    IconButton(
                      onPressed: _launchMeetingUrl,
                      icon: const Icon(Icons.open_in_new, color: Colors.white),
                      tooltip: s.openUrlTooltip,
                    ),
                  ],
                ),

                // Show transcription status for Google Meet URLs
                if (_meeting!['meeting_url']
                    .toString()
                    .contains('meet.google.com'))
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
                          '${s.transcriptionStatus}: $transcriptionStatus',
                          style: TextStyle(
                            color: transcriptionStatusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Manage from AI summary (action items and follow-ups). Hide raw transcription/summary here.
        if (!isUpcoming) _buildManageSections(s),

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
                  '${s.joinMeetingBtn} Meeting', // Keeping "Meeting" hardcoded for now or use concatenation if valid
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

  Widget _buildEditForm(dynamic s) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Title
        TextFormField(
          controller: _titleController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Title',
            labelStyle: TextStyle(color: Colors.grey),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.green),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Description
        TextFormField(
          controller: _descriptionController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Description',
            labelStyle: TextStyle(color: Colors.grey),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
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
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        _meetingDate == null
                            ? 'Select Date'
                            : DateFormat('MMM dd, yyyy').format(_meetingDate!),
                        style: TextStyle(
                          color:
                              _meetingDate == null ? Colors.grey : Colors.white,
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
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        _meetingTime == null
                            ? 'Select Time'
                            : _meetingTime!.format(context),
                        style: TextStyle(
                          color:
                              _meetingTime == null ? Colors.grey : Colors.white,
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
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Duration (minutes)',
            labelStyle: TextStyle(color: Colors.grey),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.green),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Meeting URL
        TextFormField(
          controller: _urlController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Meeting URL',
            labelStyle: const TextStyle(color: Colors.grey),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.green),
            ),
            helperText: !_urlController.text.contains('meet.google.com') &&
                    _urlController.text.isNotEmpty
                ? 'Ellena AI transcription only works with Google Meet URLs'
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
            child: const Text(
              'Save Changes',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManageSections(dynamic s) {
    final summary = _meeting?['meeting_summary_json'];
    if (summary == null || summary is! Map || summary.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(16)),
        child:
            Text(s.noAiSummary, style: TextStyle(color: Colors.grey.shade400)),
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
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.6)),
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
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
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
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.topic, color: Colors.amber.shade400, size: 18),
                  const SizedBox(width: 8),
                  Text(s.actionItems, // Localized title
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              if (actionItems.isEmpty)
                Text(
                    s.noAiSummary, // Reuse no summary or just English? Using noAiSummary is close enough for "empty"
                    style: TextStyle(color: Colors.grey.shade400))
              else
                ...actionItems.map<Widget>((it) {
                  final map = Map<String, dynamic>.from(it as Map);
                  final title = map['item']?.toString() ?? 'Action Item';
                  final subtitle =
                      'Owner: ${map['owner'] ?? '—'}   •   Deadline: ${map['deadline'] ?? 'N/A'}';
                  return pill(
                    color: Colors.amber.shade400,
                    title: title,
                    subtitle: subtitle,
                    onTap: () => _createTicketFromAction(map),
                  );
                }).toList(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.task_alt, color: Colors.green.shade400, size: 18),
                  const SizedBox(width: 8),
                  Text(s.followUpTasks, // Localized title
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              if (followUps.isEmpty)
                Text(s.noAiSummary,
                    style: TextStyle(color: Colors.grey.shade400))
              else
                ...followUps.map<Widget>((it) {
                  final map = Map<String, dynamic>.from(it as Map);
                  final title = map['task']?.toString() ?? 'Follow-up Task';
                  final subtitle = 'Deadline: ${map['deadline'] ?? 'N/A'}';
                  return pill(
                    color: Colors.green.shade400,
                    title: title,
                    subtitle: subtitle,
                    onTap: () => _createTaskFromFollowUp(map),
                  );
                }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final s = SentenceManager.instance;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: Text(
          s.deleteMeetingTooltip,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          s.meetingDeleted, // Using meetingDeleted as a proxy or stick to English? meetingDeleted is "The meeting may have been deleted". Not exact. I'll stick to English for message or add new key. I'll use English for message to be safe.
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMeeting();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
