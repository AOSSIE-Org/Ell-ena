import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/adaptive_create_flow.dart';
import '../../shell/app_shell.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/detail_side_panel.dart';
import 'task_detail_screen.dart';
import 'create_task_screen.dart';

class TaskScreen extends StatefulWidget {
  // Create a static key that can be used to access the state
  static final GlobalKey<_TaskScreenState> _globalKey =
      GlobalKey<_TaskScreenState>();
  static GlobalKey<State<TaskScreen>> get globalKey => _globalKey;

  const TaskScreen({super.key});

  // Static method to refresh tasks from anywhere
  static void refreshTasks() {
    _globalKey.currentState?.refreshTasks();
  }

  /// Opens the create-task screen; used by the wide shell's top bar.
  static void openCreateTask() {
    _globalKey.currentState?._openCreateTask();
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

  /// Task shown in the side panel on wide screens.
  String? _selectedTaskId;

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
      final tasks = await _supabaseService.getTasks();

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
    final l10n = AppLocalizations.of(context);
    try {
      final result = await _supabaseService.updateTaskStatus(
        taskId: taskId,
        status: status,
      );

      // Reload tasks after update
      _loadTasks();
      if (result['success'] != true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.taskErrorUpdatingStatus('${result['error']}')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating task status: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.taskErrorUpdatingStatus(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateTaskApproval(String taskId, String approvalStatus) async {
    final l10n = AppLocalizations.of(context);
    try {
      final result = await _supabaseService.updateTaskApproval(
        taskId: taskId,
        approvalStatus: approvalStatus,
      );

      // Reload tasks after update
      _loadTasks();
      if (result['success'] != true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.taskErrorUpdatingApproval('${result['error']}')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating task approval: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.taskErrorUpdatingApproval(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openCreateTask() async {
    final l10n = AppLocalizations.of(context);
    final result = await openCreateFlow(
      context,
      const CreateTaskScreen(),
      fullscreenDialog: true,
    );

    if (result == true) {
      _loadTasks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.taskCreatedSuccess),
          backgroundColor: Colors.green,
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
      // Wide screens create from the shell's top bar instead.
      floatingActionButton: AppShell.isDesktop(context)
          ? null
          : FloatingActionButton(
              heroTag: 'tasks-add-button',
              onPressed: _openCreateTask,
              backgroundColor: Colors.green.shade400,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: _withTaskPanel(Column(
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
      )),
    );
  }

  Widget _withTaskPanel(Widget content) {
    final taskId = _selectedTaskId;
    return DetailPanelLayout(
      content: content,
      panel: taskId == null || !AppShell.isDesktop(context)
          ? null
          : DetailSidePanel(
              itemKey: taskId,
              onClose: _closeTaskPanel,
              child: TaskDetailScreen(taskId: taskId),
            ),
    );
  }

  Widget _buildDraggableTaskList() {
    final filteredTasks =
        _tasks.where((task) => task['status'] == _selectedStatus).toList();

    if (filteredTasks.isEmpty) {
      final l10n = AppLocalizations.of(context);
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
              l10n.taskNoTasksFound,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedStatus == 'todo'
                  ? l10n.taskEmptyTodo
                  : _selectedStatus == 'in_progress'
                      ? l10n.taskEmptyInProgress
                      : l10n.taskEmptyCompleted,
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

    return LayoutBuilder(builder: (context, outer) {
      // The table needs room for its columns; narrower lists (e.g. beside the
      // side panel on a small window) keep the cards.
      final dense = AppShell.isDesktop(context) &&
          outer.maxWidth >= _TaskTable.minListWidth;
      final list = LayoutBuilder(
        builder: (context, constraints) {
          // Drag feedback matches the list it was lifted from.
          final feedbackWidth = dense
              ? constraints.maxWidth
              : MediaQuery.of(context).size.width - 32;
          return ReorderableListView.builder(
            itemCount: filteredTasks.length,
            onReorderItem: (oldIndex, newIndex) {
              // Just for visual reordering, no status change
              setState(() {
                final item = filteredTasks.removeAt(oldIndex);
                filteredTasks.insert(newIndex, item);
                // The list is rebuilt from _tasks, so keep the new order there.
                _tasks = [
                  ..._tasks.where((task) => task['status'] != _selectedStatus),
                  ...filteredTasks,
                ];
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
                    width: feedbackWidth,
                    child: _TaskCard(
                      task: task,
                      isAdmin: _isAdmin,
                      dense: dense,
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
                    dense: dense,
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
                  dense: dense,
                  selected: dense && task['id'] == _selectedTaskId,
                  onStatusChange: _updateTaskStatus,
                  onApprovalChange: _updateTaskApproval,
                  onTap: () => _openTask(task),
                ),
              );
            },
          );
        },
      );

      if (!dense) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: list,
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _TaskTable(child: list),
      );
    });
  }

  /// Phones open the task as a page; wide screens show it in the side panel.
  Future<void> _openTask(Map<String, dynamic> task) async {
    if (AppShell.isDesktop(context)) {
      setState(() => _selectedTaskId = task['id'] as String?);
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(taskId: task['id']),
      ),
    );

    if (result == true) {
      _loadTasks();
    }
  }

  void _closeTaskPanel() {
    setState(() => _selectedTaskId = null);
    // The panel may have changed or deleted the task.
    _loadTasks();
  }

  Widget _buildStatusChangeHint() {
    final l10n = AppLocalizations.of(context);
    final nextStatus = _selectedStatus == 'todo'
        ? l10n.taskStatusInProgress
        : _selectedStatus == 'in_progress'
            ? l10n.taskStatusCompleted
            : l10n.taskStatusTodo;

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
        l10n.taskViewStatusTasks(nextStatus),
        style: const TextStyle(color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildStatusTabs() {
    final l10n = AppLocalizations.of(context);
    final statusOptions = [
      {'id': 'todo', 'label': l10n.taskStatusTodo, 'color': Colors.blue},
      {
        'id': 'in_progress',
        'label': l10n.taskStatusInProgress,
        'color': Colors.orange
      },
      {
        'id': 'completed',
        'label': l10n.taskStatusCompleted,
        'color': Colors.green
      },
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
                        ? color.withValues(alpha: 0.2)
                        : candidateData.isNotEmpty
                            ? color.withValues(alpha: 0.1)
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
              onAcceptWithDetails: (details) {
                final task = details.data;
                final newStatus = status['id'] as String;
                if (task['status'] != newStatus) {
                  _updateTaskStatus(task['id'], newStatus);
                }
              },
              onWillAcceptWithDetails: (details) => true,
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
    final l10n = AppLocalizations.of(context);
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
                label: l10n.taskStatusTodo,
                value: todoTasks,
                total: totalTasks > 0 ? totalTasks : 1,
                color: Colors.blue.shade400,
              ),
              _buildProgressStat(
                label: l10n.taskStatusInProgress,
                value: inProgressTasks,
                total: totalTasks > 0 ? totalTasks : 1,
                color: Colors.orange.shade400,
              ),
              _buildProgressStat(
                label: l10n.taskStatusCompleted,
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

  /// One-line table row for wide screens, with the same data and actions.
  final bool dense;

  /// Highlights the row whose task is open in the side panel.
  final bool selected;

  const _TaskCard({
    required this.task,
    required this.isAdmin,
    required this.onStatusChange,
    required this.onApprovalChange,
    required this.onTap,
    this.dense = false,
    this.selected = false,
  });

  bool get _canDelete =>
      task['created_by'] == SupabaseService().client.auth.currentUser?.id ||
      isAdmin;

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(l10n.taskDeleteTitle,
            style: Theme.of(context).textTheme.titleLarge),
        content: Text(
          l10n.taskDeleteConfirmMessage,
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.taskDelete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final result = await SupabaseService().deleteTask(task['id']);
        if (result['success'] == true) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.taskDeletedSuccess),
                backgroundColor: Colors.green,
              ),
            );
            // Refresh the task list
            TaskScreen.refreshTasks();
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['error'] ?? l10n.taskDeleteFailed),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.taskErrorGeneric(e.toString())),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final String title = task['title'] ?? l10n.taskUntitled;
    final String description = task['description'] ?? l10n.taskNoDescription;
    final String status = task['status'] ?? 'todo';
    final String approvalStatus = task['approval_status'] ?? 'pending';

    // Get names from the team members cache
    final supabaseService = SupabaseService();
    String creatorName;
    if (task['created_by'] != null) {
      if (supabaseService.isCurrentUser(task['created_by'])) {
        creatorName = l10n.taskYou;
      } else {
        creatorName = supabaseService.getUserNameById(task['created_by']);
      }
    } else {
      creatorName = l10n.taskUnknown;
    }

    String assigneeName;
    if (task['assigned_to'] != null) {
      if (supabaseService.isCurrentUser(task['assigned_to'])) {
        assigneeName = l10n.taskYou;
      } else {
        assigneeName = supabaseService.getUserNameById(task['assigned_to']);
      }
    } else {
      assigneeName = l10n.taskUnassigned;
    }

    // Format due date if available
    String dueDate = l10n.taskNoDueDate;
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

    if (dense) {
      return _buildRow(
        context,
        title: title,
        description: description,
        status: status,
        statusColor: statusColor,
        approvalStatus: approvalStatus,
        approvalColor: approvalColor,
        creatorName: creatorName,
        assigneeName: assigneeName,
        dueDate: dueDate,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:
                  Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
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
                color: statusColor.withValues(alpha: 0.1),
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
                            ? l10n.taskStatusTodo
                            : status == 'in_progress'
                                ? l10n.taskStatusInProgress
                                : l10n.taskStatusCompleted,
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
                              tooltip: l10n.taskApprove,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () =>
                                  onApprovalChange(task['id'], 'rejected'),
                              icon: Icon(Icons.cancel,
                                  color: Colors.red.shade400, size: 20),
                              tooltip: l10n.taskReject,
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
                              onPressed: () => _confirmDelete(context),
                              icon: Icon(Icons.delete_outline,
                                  color: Colors.red.shade400, size: 20),
                              tooltip: l10n.taskDelete,
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
                          color: approvalColor.withValues(alpha: 0.1),
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
                            l10n.taskCreatedBy(creatorName),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (task['assigned_to'] != null)
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
                              l10n.taskAssignedTo(assigneeName),
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
                    l10n.taskDragToChangeStatus,
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

  /// Wide-screen table row: same fields and actions as the card, one line.
  Widget _buildRow(
    BuildContext context, {
    required String title,
    required String description,
    required String status,
    required Color statusColor,
    required String approvalStatus,
    required Color approvalColor,
    required String creatorName,
    required String assigneeName,
    required String dueDate,
  }) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusLabel = status == 'todo'
        ? l10n.taskStatusTodo
        : status == 'in_progress'
            ? l10n.taskStatusInProgress
            : l10n.taskStatusCompleted;

    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.08)
          : colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.fromLTRB(12, 10, _TaskTable.trailingGap, 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Tooltip(
                message: l10n.taskDragToChangeStatus,
                child: Icon(
                  Icons.drag_indicator,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: statusLabel,
                child: Icon(
                  status == 'todo'
                      ? Icons.assignment_outlined
                      : status == 'in_progress'
                          ? Icons.pending_actions_outlined
                          : Icons.task_alt_outlined,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: _TaskTable.titleFlex,
                child: Tooltip(
                  message: description,
                  waitDuration: const Duration(milliseconds: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: _TaskTable.approvalWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: approvalColor.withValues(alpha: 0.1),
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
                ),
              ),
              Expanded(
                flex: _TaskTable.personFlex,
                child: _PersonCell(
                  name: creatorName,
                  color: Colors.blue.shade700,
                ),
              ),
              Expanded(
                flex: _TaskTable.personFlex,
                child: task['assigned_to'] == null
                    ? Text(
                        assigneeName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    : _PersonCell(
                        name: assigneeName,
                        color: Colors.purple.shade700,
                      ),
              ),
              SizedBox(
                width: _TaskTable.dueWidth,
                child: Text(
                  dueDate,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(
                width: _TaskTable.actionsWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isAdmin && approvalStatus == 'pending') ...[
                      IconButton(
                        onPressed: () =>
                            onApprovalChange(task['id'], 'approved'),
                        icon: Icon(Icons.check_circle,
                            color: Colors.green.shade400, size: 20),
                        tooltip: l10n.taskApprove,
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        onPressed: () =>
                            onApprovalChange(task['id'], 'rejected'),
                        icon: Icon(Icons.cancel,
                            color: Colors.red.shade400, size: 20),
                        tooltip: l10n.taskReject,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                    if (_canDelete)
                      IconButton(
                        onPressed: () => _confirmDelete(context),
                        icon: Icon(Icons.delete_outline,
                            color: Colors.red.shade400, size: 20),
                        tooltip: l10n.taskDelete,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar initial and name, as in the card's "Created by" / "Assigned to".
class _PersonCell extends StatelessWidget {
  final String name;
  final Color color;

  const _PersonCell({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: color,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Frame and column headings for the wide-screen task rows.
class _TaskTable extends StatelessWidget {
  static const titleFlex = 5;
  static const personFlex = 2;
  static const approvalWidth = 110.0;
  static const dueWidth = 100.0;
  static const actionsWidth = 128.0;

  /// Narrower lists fall back to cards.
  static const minListWidth = 880.0;

  /// Room for the reorder handle the list adds at the end of each row on
  /// desktop platforms.
  static const trailingGap = 40.0;

  final Widget child;

  const _TaskTable({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final headingStyle = theme.textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            color: colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.fromLTRB(12, 12, trailingGap, 12),
            child: Row(
              children: [
                // Drag handle (18) + gap (8) + status icon (20) + gap (12).
                const SizedBox(width: 58),
                Expanded(
                  flex: titleFlex,
                  child: Text(l10n.taskTableTask, style: headingStyle),
                ),
                SizedBox(
                  width: approvalWidth,
                  child: Text(l10n.taskTableApproval, style: headingStyle),
                ),
                Expanded(
                  flex: personFlex,
                  child: Text(l10n.taskTableCreatedBy, style: headingStyle),
                ),
                Expanded(
                  flex: personFlex,
                  child: Text(l10n.taskTableAssignedTo, style: headingStyle),
                ),
                SizedBox(
                  width: dueWidth,
                  child: Text(l10n.taskTableDueDate, style: headingStyle),
                ),
                const SizedBox(width: actionsWidth),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
