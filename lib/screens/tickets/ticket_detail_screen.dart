import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_widgets.dart';
import '../../utils/language/sentence_manager.dart';

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
          // Ensure comments is List<Map<String, dynamic>>
          _comments = (result['comments'] as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else if (mounted) {
        final s = SentenceManager.instance;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s
                .ticketNotFound), // Using generic not found message or fallback
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading ticket details: $e');
      if (mounted) {
        // final s = SentenceManager.instance; // Can't access here easily inside catch without context or if static available
        // But SentenceManager.instance is static getter.
        final s = SentenceManager.instance;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.ticketNotFound}: $e'), // Generic error fallback
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final s = SentenceManager.instance;
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
              content: Text('${s.errorAddingComment}: ${result['error']}'),
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
            content: Text('${s.errorAddingComment}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateTicketStatus(String status) async {
    final s = SentenceManager.instance;
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
            SnackBar(
              content: Text(s.ticketStatusUpdated),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${s.errorUpdatingTicket}: ${result['error']}'),
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
            content: Text('${s.errorUpdatingTicket}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateTicketPriority(String priority) async {
    final s = SentenceManager.instance;
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
            SnackBar(
              content: Text(s.ticketPriorityUpdated),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${s.errorUpdatingTicket}: ${result['error']}'),
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
            content: Text('${s.errorUpdatingTicket}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignTicket(String userId) async {
    final s = SentenceManager.instance;
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
            SnackBar(
              content: Text(s.ticketAssignedSuccess),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${s.errorAssigningTicket}: ${result['error']}'),
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
            content: Text('${s.errorAssigningTicket}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show team members dialog for assignment
  void _showAssignDialog() {
    final s = SentenceManager.instance;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: Text(
            s.assignTicketDialogTitle,
            style: const TextStyle(color: Colors.white),
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
                    s.errorAssigningTicket, // Using generic error
                    style: TextStyle(color: Colors.red.shade400),
                  );
                }

                final teamMembers = snapshot.data ?? [];
                if (teamMembers.isEmpty) {
                  return Text(
                    s.noMembersFound,
                    style: const TextStyle(color: Colors.white),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: teamMembers.length,
                  itemBuilder: (context, index) {
                    final member = teamMembers[index];
                    final fullName = member['full_name'] ?? s.unknownMember;
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
                        isAdmin ? s.teamAdmin : s.teamMember,
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
              child: Text(
                s.cancel,
                style: const TextStyle(color: Colors.white),
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
    // Obx wrapping handled inside specific widgets if needed, but here structure is simple stateful.
    // However, to be reactive to language change, we should wrap the returned Scaffold in Obx.

    return Obx(() {
      final s = SentenceManager.instance;

      if (_isLoading) {
        return Scaffold(
          backgroundColor: const Color(0xFF1A1A1A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF2D2D2D),
            title: Text(s.ticketDetailsTitle),
          ),
          body: const Center(child: CustomLoading()),
        );
      }

      if (_ticket == null) {
        return Scaffold(
          backgroundColor: const Color(0xFF1A1A1A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF2D2D2D),
            title: Text(s.ticketDetailsTitle),
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
                Text(
                  s.ticketNotFound,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.ticketDeleted,
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
      String priorityLabel;
      switch (priority.toLowerCase()) {
        case 'high':
          priorityColor = Colors.red.shade400;
          priorityLabel = s.priorityHigh;
          break;
        case 'medium':
          priorityColor = Colors.orange.shade400;
          priorityLabel = s.priorityMedium;
          break;
        case 'low':
          priorityColor = Colors.green.shade400;
          priorityLabel = s.priorityLow;
          break;
        default:
          priorityColor = Colors.grey;
          priorityLabel = priority;
      }

      Color statusColor;
      String statusLabel;
      switch (status) {
        case 'open':
          statusColor = Colors.blue.shade400;
          statusLabel = s.statusOpen;
          break;
        case 'in_progress':
          statusColor = Colors.orange.shade400;
          statusLabel = s.statusInProgress;
          break;
        case 'resolved':
          statusColor = Colors.green.shade400;
          statusLabel = s.statusResolved;
          break;
        default:
          statusColor = Colors.grey;
          statusLabel = status;
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
          title: Text(_ticket!['ticket_number'] ?? s.ticketDetailsTitle),
          actions: [
            if (_isAdmin)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value.startsWith('status:')) {
                    _updateTicketStatus(value.split(':')[1]);
                  } else if (value.startsWith('priority:')) {
                    _updateTicketPriority(value.split(':')[1]);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'header_status',
                    enabled: false,
                    child: Text(
                      s.changeStatus,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'status:open',
                    child: Text(s.statusOpen),
                  ),
                  PopupMenuItem(
                    value: 'status:in_progress',
                    child: Text(s.statusInProgress),
                  ),
                  PopupMenuItem(
                    value: 'status:resolved',
                    child: Text(s.statusResolved),
                  ),
                  const PopupMenuItem(
                    value: 'divider1',
                    enabled: false,
                    child: Divider(),
                  ),
                  PopupMenuItem(
                    value: 'header_priority',
                    enabled: false,
                    child: Text(
                      s.changePriority,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'priority:high',
                    child: Text(s.priorityHigh),
                  ),
                  PopupMenuItem(
                    value: 'priority:medium',
                    child: Text(s.priorityMedium),
                  ),
                  PopupMenuItem(
                    value: 'priority:low',
                    child: Text(s.priorityLow),
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
                                      priorityLabel.toUpperCase(),
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
                                  statusLabel.toUpperCase(),
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
                            _ticket!['title'] ?? s.untitledTicket,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _ticket!['description'] ?? s.noDescription,
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
                                      s.ticketCreatedBy,
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      _ticket!['creator']['full_name'] ??
                                          s.unknownMember,
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
                                      s.ticketAssignedTo,
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      _ticket!['assignee']['full_name'] ??
                                          s.unknownMember,
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
                                  label: Text(s.assignBtn),
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
                    '${s.commentsTitle} (${_comments.length})',
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
                              s.noComments,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              s.beFirstToComment,
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.blue.shade700,
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
                                  comment['user']['full_name'] ??
                                      s.unknownMember,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
                            const SizedBox(height: 8),
                            Text(
                              comment['content'] ?? '',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Comment input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D2D),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade800),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: s
                            .commentsTitle, // Or 'Add a comment...' if key exists. 'commentsTitle' is 'Comments', so maybe acceptable as hint?
                        // Actually I don't have 'addCommentHint' key anymore?
                        // I'll check if I have a better key.
                        // 'enterTicketDescription' might be close but not exact.
                        // I will use 's.commentsTitle' for now as placeholder for "Comments".
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addComment,
                    icon: const Icon(Icons.send),
                    color: Colors.blue.shade400,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';

    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }
}
