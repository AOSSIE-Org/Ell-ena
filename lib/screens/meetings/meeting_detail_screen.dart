import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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
            const SnackBar(
              content: Text('Meeting not found'),
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
            content: Text('Error loading meeting details: $e'),
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
              content: Text('Error deleting meeting: ${result['error']}'),
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
            content: Text('Error deleting meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateMeeting() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_meetingDate == null || _meetingTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select date and time'),
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
              content: Text('Error updating meeting: ${result['error']}'),
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
            content: Text('Error updating meeting: $e'),
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
          const SnackBar(
            content: Text('Could not launch meeting URL'),
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
          const SnackBar(
              content: Text('Ticket created'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to create ticket: ${result['error']}'),
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
          const SnackBar(
              content: Text('Task created'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to create task: ${result['error']}'),
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
        const SnackBar(
          content: Text('Meeting URL copied to clipboard'),
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CustomLoading()),
      );
    }

    if (_meeting == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: Text('Meeting not found')),
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
        title: Text(_isEditing ? 'Edit Meeting' : 'Meeting Details'),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _updateMeeting,
              icon: const Icon(Icons.check),
              tooltip: 'Save Changes',
            )
          else if (canEdit)
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Meeting',
            ),
          if (canEdit && !_isEditing)
            IconButton(
              onPressed: () => _showDeleteConfirmation(context),
              icon: const Icon(Icons.delete),
              tooltip: 'Delete Meeting',
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
    final meetingDateTime = DateTime.parse(_meeting!['meeting_date']);

    // Determine transcription status
    String transcriptionStatus = 'Not started';
    Color transcriptionStatusColor = Colors.grey.shade600;

    if (_meeting!['transcription'] != null &&
        _meeting!['transcription'].toString().isNotEmpty) {
      transcriptionStatus = 'Completed';
      transcriptionStatusColor = Colors.green.shade400;
    } else if (_meeting!['transcription_attempted_at'] != null) {
      transcriptionStatus = 'Attempted';
      transcriptionStatusColor = Colors.orange.shade400;
    } else if (_meeting!['bot_started_at'] != null) {
      transcriptionStatus = 'In progress';
      transcriptionStatusColor = Colors.blue.shade400;
    } else if (!isUpcoming &&
        _meeting!['meeting_url'] != null &&
        _meeting!['meeting_url'].toString().contains('meet.google.com')) {
      transcriptionStatus = 'Pending';
      transcriptionStatusColor = Colors.yellow.shade700;
    } else if (!_meeting!['meeting_url']
        .toString()
        .contains('meet.google.com')) {
      transcriptionStatus = 'Not available';
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
                    isUpcoming ? 'UPCOMING' : 'PAST',
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
          _meeting!['title'] ?? 'Untitled Meeting',
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
                    color: cs.shadow.withOpacity(0.1),
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
                            Text('Date',
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
                            Text('Time',
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
                            Text('Duration',
                                style: TextStyle(
                                    color: cs.onSurfaceVariant, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                                '${_meeting!['duration_minutes'] ?? 60} minutes',
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
                  'Description',
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
                  'Meeting URL',
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
                      tooltip: 'Copy URL',
                    ),
                    IconButton(
                      onPressed: _launchMeetingUrl,
                      icon: Icon(Icons.open_in_new,
                          color: Theme.of(context).colorScheme.onSurface),
                      tooltip: 'Open URL',
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
                          'Transcription: $transcriptionStatus',
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
              children: const [
                Icon(Icons.video_call, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Join Meeting',
                  style: TextStyle(
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
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Title
        TextFormField(
          controller: _titleController,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: 'Title',
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
            labelText: 'Description',
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
                            ? 'Select Date'
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
                            ? 'Select Time'
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
            labelText: 'Duration (minutes)',
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
            labelText: 'Meeting URL',
            labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: colorScheme.outline),
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

  Widget _buildManageSections() {
    final summary = _meeting?['meeting_summary_json'];
    if (summary == null || summary is! Map || summary.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16)),
        child: Text('AI summary not available yet.',
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
                  Text('Manage Important Discussion',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              if (actionItems.isEmpty)
                Text('No action items detected',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant))
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
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.task_alt, color: Colors.green.shade400, size: 18),
                  const SizedBox(width: 8),
                  Text('Manage Tasks',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              if (followUps.isEmpty)
                Text('No follow-up tasks detected',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant))
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Delete Meeting',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: const Text(
          'Are you sure you want to delete this meeting? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
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
