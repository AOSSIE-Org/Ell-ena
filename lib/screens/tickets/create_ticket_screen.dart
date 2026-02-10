import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets/unified_form_components.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _supabaseService = SupabaseService();
  
  String _selectedPriority = 'medium';
  String _selectedCategory = 'Bug';
  List<Map<String, dynamic>> _teamMembers = [];
  String? _selectedAssignee;
  bool _isLoading = true;
  
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
      if (userProfile != null && userProfile['team_id'] != null) {
        // Load team members cache first
        await _supabaseService.loadTeamMembers(userProfile['team_id']);
        
        // Get team members from cache
        final teamMembers = _supabaseService.teamMembersCache;
        
        if (mounted) {
          setState(() {
            _teamMembers = teamMembers;
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
  
  Future<void> _createTicket() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await _supabaseService.createTicket(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _selectedPriority,
        category: _selectedCategory,
        assignedToUserId: _selectedAssignee,
      );
      
      if (result['success']) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create ticket: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating ticket: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating ticket: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketCategories = _supabaseService.getTicketCategories();
    
    return Scaffold(
      backgroundColor: UnifiedDesignTokens.backgroundColor,
      appBar: unifiedCreateAppBar(title: 'Create Ticket'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    UnifiedTextFormField(
                      label: 'Ticket Title',
                      hintText: 'Enter ticket title',
                      controller: _titleController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: UnifiedDesignTokens.sectionSpacing),
                    
                    // Description
                    UnifiedTextFormField(
                      label: 'Description',
                      hintText: 'Enter ticket description (max 75 words recommended)',
                      controller: _descriptionController,
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: UnifiedDesignTokens.sectionSpacing),
                    
                    // Priority
                    const Text(
                      'Priority',
                      style: UnifiedDesignTokens.labelStyle,
                    ),
                    const SizedBox(height: UnifiedDesignTokens.labelSpacing),
                    Row(
                      children: [
                        _buildPriorityOption('low', 'Low', Colors.green.shade400),
                        const SizedBox(width: 8),
                        _buildPriorityOption('medium', 'Medium', Colors.orange.shade400),
                        const SizedBox(width: 8),
                        _buildPriorityOption('high', 'High', Colors.red.shade400),
                      ],
                    ),
                    const SizedBox(height: UnifiedDesignTokens.sectionSpacing),
                    
                    // Category
                    UnifiedDropdownField<String>(
                      label: 'Category',
                      value: _selectedCategory,
                      items: ticketCategories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: UnifiedDesignTokens.sectionSpacing),
                    
                    // Assignee (Optional)
                    UnifiedDropdownField<String?>(
                      label: 'Assign To',
                      value: _selectedAssignee,
                      isOptional: true,
                      hintText: 'Select team member',
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Unassigned'),
                        ),
                        ..._teamMembers.map((member) {
                          return DropdownMenuItem<String?>(
                            value: member['id'],
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.green.shade700,
                                  child: Text(
                                    member['full_name'] != null && member['full_name'].isNotEmpty
                                        ? member['full_name'][0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(member['full_name'] ?? 'Unknown'),
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
                          _selectedAssignee = value;
                        });
                      },
                    ),
                    const SizedBox(height: 32),
                    
                    // Submit button
                    UnifiedActionButton(
                      text: 'Create Ticket',
                      onPressed: _createTicket,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildPriorityOption(String value, String label, Color color) {
    final isSelected = _selectedPriority == value;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPriority = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : UnifiedDesignTokens.surfaceColor,
            borderRadius: BorderRadius.circular(UnifiedDesignTokens.borderRadius),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                value == 'high'
                    ? Icons.priority_high
                    : value == 'medium'
                        ? Icons.remove_circle_outline
                        : Icons.arrow_downward,
                color: isSelected ? color : Colors.grey,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 