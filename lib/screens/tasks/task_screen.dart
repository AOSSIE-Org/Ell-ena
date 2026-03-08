import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_widgets.dart';
import 'task_detail_screen.dart';
import 'create_task_screen.dart';

class TaskScreen extends StatefulWidget {
  // Create a static key that can be used to access the state
  static final GlobalKey<_TaskScreenState> globalKey =
      GlobalKey<_TaskScreenState>();

  const TaskScreen({Key? key}) : super(key: key);

  // Static method to refresh tasks from anywhere
  static void refreshTasks() {
    globalKey.currentState?.refreshTasks();
  }

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _tasks = [];
  String _selectedStatus = 'todo';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadTeamMembersAndTasks();
    _checkUserRole();
  }

  // This method can be called from outside to refresh tasks
  void refreshTasks() {
    _loadTeamMembersAndTasks();
  }

  // Load team members first, then tasks
  Future<void> _loadTeamMembersAndTasks() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get the user's team ID
      final userProfile = await _supabaseService.getCurrentUserProfile();
      if (userProfile != null && userProfile['team_id'] != null) {
        // Load team members first
        await _supabaseService.loadTeamMembers(userProfile['team_id']);
      }

      // Then load tasks
      await _loadTasks();
    } catch (e) {
      debugPrint('Error loading team members and tasks: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkUserRole() async {
    final userProfile = await _supabaseService.getCurrentUserProfile();
    if (mounted) {
      setState(() {
        _isAdmin = userProfile?['role'] == 'admin';
      });
    }
  }

  Future<void> _loadTasks() async {
    try {
      final tasks = await _supabaseService.getTasks(filterByAssignment: true);

      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateTaskStatus(String taskId, String status) async {
    try {
      await _supabaseService.updateTaskStatus(
        taskId: taskId,
        status: status,
      );

      // Reload tasks after update
      _loadTasks();
    } catch (e) {
      debugPrint('Error updating task status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating task status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateTaskApproval(String taskId, String approvalStatus) async {
    try {
      await _supabaseService.updateTaskApproval(
        taskId: taskId,
        approvalStatus: approvalStatus,
      );

      // Reload tasks after update
      _loadTasks();
    } catch (e) {
      debugPrint('Error updating task approval: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating task approval: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

    // Make sure the key is properly associated with this instance
    if (TaskScreen.globalKey.currentState != this) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        TaskScreen.refreshTasks();
      });
    }

    final todoTasks = _tasks.where((task) => task['status'] == 'todo').toList();
    final inProgressTasks =
        _tasks.where((task) => task['status'] == 'in_progress').toList();
    final completedTasks =
        _tasks.where((task) => task['status'] == 'completed').toList();
    final totalTasks = _tasks.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateTaskScreen(),
              fullscreenDialog: true,
            ),
          );

          if (result == true) {
            _loadTasks();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Task created successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        backgroundColor: Colors.green.shade400,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          _buildProgressHeader(
            completedTasks: completedTasks.length,
            inProgressTasks: inProgressTasks.length,
            todoTasks: todoTasks.length,
            totalTasks: totalTasks,
          ),
          const SizedBox(height: 16),
          _buildStatusTabs(),
          Expanded(
            child: _buildDraggableTaskList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableTaskList() {
    final filteredTasks =
        _tasks.where((task) => task['status'] == _selectedStatus).toList();

    if (filteredTasks.isEmpty) {
      final colorScheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedStatus == 'todo'
                  ? Icons.assignment_outlined
                  : _selectedStatus == 'in_progress'
                      ? Icons.pending_actions_outlined
                      : Icons.task_alt_outlined,
              size: 80,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedStatus == 'todo'
                  ? 'Add new tasks to get started'
                  : _selectedStatus == 'in_progress'
                      ? 'Move tasks here when you start working on them'
                      : 'Completed tasks will appear here',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildStatusChangeHint(),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ReorderableListView.builder(
        itemCount: filteredTasks.length,
        onReorder: (oldIndex, newIndex) {
          // Just for visual reordering, no status change
          setState(() {
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }
            final item = filteredTasks.removeAt(oldIndex);
            filteredTasks.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) {
          final task = filteredTasks[index];
          return Draggable<Map<String, dynamic>>(
            key: ValueKey(task['id']),
            data: task,
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 32,
                child: _TaskCard(
                  task: task,
                  isAdmin: _isAdmin,
                  onStatusChange: _updateTaskStatus,
                  onApprovalChange: _updateTaskApproval,
                  onTap: () {},
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.5,
              child: _TaskCard(
                task: task,
                isAdmin: _isAdmin,
                onStatusChange: _updateTaskStatus,
                onApprovalChange: _updateTaskApproval,
                onTap: () {},
              ),
            ),
            onDragEnd: (details) {
              if (details.wasAccepted) {
                // Status change will be handled by the DragTarget
              }
            },
            child: _TaskCard(
              task: task,
              isAdmin: _isAdmin,
              onStatusChange: _updateTaskStatus,
              onApprovalChange: _updateTaskApproval,
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskDetailScreen(taskId: task['id']),
                  ),
                );

                if (result == true) {
                  _loadTasks();
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChangeHint() {
    final nextStatus = _selectedStatus == 'todo'
        ? 'In Progress'
        : _selectedStatus == 'in_progress'
            ? 'Completed'
            : 'To Do';

    final nextStatusId = _selectedStatus == 'todo'
        ? 'in_progress'
        : _selectedStatus == 'in_progress'
            ? 'completed'
            : 'todo';

    final color = _selectedStatus == 'todo'
        ? Colors.orange
        : _selectedStatus == 'in_progress'
            ? Colors.green
            : Colors.blue;

    return ElevatedButton.icon(
      onPressed: () => setState(() => _selectedStatus = nextStatusId),
      icon: Icon(
        _selectedStatus == 'todo'
            ? Icons.arrow_forward
            : _selectedStatus == 'in_progress'
                ? Icons.check
                : Icons.refresh,
        color: Colors.white,
        size: 16,
      ),
      label: Text(
        'View $nextStatus Tasks',
        style: const TextStyle(color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildStatusTabs() {
    final statusOptions = [
      {'id': 'todo', 'label': 'To Do', 'color': Colors.blue},
      {'id': 'in_progress', 'label': 'In Progress', 'color': Colors.orange},
      {'id': 'completed', 'label': 'Completed', 'color': Colors.green},
    ];

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: statusOptions.map((status) {
          final isSelected = status['id'] == _selectedStatus;
          final color = status['color'] as MaterialColor;

          return Expanded(
            child: DragTarget<Map<String, dynamic>>(
              builder: (context, candidateData, rejectedData) {
                return Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.2)
                        : candidateData.isNotEmpty
                            ? color.withOpacity(0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => setState(
                        () => _selectedStatus = status['id'] as String),
                    borderRadius: BorderRadius.circular(20),
                    child: Center(
                      child: Text(
                        status['label'] as String,
                        style: TextStyle(
                          color: isSelected
                              ? color
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
              onAccept: (task) {
                final newStatus = status['id'] as String;
                if (task['status'] != newStatus) {
                  _updateTaskStatus(task['id'], newStatus);
                }
              },
              onWillAccept: (data) => data != null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProgressHeader({
    required int completedTasks,
    required int inProgressTasks,
    required int todoTasks,
    required int totalTasks,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildProgressStat(
                label: 'To Do',
                value: todoTasks,
                total: totalTasks > 0 ? totalTasks : 1,
                color: Colors.blue.shade400,
              ),
              _buildProgressStat(
                label: 'In Progress',
                value: inProgressTasks,
                total: totalTasks > 0 ? totalTasks : 1,
                color: Colors.orange.shade400,
              ),
              _buildProgressStat(
                label: 'Completed',
                value: completedTasks,
                total: totalTasks > 0 ? totalTasks : 1,
                color: Colors.green.shade400,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Container(
                    height: 8,
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest),
                Row(
                  children: [
                    _buildProgressBar(
                      width: totalTasks > 0 ? todoTasks / totalTasks : 0,
                      color: Colors.blue.shade400,
                    ),
                    _buildProgressBar(
                      width: totalTasks > 0 ? inProgressTasks / totalTasks : 0,
                      color: Colors.orange.shade400,
                    ),
                    _buildProgressBar(
                      width: totalTasks > 0 ? completedTasks / totalTasks : 0,
                      color: Colors.green.shade400,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat({
    required String label,
    required int value,
    required int total,
    required Color color,
  }) {
    final percentage = (value / total * 100).round();
    return Column(
      children: [
        Text(
          '$percentage%',
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildProgressBar({required double width, required Color color}) {
    return Container(
      height: 8,
      width: MediaQuery.of(context).size.width * width - 32 * width,
      color: color,
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final bool isAdmin;
  final Function(String, String) onStatusChange;
  final Function(String, String) onApprovalChange;
  final VoidCallback onTap;

  const _TaskCard({
    required this.task,
    required this.isAdmin,
    required this.onStatusChange,
    required this.onApprovalChange,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String title = task['title'] ?? 'Untitled Task';
    final String description = task['description'] ?? 'No description';
    final String status = task['status'] ?? 'todo';
    final String approvalStatus = task['approval_status'] ?? 'pending';

    // Get names from the team members cache
    final supabaseService = SupabaseService();
    String creatorName;
    if (task['created_by'] != null) {
      if (supabaseService.isCurrentUser(task['created_by'])) {
        creatorName = 'You';
      } else {
        creatorName = supabaseService.getUserNameById(task['created_by']);
      }
    } else {
      creatorName = 'Unknown';
    }

    String assigneeName;
    if (task['assigned_to'] != null) {
      if (supabaseService.isCurrentUser(task['assigned_to'])) {
        assigneeName = 'You';
      } else {
        assigneeName = supabaseService.getUserNameById(task['assigned_to']);
      }
    } else {
      assigneeName = 'Unassigned';
    }

    // Format due date if available
    String dueDate = 'No due date';
    if (task['due_date'] != null) {
      final DateTime date = DateTime.parse(task['due_date']);
      dueDate = '${date.day}/${date.month}/${date.year}';
    }

    // Determine colors based on status
    final Color statusColor = status == 'todo'
        ? Colors.blue
        : status == 'in_progress'
            ? Colors.orange
            : Colors.green;

    final Color approvalColor = approvalStatus == 'pending'
        ? Colors.grey
        : approvalStatus == 'approved'
            ? Colors.green
            : Colors.red;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        status == 'todo'
                            ? Icons.assignment_outlined
                            : status == 'in_progress'
                                ? Icons.pending_actions_outlined
                                : Icons.task_alt_outlined,
                        color: statusColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status == 'todo'
                            ? 'To Do'
                            : status == 'in_progress'
                                ? 'In Progress'
                                : 'Completed',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (isAdmin && approvalStatus == 'pending')
                        Row(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  onApprovalChange(task['id'], 'approved'),
                              icon: Icon(Icons.check_circle,
                                  color: Colors.green.shade400, size: 20),
                              tooltip: 'Approve',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () =>
                                  onApprovalChange(task['id'], 'rejected'),
                              icon: Icon(Icons.cancel,
                                  color: Colors.red.shade400, size: 20),
                              tooltip: 'Reject',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 12),
                          ],
                        ),
                      Row(
                        children: [
                          if (task['created_by'] ==
                                  SupabaseService()
                                      .client
                                      .auth
                                      .currentUser
                                      ?.id ||
                              isAdmin)
                            IconButton(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.surface,
                                    title: Text('Delete Task',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    content: Text(
                                      'Are you sure you want to delete this task? This action cannot be undone.',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: TextButton.styleFrom(
                                            foregroundColor: Colors.red),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  try {
                                    final result = await SupabaseService()
                                        .deleteTask(task['id']);
                                    if (result['success'] == true) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Task deleted successfully'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        // Refresh the task list
                                        TaskScreen.refreshTasks();
                                      }
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(result['error'] ??
                                                'Failed to delete task'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              icon: Icon(Icons.delete_outline,
                                  color: Colors.red.shade400, size: 20),
                              tooltip: 'Delete',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          if (task['created_by'] ==
                                  SupabaseService()
                                      .client
                                      .auth
                                      .currentUser
                                      ?.id ||
                              isAdmin)
                            const SizedBox(width: 8),
                          Text(
                            dueDate,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: approvalColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          approvalStatus.toUpperCase(),
                          style: TextStyle(
                            color: approvalColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.blue.shade700,
                            child: Text(
                              creatorName.isNotEmpty
                                  ? creatorName[0].toUpperCase()
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
                            'Created by $creatorName',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (assigneeName != 'Unassigned')
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.purple.shade700,
                              child: Text(
                                assigneeName.isNotEmpty
                                    ? assigneeName[0].toUpperCase()
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
                              'Assigned to $assigneeName',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Drag handle indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.drag_indicator,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Drag to change status',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
