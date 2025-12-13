import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_widgets.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;

  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _supabaseService = SupabaseService();
  final _commentController = TextEditingController();

  bool _isLoading = true;
  bool _isAdmin = false;
  Map<String, dynamic>? _ticket;
  List<Map<String, dynamic>> _comments = [];

  @override
  void initState() {
    super.initState();
    _loadTicketDetails();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadTicketDetails() async {
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

      // Load team members first
      if (userProfile != null && userProfile['team_id'] != null) {
        await _supabaseService.loadTeamMembers(userProfile['team_id']);
      }

      // Get ticket details
      final result = await _supabaseService.getTicketDetails(widget.ticketId);

      if (result != null && mounted) {
        setState(() {
          _ticket = result['ticket'];
          _comments = List<Map<String, dynamic>>.from(result['comments']);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load ticket details'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading ticket details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading ticket details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteTicket() async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Delete Ticket',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to delete this ticket? This action cannot be undone.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final result = await _supabaseService.deleteTicket(widget.ticketId);

      if (mounted) {
        if (result['success']) {
          Navigator.of(context).pop(true); // Return true to trigger refresh
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ticket deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting ticket: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting ticket: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting ticket: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      final result = await _supabaseService.addTicketComment(
        ticketId: widget.ticketId,
        content: _commentController.text.trim(),
      );

      if (result['success']) {
        setState(() {
          _comments.add(result['comment']);
          _commentController.clear();
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add comment: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error adding comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateTicketStatus(String status) async {
    try {
      final result = await _supabaseService.updateTicketStatus(
        ticketId: widget.ticketId,
        status: status,
      );

      if (result['success']) {
        setState(() {
          if (_ticket != null) {
            _ticket!['status'] = status;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ticket status updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Failed to update ticket status: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating ticket status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating ticket status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateTicketPriority(String priority) async {
    try {
      final result = await _supabaseService.updateTicketPriority(
        ticketId: widget.ticketId,
        priority: priority,
      );

      if (result['success']) {
        setState(() {
          if (_ticket != null) {
            _ticket!['priority'] = priority;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ticket priority updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Failed to update ticket priority: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating ticket priority: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating ticket priority: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignTicket(String userId) async {
    try {
      final result = await _supabaseService.assignTicket(
        ticketId: widget.ticketId,
        userId: userId,
      );

      if (result['success']) {
        // Reload ticket details to get updated assignee info
        _loadTicketDetails();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ticket assigned successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to assign ticket: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error assigning ticket: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning ticket: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show team members dialog for assignment
  void _showAssignDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: const Text(
            'Assign Ticket',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _getTeamMembers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Text(
                    'Error loading team members',
                    style: TextStyle(color: Colors.red.shade400),
                  );
                }

                final teamMembers = snapshot.data ?? [];
                if (teamMembers.isEmpty) {
                  return const Text(
                    'No team members found',
                    style: TextStyle(color: Colors.white),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: teamMembers.length,
                  itemBuilder: (context, index) {
                    final member = teamMembers[index];
                    final fullName = member['full_name'] ?? 'Unknown';
                    final isAdmin = member['role'] == 'admin';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isAdmin
                            ? Colors.orange.shade700
                            : Colors.blue.shade700,
                        child: Text(
                          fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        fullName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        isAdmin ? 'Admin' : 'Team Member',
                        style: TextStyle(
                          color: isAdmin
                              ? Colors.orange.shade400
                              : Colors.grey.shade400,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _assignTicket(member['id']);
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getTeamMembers() async {
    try {
      final userProfile = await _supabaseService.getCurrentUserProfile();
      if (userProfile != null && userProfile['team_id'] != null) {
        return _supabaseService.teamMembersCache;
      }
      return [];
    } catch (e) {
      debugPrint('Error getting team members: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2D2D2D),
          title: const Text('Ticket Details'),
        ),
        body: const Center(child: CustomLoading()),
      );
    }

    if (_ticket == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2D2D2D),
          title: const Text('Ticket Details'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'Ticket not found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The ticket may have been deleted or you do not have access to it.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final priority = _ticket!['priority'] as String;
    final status = _ticket!['status'] as String;
    final approvalStatus = _ticket!['approval_status'] as String;

    Color priorityColor;
    switch (priority.toLowerCase()) {
      case 'high':
        priorityColor = Colors.red.shade400;
        break;
      case 'medium':
        priorityColor = Colors.orange.shade400;
        break;
      case 'low':
        priorityColor = Colors.green.shade400;
        break;
      default:
        priorityColor = Colors.grey;
    }

    Color statusColor;
    switch (status) {
      case 'open':
        statusColor = Colors.blue.shade400;
        break;
      case 'in_progress':
        statusColor = Colors.orange.shade400;
        break;
      case 'resolved':
        statusColor = Colors.green.shade400;
        break;
      default:
        statusColor = Colors.grey;
    }

    Color approvalColor;
    IconData approvalIcon;
    switch (approvalStatus) {
      case 'approved':
        approvalColor = Colors.green.shade400;
        approvalIcon = Icons.check_circle;
        break;
      case 'rejected':
        approvalColor = Colors.red.shade400;
        approvalIcon = Icons.cancel;
        break;
      case 'pending':
      default:
        approvalColor = Colors.grey;
        approvalIcon = Icons.pending;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        title: Text(_ticket!['ticket_number'] ?? 'Ticket Details'),
        actions: [
          if (_isAdmin ||
              _ticket!['created_by'] == _supabaseService.currentUser?.id)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteTicket();
                } else if (value.startsWith('status:')) {
                  _updateTicketStatus(value.split(':')[1]);
                } else if (value.startsWith('priority:')) {
                  _updateTicketPriority(value.split(':')[1]);
                }
              },
              itemBuilder: (context) => [
                if (_isAdmin) ...[
                  const PopupMenuItem(
                    value: 'header_status',
                    enabled: false,
                    child: Text(
                      'Change Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'status:open',
                    child: Text('Open'),
                  ),
                  const PopupMenuItem(
                    value: 'status:in_progress',
                    child: Text('In Progress'),
                  ),
                  const PopupMenuItem(
                    value: 'status:resolved',
                    child: Text('Resolved'),
                  ),
                  const PopupMenuItem(
                    value: 'divider1',
                    enabled: false,
                    child: Divider(),
                  ),
                  const PopupMenuItem(
                    value: 'header_priority',
                    enabled: false,
                    child: Text(
                      'Change Priority',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'priority:high',
                    child: Text('High'),
                  ),
                  const PopupMenuItem(
                    value: 'priority:medium',
                    child: Text('Medium'),
                  ),
                  const PopupMenuItem(
                    value: 'priority:low',
                    child: Text('Low'),
                  ),
                  const PopupMenuItem(
                    value: 'divider2',
                    enabled: false,
                    child: Divider(),
                  ),
                ],
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete Ticket',
                          style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Ticket header
                Card(
                  color: const Color(0xFF2D2D2D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: priorityColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.flag,
                                    color: priorityColor,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    priority.toUpperCase(),
                                    style: TextStyle(
                                      color: priorityColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase().replaceAll('_', ' '),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: approvalColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    approvalIcon,
                                    color: approvalColor,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    approvalStatus.toUpperCase(),
                                    style: TextStyle(
                                      color: approvalColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _ticket!['category'] ?? 'Other',
                                style: TextStyle(
                                  color: Colors.purple.shade300,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _ticket!['title'] ?? 'Untitled Ticket',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _ticket!['description'] ?? 'No description provided.',
                          style: TextStyle(
                            color: Colors.grey.shade300,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.grey),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (_ticket!['creator'] != null) ...[
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.green.shade700,
                                child: Text(
                                  _ticket!['creator']['full_name'] != null &&
                                          _ticket!['creator']['full_name']
                                              .isNotEmpty
                                      ? _ticket!['creator']['full_name'][0]
                                          .toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Created by',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _ticket!['creator']['full_name'] ??
                                        'Unknown',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const Spacer(),
                            if (_ticket!['assignee'] != null) ...[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Assigned to',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _ticket!['assignee']['full_name'] ??
                                        'Unknown',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.blue.shade700,
                                child: Text(
                                  _ticket!['assignee']['full_name'] != null &&
                                          _ticket!['assignee']['full_name']
                                              .isNotEmpty
                                      ? _ticket!['assignee']['full_name'][0]
                                          .toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ] else ...[
                              ElevatedButton.icon(
                                onPressed: _showAssignDialog,
                                icon: const Icon(Icons.person_add, size: 16),
                                label: const Text('Assign'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Comments section
                Text(
                  'Comments (${_comments.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                if (_comments.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No comments yet',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Be the first to add a comment',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                ...List.generate(_comments.length, (index) {
                  final comment = _comments[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    color: const Color(0xFF2D2D2D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (comment['user'] != null) ...[
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.green.shade700,
                                  child: Text(
                                    comment['user']['full_name'] != null &&
                                            comment['user']['full_name']
                                                .isNotEmpty
                                        ? comment['user']['full_name'][0]
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
                                  comment['user']['full_name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Text(
                                _formatDate(comment['created_at']),
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            comment['content'] ?? '',
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // Add extra space at the bottom for the comment input
                const SizedBox(height: 80),
              ],
            ),
          ),

          // Comment input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addComment,
                  icon: const Icon(Icons.send_rounded),
                  color: Colors.green.shade400,
                  iconSize: 28,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';

    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}
