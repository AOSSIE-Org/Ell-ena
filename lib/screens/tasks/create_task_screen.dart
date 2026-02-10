import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets/unified_form_components.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _supabaseService = SupabaseService();
  bool _isLoading = false;
  DateTime? _selectedDueDate;
  String? _selectedAssigneeId;
  List<Map<String, dynamic>> _teamMembers = [];
  
  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _loadTeamMembers() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userProfile = await _supabaseService.getCurrentUserProfile();
      if (userProfile != null && userProfile['teams'] != null && userProfile['teams']['team_code'] != null) {
        final teamId = userProfile['teams']['team_code'];
        final members = await _supabaseService.getTeamMembers(teamId);
        
        if (mounted) {
          setState(() {
            _teamMembers = members;
            _isLoading = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading team members: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.green.shade400,
              onPrimary: Colors.white,
              surface: const Color(0xFF2D2D2D),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1A1A1A),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && mounted) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }
  
  Future<void> _createTask() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await _supabaseService.createTask(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _selectedDueDate,
        assignedToUserId: _selectedAssigneeId,
      );
      
      if (result['success'] && mounted) {
        Navigator.pop(context, true);
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating task: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating task: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UnifiedDesignTokens.backgroundColor,
      appBar: unifiedCreateAppBar(title: 'Create New Task'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Task title
                    UnifiedTextFormField(
                      label: 'Task Title',
                      hintText: 'Enter task title',
                      controller: _titleController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a task title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: UnifiedDesignTokens.sectionSpacing),
                    
                    // Task description (Optional)
                    UnifiedTextFormField(
                      label: 'Description',
                      hintText: 'Enter task description',
                      controller: _descriptionController,
                      maxLines: 5,
                      isOptional: true,
                    ),
                    const SizedBox(height: UnifiedDesignTokens.sectionSpacing),
                    
                    // Due date (Optional)
                    UnifiedPickerField(
                      label: 'Due Date',
                      displayText: _selectedDueDate == null
                          ? 'Select due date'
                          : '${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}',
                      icon: Icons.calendar_today,
                      onTap: _selectDueDate,
                      isOptional: true,
                    ),
                    const SizedBox(height: UnifiedDesignTokens.sectionSpacing),
                    
                    // Assign to (Optional)
                    UnifiedDropdownField<String>(
                      label: 'Assign To',
                      value: _selectedAssigneeId,
                      isOptional: true,
                      hintText: 'Select team member',
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Unassigned'),
                        ),
                        ..._teamMembers.map((member) {
                          return DropdownMenuItem<String>(
                            value: member['id'],
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.green.shade700,
                                  child: Text(
                                    (member['full_name'] != null && member['full_name'].toString().isNotEmpty)
                                        ? member['full_name'].toString()[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                  Text(member['full_name']?.toString() ?? 'Unknown'),
                                if (member['role'] == 'admin')
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade400.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Admin',
                                      style: TextStyle(
                                        color: Colors.orange.shade400,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedAssigneeId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 32),
                    
                    // Submit button
                    UnifiedActionButton(
                      text: 'Create Task',
                      onPressed: _createTask,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 