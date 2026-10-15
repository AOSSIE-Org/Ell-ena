import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/supabase_service.dart';
import '../../utils/task_ticket_link.dart';
import '../../widgets/custom_widgets.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  Map<String, dynamic>? _taskDetails;
  List<Map<String, dynamic>> _comments = [];
  bool _isAdmin = false;
  List<Map<String, dynamic>> _tickets = [];
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTaskDetails();
    _checkUserRole();
    _loadTickets();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    final userProfile = await _supabaseService.getCurrentUserProfile();
    if (mounted) {
      setState(() {
        _isAdmin = userProfile?['role'] == 'admin';
      });
    }
  }

  Future<void> _loadTickets() async {
    try {
      final tickets = await _supabaseService.getTickets();
      if (mounted) {
        setState(() {
          _tickets = tickets;
        });
      }
    } catch (e) {
      debugPrint('Error loading tickets: $e');
    }
  }

  Future<void> _updateLinkedTicket(String? ticketId) async {
    final l10n = AppLocalizations.of(context);
    final result = await _supabaseService.updateTaskTicket(
      taskId: widget.taskId,
      ticketId: TaskTicketLink.normalizeId(ticketId),
    );
    if (!mounted) return;
    if (result['success'] == true) {
      await _loadTaskDetails();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['error']?.toString() ?? l10n.taskLinkedTicketUpdateFailed,
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadTaskDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final details = await _supabaseService.getTaskDetails(widget.taskId);

      if (mounted && details != null) {
        setState(() {
          _taskDetails = details['task'];
          _comments = List<Map<String, dynamic>>.from(details['comments']);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading task details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateTaskStatus(String status) async {
    final l10n = AppLocalizations.of(context);
    try {
      final success = await _supabaseService.updateTaskStatus(
        taskId: widget.taskId,
        status: status,
      );

      if (mounted) {
        if (success == true) {
          // Reload task details
          await _loadTaskDetails();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.taskStatusUpdatedTo(_getStatusLabel(l10n, status)),
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.taskStatusUpdateFailed),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating task status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.taskErrorUpdatingStatus(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateTaskApproval(String approvalStatus) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _supabaseService.updateTaskApproval(
        taskId: widget.taskId,
        approvalStatus: approvalStatus,
      );

      // Reload task details
      _loadTaskDetails();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approvalStatus == 'approved'
                  ? l10n.taskApprovedMessage
                  : l10n.taskRejectedMessage,
            ),
            backgroundColor:
                approvalStatus == 'approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating task approval: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.taskErrorUpdatingApproval(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteTask() async {
    final l10n = AppLocalizations.of(context);
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            l10n.taskDeleteTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Text(
            l10n.taskDeleteConfirmMessage,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l10n.taskDelete),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final result = await _supabaseService.deleteTask(widget.taskId);

      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.taskDeletedSuccess),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // Return true to trigger refresh
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.taskErrorDeleting('${result['error']}')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.taskErrorDeleting(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    final l10n = AppLocalizations.of(context);

    try {
      final result = await _supabaseService.addTaskComment(
        taskId: widget.taskId,
        content: _commentController.text.trim(),
      );

      if (result['success'] && mounted) {
        _commentController.clear();
        _loadTaskDetails();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.taskErrorAddingComment('${result['error']}')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.taskErrorAddingComment(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getStatusLabel(AppLocalizations l10n, String status) {
    switch (status) {
      case 'todo':
        return l10n.taskStatusTodo;
      case 'in_progress':
        return l10n.taskStatusInProgress;
      case 'completed':
        return l10n.taskStatusCompleted;
      default:
        return l10n.taskUnknown;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'todo':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getApprovalColor(String approvalStatus) {
    switch (approvalStatus) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(l10n.taskDetailsTitle),
          backgroundColor: Colors.green.shade800,
        ),
        body: const Center(child: CustomLoading()),
      );
    }

    if (_taskDetails == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(l10n.taskDetailsTitle),
          backgroundColor: Colors.green.shade800,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                l10n.taskNotFound,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.taskMayHaveBeenDeleted,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      );
    }

    final String title = _taskDetails!['title'] ?? l10n.taskUntitled;
    final String description =
        _taskDetails!['description'] ?? l10n.taskNoDescription;
    final String status = _taskDetails!['status'] ?? 'todo';
    final String approvalStatus = _taskDetails!['approval_status'] ?? 'pending';
    final String creatorName =
        _taskDetails!['creator']?['full_name'] ?? l10n.taskUnknown;
    final String assigneeName =
        _taskDetails!['assignee']?['full_name'] ?? l10n.taskUnassigned;

    // Format due date if available
    String dueDate = l10n.taskNoDueDate;
    if (_taskDetails!['due_date'] != null) {
      final DateTime date = DateTime.parse(_taskDetails!['due_date']);
      dueDate = '${date.day}/${date.month}/${date.year}';
    }

    final Color statusColor = _getStatusColor(status);
    final Color approvalColor = _getApprovalColor(approvalStatus);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.taskDetailsTitle),
        backgroundColor: Colors.green.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTaskDetails,
            tooltip: l10n.refresh,
          ),
          // Show delete button if user is creator or admin
          if (_isAdmin ||
              _taskDetails!['created_by'] == _supabaseService.currentUser?.id)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteTask,
              tooltip: l10n.taskDeleteTitle,
              color: Colors.red.shade300,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .shadow
                              .withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    status == 'todo'
                                        ? Icons.assignment_outlined
                                        : status == 'in_progress'
                                            ? Icons.pending_actions_outlined
                                            : Icons.task_alt_outlined,
                                    color: statusColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _getStatusLabel(l10n, status),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: approvalColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: approvalColor),
                              ),
                              child: Text(
                                approvalStatus.toUpperCase(),
                                style: TextStyle(
                                  color: approvalColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.taskDueLabel(dueDate),
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue.shade700,
                              child: Text(
                                creatorName.isNotEmpty
                                    ? creatorName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.taskCreatedBy(creatorName),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.taskLinkedTicket,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Builder(builder: (context) {
                          final linkedId =
                              _taskDetails!['ticket_id']?.toString();
                          final options = <Map<String, dynamic>>[
                            ..._tickets,
                          ];
                          final known = options.any(
                            (ticket) => ticket['id']?.toString() == linkedId,
                          );
                          final current = _taskDetails!['ticket'];
                          if (linkedId != null &&
                              !known &&
                              current is Map<String, dynamic>) {
                            options.insert(0, current);
                          }
                          return DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              value: options.any((ticket) =>
                                      ticket['id']?.toString() == linkedId)
                                  ? linkedId
                                  : null,
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(l10n.taskNoLinkedTicket),
                                ),
                                ...options.map((ticket) {
                                  return DropdownMenuItem<String?>(
                                    value: ticket['id']?.toString(),
                                    child: Text(
                                      TaskTicketLink.labelFor(ticket),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }),
                              ],
                              onChanged: _updateLinkedTicket,
                            ),
                          );
                        }),
                        if (_taskDetails!['assignee']?['full_name'] !=
                            null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.purple.shade700,
                                child: Text(
                                  assigneeName.isNotEmpty
                                      ? assigneeName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.taskAssignedTo(assigneeName),
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Action buttons
                  if (status != 'completed' ||
                      (_isAdmin && approvalStatus == 'pending'))
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.taskActions,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (status == 'todo')
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _updateTaskStatus('in_progress'),
                                  icon: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    l10n.taskStart,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade600,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              if (status == 'in_progress')
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _updateTaskStatus('completed'),
                                  icon: const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    l10n.taskComplete,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              if (_isAdmin && approvalStatus == 'pending') ...[
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _updateTaskApproval('approved'),
                                  icon: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    l10n.taskApprove,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _updateTaskApproval('rejected'),
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    l10n.taskReject,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                  // Comments section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.taskCommentsCount(_comments.length),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_comments.isNotEmpty)
                              TextButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.sort, size: 16),
                                label: Text(l10n.taskLatestFirst),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey.shade400,
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Comment list
                        if (_comments.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 48,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    l10n.taskNoCommentsYet,
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.taskBeFirstToComment,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _comments.length,
                            itemBuilder: (context, index) {
                              final comment = _comments[index];
                              final userName = comment['user']?['full_name'] ??
                                  l10n.taskUnknown;
                              final content = comment['content'] ?? '';
                              final createdAt = DateTime.parse(
                                comment['created_at'],
                              );

                              // Format date
                              final now = DateTime.now();
                              final difference = now.difference(createdAt);
                              String formattedDate;

                              if (difference.inDays > 0) {
                                formattedDate =
                                    l10n.taskDaysAgo(difference.inDays);
                              } else if (difference.inHours > 0) {
                                formattedDate =
                                    l10n.taskHoursAgo(difference.inHours);
                              } else if (difference.inMinutes > 0) {
                                formattedDate =
                                    l10n.taskMinutesAgo(difference.inMinutes);
                              } else {
                                formattedDate = l10n.taskJustNow;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor:
                                              Colors.green.shade700,
                                          child: Text(
                                            userName.isNotEmpty
                                                ? userName[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          userName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          formattedDate,
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      content,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Comment input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: l10n.taskAddCommentHint,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.green.shade400,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _addComment,
                    tooltip: l10n.taskSendComment,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
