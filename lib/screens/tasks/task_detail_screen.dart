import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_widgets.dart';
import '../../controllers/language_controller.dart';
import 'package:get/get.dart';
import '../../utils/language/sentence_manager.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailScreen({
    super.key,
    required this.taskId,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  Map<String, dynamic>? _taskDetails;
  List<Map<String, dynamic>> _comments = [];
  bool _isAdmin = false;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTaskDetails();
    _checkUserRole();
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
    try {
      final success = await _supabaseService.updateTaskStatus(
        taskId: widget.taskId,
        status: status,
      );

      if (mounted) {
        if (success == true) {
          // Reload task details
          await _loadTaskDetails();

          final _languageController = Get.find<LanguageController>();
          final s = SentenceManager(
                  currentLanguage: _languageController.selectedLanguage.value)
              .sentences;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('${s.taskStatusUpdated}: ${_getStatusLabel(status, s)}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          final _languageController = Get.find<LanguageController>();
          final s = SentenceManager(
                  currentLanguage: _languageController.selectedLanguage.value)
              .sentences;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(s.failedUpdateTask),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating task status: $e');
      if (mounted) {
        final _languageController = Get.find<LanguageController>();
        final s = SentenceManager(
                currentLanguage: _languageController.selectedLanguage.value)
            .sentences;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.failedUpdateTask}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateTaskApproval(String approvalStatus) async {
    try {
      await _supabaseService.updateTaskApproval(
        taskId: widget.taskId,
        approvalStatus: approvalStatus,
      );

      // Reload task details
      _loadTaskDetails();

      // Show success message
      if (mounted) {
        final _languageController = Get.find<LanguageController>();
        final s = SentenceManager(
                currentLanguage: _languageController.selectedLanguage.value)
            .sentences;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                approvalStatus == 'approved' ? s.taskApproved : s.taskRejected),
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
            content: Text('Error updating task approval: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      final result = await _supabaseService.addTaskComment(
        taskId: widget.taskId,
        content: _commentController.text.trim(),
      );

      if (result['success'] && mounted) {
        _commentController.clear();
        _loadTaskDetails();
      } else if (mounted) {
        final _languageController = Get.find<LanguageController>();
        final s = SentenceManager(
                currentLanguage: _languageController.selectedLanguage.value)
            .sentences;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.errorAddingComment}: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
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

  String _getStatusLabel(String status, dynamic s) {
    switch (status) {
      case 'todo':
        return s.statusTodo;
      case 'in_progress':
        return s.statusInProgress;
      case 'completed':
        return s.statusCompleted;
      default:
        return s
            .unknownUser; // Reusing unknownUser or add unknownStatus if needed
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
    // Get Controller
    final LanguageController _languageController =
        Get.find<LanguageController>();

    return Obx(() {
      final s = SentenceManager(
              currentLanguage: _languageController.selectedLanguage.value)
          .sentences;

      if (_isLoading) {
        return Scaffold(
          backgroundColor: const Color(0xFF1A1A1A),
          appBar: AppBar(
            title: Text(s.taskDetailsTitle),
            backgroundColor: Colors.green.shade800,
          ),
          body: const Center(child: CustomLoading()),
        );
      }

      if (_taskDetails == null) {
        return Scaffold(
          backgroundColor: const Color(0xFF1A1A1A),
          appBar: AppBar(
            title: Text(s.taskDetailsTitle),
            backgroundColor: Colors.green.shade800,
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
                  s.taskNotFound,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.taskDeleted,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final String title = _taskDetails!['title'] ?? s.untitledTask;
      final String description =
          _taskDetails!['description'] ?? s.noDescription;
      final String status = _taskDetails!['status'] ?? 'todo';
      final String approvalStatus =
          _taskDetails!['approval_status'] ?? 'pending';
      final String creatorName =
          _taskDetails!['creator']?['full_name'] ?? s.unknownUser;
      final String assigneeName =
          _taskDetails!['assignee']?['full_name'] ?? s.unassigned;

      // Format due date if available
      String dueDate = s.noDueDate;
      if (_taskDetails!['due_date'] != null) {
        final DateTime date = DateTime.parse(_taskDetails!['due_date']);
        dueDate = '${date.day}/${date.month}/${date.year}';
      }

      final Color statusColor = _getStatusColor(status);
      final Color approvalColor = _getApprovalColor(approvalStatus);

      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          title: Text(s.taskDetailsTitle),
          backgroundColor: Colors.green.shade800,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadTaskDetails,
              tooltip: s.refreshBtn,
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
                        color: const Color(0xFF2D2D2D),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
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
                                    horizontal: 12, vertical: 6),
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
                                      _getStatusLabel(status, s),
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
                                    horizontal: 12, vertical: 6),
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
                            '${s.taskDueDateLabel}: $dueDate', // Using taskDueDateLabel
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
                                '${s.createdBy} $creatorName',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          if (assigneeName != s.unassigned) ...[
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
                                  '${s.assignedTo} $assigneeName',
                                  style: const TextStyle(
                                    color: Colors.white,
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
                              s.actions,
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
                                    icon: const Icon(Icons.play_arrow,
                                        color: Colors.white),
                                    label: Text(s.startTaskBtn,
                                        style: const TextStyle(
                                            color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade600,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                    ),
                                  ),
                                if (status == 'in_progress')
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _updateTaskStatus('completed'),
                                    icon: const Icon(Icons.check_circle,
                                        color: Colors.white),
                                    label: Text(s.completeTaskBtn,
                                        style: const TextStyle(
                                            color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade600,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                    ),
                                  ),
                                if (_isAdmin &&
                                    approvalStatus == 'pending') ...[
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _updateTaskApproval('approved'),
                                    icon: const Icon(Icons.check,
                                        color: Colors.white),
                                    label: Text(s.approveTaskBtn,
                                        style: const TextStyle(
                                            color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade600,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _updateTaskApproval('rejected'),
                                    icon: const Icon(Icons.close,
                                        color: Colors.white),
                                    label: Text(s.rejectTaskBtn,
                                        style: const TextStyle(
                                            color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade600,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
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
                                '${s.comments} (${_comments.length})',
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
                                  label: Text(s.latestFirst),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 20),
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
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _comments.length,
                              itemBuilder: (context, index) {
                                final comment = _comments[index];
                                final userName =
                                    comment['user']?['full_name'] ?? 'Unknown';
                                final content = comment['content'] ?? '';
                                final createdAt =
                                    DateTime.parse(comment['created_at']);

                                // Format date
                                final now = DateTime.now();
                                final difference = now.difference(createdAt);
                                String formattedDate;

                                if (difference.inDays > 0) {
                                  formattedDate = '${difference.inDays}d ago';
                                } else if (difference.inHours > 0) {
                                  formattedDate = '${difference.inHours}h ago';
                                } else if (difference.inMinutes > 0) {
                                  formattedDate =
                                      '${difference.inMinutes}m ago';
                                } else {
                                  formattedDate = 'Just now';
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2D2D2D),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                color: const Color(0xFF2D2D2D),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
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
                        hintText: s.addCommentHint,
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      style: const TextStyle(color: Colors.white),
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
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
