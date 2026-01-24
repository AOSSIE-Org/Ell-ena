import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_widgets.dart';
import '../../utils/language/sentence_manager.dart';

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

  bool _isLoading = false;
  String _priority = 'medium';
  String _category = 'Bug';
  String? _assignedTo;
  List<Map<String, dynamic>> _teamMembers = [];
  bool _isLoadingMembers = true;

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
    try {
      final userProfile = await _supabaseService.getCurrentUserProfile();
      if (userProfile != null && userProfile['team_id'] != null) {
        await _supabaseService.loadTeamMembers(userProfile['team_id']);
        if (mounted) {
          setState(() {
            _teamMembers = _supabaseService.teamMembersCache;
            _isLoadingMembers = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingMembers = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading team members: $e');
      if (mounted) {
        setState(() {
          _isLoadingMembers = false;
        });
      }
    }
  }

  Future<void> _createTicket() async {
    if (!_formKey.currentState!.validate()) return;

    final s = SentenceManager.instance;
    setState(() {
      _isLoading = true;
    });

    try {
      await _supabaseService.createTicket(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _priority,
        category: _category,
        assignedToUserId: _assignedTo,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error creating ticket: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.errorPrefix}$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = SentenceManager.instance;
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            s.createTicketTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CustomLoading())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: _titleController,
                        label: s.ticketTitleLabel,
                        hint: s.enterTicketTitle,
                        maxLines: 1,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return s.enterTicketTitle;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _descriptionController,
                        label: s.ticketDescriptionLabel,
                        hint: s.enterTicketDescription,
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return s.enterTicketDescription;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown<String>(
                              value: _priority,
                              items: const ['high', 'medium', 'low'],
                              label: s.ticketPriorityLabel,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _priority = value);
                                }
                              },
                              itemLabelBuilder: (item) {
                                switch (item) {
                                  case 'high':
                                    return s.priorityHigh;
                                  case 'medium':
                                    return s.priorityMedium;
                                  case 'low':
                                    return s.priorityLow;
                                  default:
                                    return item;
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdown<String>(
                              value: _category,
                              items: const [
                                'Bug',
                                'Feature Request',
                                'UI/UX',
                                'Performance',
                                'Documentation',
                                'Security'
                              ],
                              label: s.ticketCategoryLabel,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _category = value);
                                }
                              },
                              itemLabelBuilder: (item) {
                                // Map English category keys to localized labels
                                switch (item) {
                                  case 'Bug':
                                    return s.categoryBug;
                                  case 'Feature Request':
                                    return s.categoryFeatureRequest;
                                  case 'UI/UX':
                                    return s.categoryUiUx;
                                  case 'Performance':
                                    return s.categoryPerformance;
                                  case 'Documentation':
                                    return s.categoryDocumentation;
                                  case 'Security':
                                    return s.categorySecurity;
                                  default:
                                    return item;
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        s.ticketAssigneeLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _isLoadingMembers
                          ? const Center(child: CircularProgressIndicator())
                          : Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D2D2D),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade800),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _assignedTo,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF2D2D2D),
                                  hint: Text(
                                    s.selectTicketAssignee,
                                    style:
                                        TextStyle(color: Colors.grey.shade500),
                                  ),
                                  icon: const Icon(Icons.arrow_drop_down,
                                      color: Colors.white),
                                  items: [
                                    DropdownMenuItem<String>(
                                      value: null,
                                      child: Row(
                                        children: [
                                          const CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Colors.grey,
                                            child: Icon(Icons.person_off,
                                                size: 14, color: Colors.white),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            s.unassigned,
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ..._teamMembers.map((member) {
                                      return DropdownMenuItem<String>(
                                        value: member['id'],
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 12,
                                              backgroundColor:
                                                  Colors.blue.shade700,
                                              child: Text(
                                                (member['full_name'] as String)
                                                        .isNotEmpty
                                                    ? (member['full_name']
                                                            as String)[0]
                                                        .toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              member['full_name'] ??
                                                  s.unknownMember,
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
                                            if (member['role'] == 'admin') ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  // 'ADMIN',
                                                  s.teamAdmin,
                                                  style: TextStyle(
                                                    color: Colors.red.shade400,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _assignedTo = value;
                                    });
                                  },
                                ),
                              ),
                            ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _createTicket,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            s.createTicketTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required int maxLines,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade600),
            filled: true,
            fillColor: const Color(0xFF2D2D2D),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.green, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required String label,
    required ValueChanged<T?> onChanged,
    required String Function(T) itemLabelBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF2D2D2D),
              style: const TextStyle(color: Colors.white),
              items: items.map((T item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabelBuilder(item)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
