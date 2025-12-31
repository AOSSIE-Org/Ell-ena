import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';

import '../../utils/language/sentence_manager.dart';
import '../../services/supabase_service.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _urlController = TextEditingController();
  final _durationController =
      TextEditingController(text: '60'); // Default to 60 minutes
  final _supabaseService = SupabaseService();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;
  bool _isGoogleMeetUrl = true;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  // Validate if the URL is a Google Meet URL
  bool _validateGoogleMeetUrl(String url) {
    if (url.isEmpty) return true; // Empty URL is valid (not required)
    return url.contains('meet.google.com');
  }

  // Check URL and update state
  void _checkUrl(String url) {
    setState(() {
      _isGoogleMeetUrl = _validateGoogleMeetUrl(url);
    });
  }

  Future<void> _createMeeting() async {
    final s = SentenceManager.instance;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.dateRequired),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.timeRequired),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate meeting URL if provided
    final meetingUrl = _urlController.text.trim();
    if (meetingUrl.isNotEmpty && !_validateGoogleMeetUrl(meetingUrl)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.googleMeetUrlError),
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
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Parse duration
      int duration = 60;
      try {
        duration = int.parse(_durationController.text.trim());
        if (duration <= 0) duration = 60;
      } catch (e) {
        // Default to 60 if parsing fails
        duration = 60;
      }

      final result = await _supabaseService.createMeeting(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        meetingDate: meetingDateTime,
        meetingUrl: meetingUrl.isNotEmpty ? meetingUrl : null,
        durationMinutes: duration,
      );

      if (mounted) {
        if (result['success']) {
          Navigator.pop(context, true);
        } else {
          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${s.errorCreatingMeeting}: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating meeting: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.errorCreatingMeeting}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
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
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
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
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = SentenceManager.instance;
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2D2D2D),
          title: Text(s.createMeetingTitle),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.green))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      TextFormField(
                        controller: _titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: '${s.meetingTitleLabel} *',
                          labelStyle: const TextStyle(color: Colors.grey),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return s.titleRequired;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: s.meetingDescriptionLabel,
                          labelStyle: const TextStyle(color: Colors.grey),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
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
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      _selectedDate == null
                                          ? '${s.selectDate} *'
                                          : DateFormat('MMM dd, yyyy')
                                              .format(_selectedDate!),
                                      style: TextStyle(
                                        color: _selectedDate == null
                                            ? Colors.grey
                                            : Colors.white,
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
                                    const Icon(Icons.access_time,
                                        color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      _selectedTime == null
                                          ? '${s.selectTime} *'
                                          : _selectedTime!.format(context),
                                      style: TextStyle(
                                        color: _selectedTime == null
                                            ? Colors.grey
                                            : Colors.white,
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
                        decoration: InputDecoration(
                          labelText: s.meetingDurationLabel,
                          labelStyle: const TextStyle(color: Colors.grey),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green),
                          ),
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            try {
                              int duration = int.parse(value);
                              if (duration <= 0) {
                                return 'Duration must be greater than 0';
                              }
                            } catch (e) {
                              return 'Please enter a valid number';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Meeting URL
                      TextFormField(
                        controller: _urlController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: s.googleMeetUrlHint,
                          labelStyle: const TextStyle(color: Colors.grey),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _urlController.text.isNotEmpty &&
                                      !_isGoogleMeetUrl
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _urlController.text.isNotEmpty &&
                                      !_isGoogleMeetUrl
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                          suffixIcon: _urlController.text.isNotEmpty
                              ? Icon(
                                  _isGoogleMeetUrl
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color: _isGoogleMeetUrl
                                      ? Colors.green
                                      : Colors.red,
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          _checkUrl(value);
                        },
                      ),

                      // Warning message for non-Google Meet URLs
                      if (_urlController.text.isNotEmpty && !_isGoogleMeetUrl)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            s.googleMeetUrlError,
                            style: TextStyle(
                                color: Colors.red.shade300, fontSize: 12),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Create button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _createMeeting,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            s.createMeetingTitle,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      );
    });
  }
}
