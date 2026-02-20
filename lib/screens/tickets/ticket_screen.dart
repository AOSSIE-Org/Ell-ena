import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_widgets.dart';
import 'ticket_detail_screen.dart';
import 'create_ticket_screen.dart';

class TicketScreen extends StatefulWidget {
  static final GlobalKey<_TicketScreenState> globalKey =
      GlobalKey<_TicketScreenState>();

  const TicketScreen({super.key});

  // Static method to refresh tickets from anywhere
  static void refreshTickets() {
    final state = globalKey.currentState;
    if (state != null) {
      state.refreshTickets();
    }
  }

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  String _selectedStatus = 'open';
  bool _isAdmin = false;
  List<Map<String, dynamic>> _tickets = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // Method to refresh tickets
  void refreshTickets() {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
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

      // Initial load of tickets with filtering
      final tickets =
          await _supabaseService.getTickets(filterByAssignment: true);

      if (mounted) {
        setState(() {
          _tickets = tickets;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateTicketStatus(String ticketId, String status) async {
    try {
      await _supabaseService.updateTicketStatus(
        ticketId: ticketId,
        status: status,
      );

      // Reload tickets after update
      _loadInitialData();
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

  Future<void> _updateTicketApproval(
      String ticketId, String approvalStatus) async {
    try {
      await _supabaseService.updateTicketApproval(
        ticketId: ticketId,
        approvalStatus: approvalStatus,
      );

      // Reload tickets after update
      _loadInitialData();
    } catch (e) {
      debugPrint('Error updating ticket approval: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating ticket approval: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    if (TicketScreen.globalKey.currentState != this) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        TicketScreen.refreshTickets();
      });
    }

    final openTickets =
        _tickets.where((ticket) => ticket['status'] == 'open').toList();
    final inProgressTickets =
        _tickets.where((ticket) => ticket['status'] == 'in_progress').toList();
    final resolvedTickets =
        _tickets.where((ticket) => ticket['status'] == 'resolved').toList();
    final totalTickets = _tickets.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateTicketScreen(),
              fullscreenDialog: true,
            ),
          );

          if (result == true) {
            refreshTickets();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ticket created successfully'),
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
            openTickets: openTickets.length,
            inProgressTickets: inProgressTickets.length,
            resolvedTickets: resolvedTickets.length,
            totalTickets: totalTickets,
          ),
          const SizedBox(height: 16),
          _buildStatusTabs(),
          Expanded(
            child: _buildTicketList(_tickets
                .where((ticket) => ticket['status'] == _selectedStatus)
                .toList()),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressHeader({
    required int openTickets,
    required int inProgressTickets,
    required int resolvedTickets,
    required int totalTickets,
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
                label: 'Open',
                value: openTickets,
                total: totalTickets > 0 ? totalTickets : 1,
                color: Colors.blue.shade400,
              ),
              _buildProgressStat(
                label: 'In Progress',
                value: inProgressTickets,
                total: totalTickets > 0 ? totalTickets : 1,
                color: Colors.orange.shade400,
              ),
              _buildProgressStat(
                label: 'Resolved',
                value: resolvedTickets,
                total: totalTickets > 0 ? totalTickets : 1,
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
                      width: totalTickets > 0 ? openTickets / totalTickets : 0,
                      color: Colors.blue.shade400,
                    ),
                    _buildProgressBar(
                      width: totalTickets > 0
                          ? inProgressTickets / totalTickets
                          : 0,
                      color: Colors.orange.shade400,
                    ),
                    _buildProgressBar(
                      width:
                          totalTickets > 0 ? resolvedTickets / totalTickets : 0,
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
    final screenWidth =
        MediaQuery.of(context).size.width - 32; // Total available width
    return Container(
      height: 8,
      width: screenWidth * width,
      color: color,
    );
  }

  Widget _buildStatusTabs() {
    final statusOptions = [
      {'id': 'open', 'label': 'Open', 'color': Colors.blue},
      {'id': 'in_progress', 'label': 'In Progress', 'color': Colors.orange},
      {'id': 'resolved', 'label': 'Resolved', 'color': Colors.green},
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
              onAccept: (ticket) {
                final newStatus = status['id'] as String;
                if (ticket['status'] != newStatus) {
                  _updateTicketStatus(ticket['id'], newStatus);
                }
              },
              onWillAccept: (data) => data != null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTicketList(List<Map<String, dynamic>> filteredTickets) {
    if (filteredTickets.isEmpty) {
      final colorScheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedStatus == 'open'
                  ? Icons.report_problem_outlined
                  : _selectedStatus == 'in_progress'
                      ? Icons.pending_actions_outlined
                      : Icons.task_alt_outlined,
              size: 80,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No tickets found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedStatus == 'open'
                  ? 'Create new tickets to get started'
                  : _selectedStatus == 'in_progress'
                      ? 'Move tickets here when you start working on them'
                      : 'Resolved tickets will appear here',
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
        itemCount: filteredTickets.length,
        onReorder: (oldIndex, newIndex) {
          // Just for visual reordering, no status change
          setState(() {
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }
            final item = filteredTickets.removeAt(oldIndex);
            filteredTickets.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) {
          final ticket = filteredTickets[index];
          return Draggable<Map<String, dynamic>>(
            key: ValueKey(ticket['id']),
            data: ticket,
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 32,
                child: _TicketCard(
                  ticket: ticket,
                  isAdmin: _isAdmin,
                  onStatusChange: _updateTicketStatus,
                  onApprovalChange: _updateTicketApproval,
                  onTap: () {},
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.5,
              child: _TicketCard(
                ticket: ticket,
                isAdmin: _isAdmin,
                onStatusChange: _updateTicketStatus,
                onApprovalChange: _updateTicketApproval,
                onTap: () {},
              ),
            ),
            child: _TicketCard(
              ticket: ticket,
              isAdmin: _isAdmin,
              onStatusChange: _updateTicketStatus,
              onApprovalChange: _updateTicketApproval,
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TicketDetailScreen(ticketId: ticket['id']),
                  ),
                );

                if (result == true) {
                  // Ticket was updated in detail screen, refresh tickets
                  _loadInitialData();
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChangeHint() {
    final nextStatus = _selectedStatus == 'open'
        ? 'In Progress'
        : _selectedStatus == 'in_progress'
            ? 'Resolved'
            : 'Open';

    final nextStatusId = _selectedStatus == 'open'
        ? 'in_progress'
        : _selectedStatus == 'in_progress'
            ? 'resolved'
            : 'open';

    final color = _selectedStatus == 'open'
        ? Colors.orange
        : _selectedStatus == 'in_progress'
            ? Colors.green
            : Colors.blue;

    return ElevatedButton.icon(
      onPressed: () => setState(() => _selectedStatus = nextStatusId),
      icon: Icon(
        _selectedStatus == 'open'
            ? Icons.arrow_forward
            : _selectedStatus == 'in_progress'
                ? Icons.check
                : Icons.refresh,
        color: Colors.white,
        size: 16,
      ),
      label: Text(
        'View $nextStatus Tickets',
        style: const TextStyle(color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final bool isAdmin;
  final Function(String, String) onStatusChange;
  final Function(String, String) onApprovalChange;
  final VoidCallback onTap;

  const _TicketCard({
    required this.ticket,
    required this.isAdmin,
    required this.onStatusChange,
    required this.onApprovalChange,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String title = ticket['title'] ?? 'Untitled Ticket';
    final String description = ticket['description'] ?? 'No description';
    // Limit description to 75 words
    final String limitedDescription = _limitWords(description, 75);
    final String status = ticket['status'] ?? 'open';
    final String priority = ticket['priority'] ?? 'medium';
    final String category = ticket['category'] ?? 'Bug';
    final String approvalStatus = ticket['approval_status'] ?? 'pending';
    final String ticketNumber = ticket['ticket_number'] ?? 'TKT-???';
    final String createdAt = _formatDate(ticket['created_at']);

    // Get names from the team members cache
    final supabaseService = SupabaseService();
    String creatorName;
    if (ticket['created_by'] != null) {
      if (supabaseService.isCurrentUser(ticket['created_by'])) {
        creatorName = 'You';
      } else if (ticket['creator'] != null &&
          ticket['creator']['full_name'] != null) {
        creatorName = ticket['creator']['full_name'];
      } else {
        creatorName = supabaseService.getUserNameById(ticket['created_by']);
      }
    } else {
      creatorName = 'Unknown';
    }

    // Determine colors and icons based on priority
    Color priorityColor;
    IconData priorityIcon;
    switch (priority.toLowerCase()) {
      case 'high':
        priorityColor = Colors.red.shade400;
        priorityIcon = Icons.priority_high;
        break;
      case 'medium':
        priorityColor = Colors.orange.shade400;
        priorityIcon = Icons.remove_circle_outline;
        break;
      case 'low':
        priorityColor = Colors.green.shade400;
        priorityIcon = Icons.arrow_downward;
        break;
      default:
        priorityColor = Colors.grey;
        priorityIcon = Icons.help_outline;
    }

    // Determine category icon
    IconData categoryIcon;
    switch (category.toLowerCase()) {
      case 'bug':
        categoryIcon = Icons.bug_report;
        break;
      case 'feature request':
        categoryIcon = Icons.lightbulb_outline;
        break;
      case 'ui/ux':
        categoryIcon = Icons.design_services;
        break;
      case 'performance':
        categoryIcon = Icons.speed;
        break;
      case 'documentation':
        categoryIcon = Icons.description;
        break;
      case 'security':
        categoryIcon = Icons.security;
        break;
      default:
        categoryIcon = Icons.category;
    }

    // Determine colors based on approval status
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
                color: priorityColor.withOpacity(0.1),
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
                        priorityIcon,
                        color: priorityColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        priority.toUpperCase(),
                        style: TextStyle(
                          color: priorityColor,
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
                                  onApprovalChange(ticket['id'], 'approved'),
                              icon: Icon(Icons.check_circle,
                                  color: Colors.green.shade400, size: 20),
                              tooltip: 'Approve',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () =>
                                  onApprovalChange(ticket['id'], 'rejected'),
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
                          if (ticket['created_by'] ==
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
                                    title: Text('Delete Ticket',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    content: Text(
                                      'Are you sure you want to delete this ticket? This action cannot be undone.',
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
                                        .deleteTicket(ticket['id']);
                                    if (result['success'] == true) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Ticket deleted successfully'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        // Refresh the ticket list
                                        TicketScreen.refreshTickets();
                                      }
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(result['error'] ??
                                                'Failed to delete ticket'),
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
                          if (ticket['created_by'] ==
                                  SupabaseService()
                                      .client
                                      .auth
                                      .currentUser
                                      ?.id ||
                              isAdmin)
                            const SizedBox(width: 8),
                          Text(
                            createdAt,
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
                  Text(
                    ticketNumber,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
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
                    limitedDescription,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              categoryIcon,
                              color: Colors.purple.shade300,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              category,
                              style: TextStyle(
                                color: Colors.purple.shade300,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  String _formatDate(String? dateString) {
    if (dateString == null) return '';

    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }

  String _limitWords(String text, int wordLimit) {
    if (text.isEmpty) return text;

    final words = text.split(' ');
    if (words.length <= wordLimit) return text;

    return '${words.take(wordLimit).join(' ')}...';
  }
}
