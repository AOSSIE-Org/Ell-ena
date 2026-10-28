import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/adaptive_create_flow.dart';
import '../../shell/app_shell.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/detail_side_panel.dart';
import 'ticket_detail_screen.dart';
import 'create_ticket_screen.dart';

class TicketScreen extends StatefulWidget {
  static final GlobalKey<_TicketScreenState> _globalKey =
      GlobalKey<_TicketScreenState>();
  static GlobalKey<State<TicketScreen>> get globalKey => _globalKey;

  const TicketScreen({super.key});

  // Static method to refresh tickets from anywhere
  /// Opens the create-ticket screen; used by the wide shell's top bar.
  static void openCreateTicket() {
    _globalKey.currentState?._openCreateTicket();
  }

  static void refreshTickets() {
    final state = _globalKey.currentState;
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

  /// Ticket shown in the side panel on wide screens.
  String? _selectedTicketId;
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

  /// [showLoading] false reloads behind the current list instead of
  /// replacing it with a spinner, e.g. when the side panel closes.
  Future<void> _loadInitialData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

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
    final l10n = AppLocalizations.of(context);
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
            content: Text(l10n.ticketErrorUpdatingStatus('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateTicketApproval(
      String ticketId, String approvalStatus) async {
    final l10n = AppLocalizations.of(context);
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
            content: Text(l10n.ticketErrorUpdatingApproval('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openCreateTicket() async {
    final l10n = AppLocalizations.of(context);
    final result = await openCreateFlow(
      context,
      const CreateTicketScreen(),
      fullscreenDialog: true,
    );

    if (result == true) {
      refreshTickets();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.ticketCreatedSuccess),
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
      // Wide screens create from the shell's top bar instead.
      floatingActionButton: AppShell.isDesktop(context)
          ? null
          : FloatingActionButton(
              heroTag: 'tickets-add-button',
              onPressed: _openCreateTicket,
              tooltip: AppLocalizations.of(context).newTicket,
              backgroundColor: Colors.green.shade400,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: _withTicketPanel(Column(
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
      )),
    );
  }

  Widget _withTicketPanel(Widget content) {
    final ticketId = _selectedTicketId;
    return DetailPanelLayout(
      content: content,
      panel: ticketId == null || !AppShell.isDesktop(context)
          ? null
          : DetailSidePanel(
              itemKey: ticketId,
              onClose: _closeTicketPanel,
              child: TicketDetailScreen(ticketId: ticketId),
            ),
    );
  }

  /// Phones open the ticket as a page; wide screens show it in the side panel.
  Future<void> _openTicket(Map<String, dynamic> ticket) async {
    if (AppShell.isDesktop(context)) {
      setState(() => _selectedTicketId = ticket['id'] as String?);
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TicketDetailScreen(ticketId: ticket['id']),
      ),
    );

    if (result == true) {
      // Ticket was updated in detail screen, refresh tickets
      _loadInitialData();
    }
  }

  void _closeTicketPanel() {
    setState(() => _selectedTicketId = null);
    // The panel may have changed or deleted the ticket.
    _loadInitialData(showLoading: false);
  }

  Widget _buildProgressHeader({
    required int openTickets,
    required int inProgressTickets,
    required int resolvedTickets,
    required int totalTickets,
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
                label: l10n.ticketStatusOpen,
                value: openTickets,
                total: totalTickets > 0 ? totalTickets : 1,
                color: Colors.blue.shade400,
              ),
              _buildProgressStat(
                label: l10n.ticketStatusInProgress,
                value: inProgressTickets,
                total: totalTickets > 0 ? totalTickets : 1,
                color: Colors.orange.shade400,
              ),
              _buildProgressStat(
                label: l10n.ticketStatusResolved,
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
    final l10n = AppLocalizations.of(context);
    final statusOptions = [
      {'id': 'open', 'label': l10n.ticketStatusOpen, 'color': Colors.blue},
      {
        'id': 'in_progress',
        'label': l10n.ticketStatusInProgress,
        'color': Colors.orange
      },
      {
        'id': 'resolved',
        'label': l10n.ticketStatusResolved,
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
                final ticket = details.data;
                final newStatus = status['id'] as String;
                if (ticket['status'] != newStatus) {
                  _updateTicketStatus(ticket['id'], newStatus);
                }
              },
              onWillAcceptWithDetails: (details) => true,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTicketList(List<Map<String, dynamic>> filteredTickets) {
    if (filteredTickets.isEmpty) {
      final l10n = AppLocalizations.of(context);
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
              l10n.ticketNoTicketsFound,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedStatus == 'open'
                  ? l10n.ticketEmptyOpen
                  : _selectedStatus == 'in_progress'
                      ? l10n.ticketEmptyInProgress
                      : l10n.ticketEmptyResolved,
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
          outer.maxWidth >= _TicketTable.minListWidth;
      final list = LayoutBuilder(
        builder: (context, constraints) {
          // Drag feedback matches the list it was lifted from.
          final feedbackWidth = dense
              ? constraints.maxWidth
              : MediaQuery.of(context).size.width - 32;
          return ReorderableListView.builder(
            itemCount: filteredTickets.length,
            onReorderItem: (oldIndex, newIndex) {
              // Just for visual reordering, no status change
              setState(() {
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
                    width: feedbackWidth,
                    child: _TicketCard(
                      ticket: ticket,
                      isAdmin: _isAdmin,
                      dense: dense,
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
                    dense: dense,
                    onStatusChange: _updateTicketStatus,
                    onApprovalChange: _updateTicketApproval,
                    onTap: () {},
                  ),
                ),
                child: _TicketCard(
                  ticket: ticket,
                  isAdmin: _isAdmin,
                  dense: dense,
                  selected: dense && ticket['id'] == _selectedTicketId,
                  onStatusChange: _updateTicketStatus,
                  onApprovalChange: _updateTicketApproval,
                  onTap: () => _openTicket(ticket),
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
        child: _TicketTable(child: list),
      );
    });
  }

  Widget _buildStatusChangeHint() {
    final l10n = AppLocalizations.of(context);
    final nextStatus = _selectedStatus == 'open'
        ? l10n.ticketStatusInProgress
        : _selectedStatus == 'in_progress'
            ? l10n.ticketStatusResolved
            : l10n.ticketStatusOpen;

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
        l10n.ticketViewStatusTickets(nextStatus),
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

  /// One-line table row for wide screens, with the same data and actions.
  final bool dense;

  /// Highlights the row whose ticket is open in the side panel.
  final bool selected;

  const _TicketCard({
    required this.ticket,
    required this.isAdmin,
    required this.onStatusChange,
    required this.onApprovalChange,
    required this.onTap,
    this.dense = false,
    this.selected = false,
  });

  bool get _canDelete =>
      ticket['created_by'] == SupabaseService().client.auth.currentUser?.id ||
      isAdmin;

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(l10n.ticketDeleteTitle,
            style: Theme.of(context).textTheme.titleLarge),
        content: Text(
          l10n.ticketDeleteConfirm,
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
            child: Text(l10n.ticketDelete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final result = await SupabaseService().deleteTicket(ticket['id']);
        if (result['success'] == true) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.ticketDeletedSuccess),
                backgroundColor: Colors.green,
              ),
            );
            // Refresh the ticket list
            TicketScreen.refreshTickets();
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['error'] ?? l10n.ticketDeleteFailed),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.ticketErrorGeneric('$e')),
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
    final String title = ticket['title'] ?? l10n.ticketUntitled;
    final String description =
        ticket['description'] ?? l10n.ticketNoDescription;
    // Limit description to 75 words
    final String limitedDescription = _limitWords(description, 75);
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
        creatorName = l10n.ticketYou;
      } else if (ticket['creator'] != null &&
          ticket['creator']['full_name'] != null) {
        creatorName = ticket['creator']['full_name'];
      } else {
        creatorName = supabaseService.getUserNameById(ticket['created_by']);
      }
    } else {
      creatorName = l10n.ticketUnknown;
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

    if (dense) {
      return _buildRow(
        context,
        title: title,
        description: description,
        priority: priority,
        priorityColor: priorityColor,
        priorityIcon: priorityIcon,
        category: category,
        categoryIcon: categoryIcon,
        approvalStatus: approvalStatus,
        approvalColor: approvalColor,
        ticketNumber: ticketNumber,
        createdAt: createdAt,
        creatorName: creatorName,
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
                color: priorityColor.withValues(alpha: 0.1),
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
                              tooltip: l10n.ticketApprove,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () =>
                                  onApprovalChange(ticket['id'], 'rejected'),
                              icon: Icon(Icons.cancel,
                                  color: Colors.red.shade400, size: 20),
                              tooltip: l10n.ticketReject,
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
                              onPressed: () => _confirmDelete(context),
                              icon: Icon(Icons.delete_outline,
                                  color: Colors.red.shade400, size: 20),
                              tooltip: l10n.ticketDelete,
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
                          color: Colors.purple.withValues(alpha: 0.2),
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
                            l10n.ticketCreatedByName(creatorName),
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
                    l10n.ticketDragToChangeStatus,
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

  /// Wide-screen table row: same fields and actions as the card, one line.
  Widget _buildRow(
    BuildContext context, {
    required String title,
    required String description,
    required String priority,
    required Color priorityColor,
    required IconData priorityIcon,
    required String category,
    required IconData categoryIcon,
    required String approvalStatus,
    required Color approvalColor,
    required String ticketNumber,
    required String createdAt,
    required String creatorName,
  }) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedSmall = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.08)
          : colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.fromLTRB(12, 10, _TicketTable.trailingGap, 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Tooltip(
                message: l10n.ticketDragToChangeStatus,
                child: Icon(
                  Icons.drag_indicator,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: _TicketTable.priorityWidth,
                child: Row(
                  children: [
                    Icon(priorityIcon, color: priorityColor, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        priority.toUpperCase(),
                        style: TextStyle(
                          color: priorityColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: _TicketTable.numberWidth,
                child: Text(
                  ticketNumber,
                  style: mutedSmall?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: _TicketTable.titleFlex,
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
                        style: mutedSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: _TicketTable.categoryFlex,
                child: Row(
                  children: [
                    Icon(
                      categoryIcon,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        category,
                        style: mutedSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: _TicketTable.approvalWidth,
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
                flex: _TicketTable.personFlex,
                child: Row(
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
                    Expanded(
                      child: Text(
                        creatorName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: _TicketTable.createdWidth,
                child: Text(createdAt, style: mutedSmall),
              ),
              SizedBox(
                width: _TicketTable.actionsWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isAdmin && approvalStatus == 'pending') ...[
                      IconButton(
                        onPressed: () =>
                            onApprovalChange(ticket['id'], 'approved'),
                        icon: Icon(Icons.check_circle,
                            color: Colors.green.shade400, size: 20),
                        tooltip: l10n.ticketApprove,
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        onPressed: () =>
                            onApprovalChange(ticket['id'], 'rejected'),
                        icon: Icon(Icons.cancel,
                            color: Colors.red.shade400, size: 20),
                        tooltip: l10n.ticketReject,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                    if (_canDelete)
                      IconButton(
                        onPressed: () => _confirmDelete(context),
                        icon: Icon(Icons.delete_outline,
                            color: Colors.red.shade400, size: 20),
                        tooltip: l10n.ticketDelete,
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

/// Frame and column headings for the wide-screen ticket rows.
class _TicketTable extends StatelessWidget {
  static const priorityWidth = 96.0;
  static const numberWidth = 96.0;
  static const titleFlex = 5;
  static const categoryFlex = 2;
  static const approvalWidth = 110.0;
  static const personFlex = 2;
  static const createdWidth = 90.0;
  static const actionsWidth = 128.0;

  /// Narrower lists fall back to cards.
  static const minListWidth = 880.0;

  /// Room for the reorder handle the list adds at the end of each row on
  /// desktop platforms.
  static const trailingGap = 40.0;

  final Widget child;

  const _TicketTable({required this.child});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                // Drag handle (18) + gap (8).
                const SizedBox(width: 26),
                SizedBox(
                  width: priorityWidth,
                  child: Text(l10n.ticketPriority, style: headingStyle),
                ),
                SizedBox(
                  width: numberWidth,
                  child: Text(l10n.ticketTicket, style: headingStyle),
                ),
                Expanded(
                  flex: titleFlex,
                  child: Text(l10n.ticketTitle, style: headingStyle),
                ),
                Expanded(
                  flex: categoryFlex,
                  child: Text(l10n.ticketCategory, style: headingStyle),
                ),
                SizedBox(
                  width: approvalWidth,
                  child: Text(l10n.ticketApproval, style: headingStyle),
                ),
                Expanded(
                  flex: personFlex,
                  child: Text(l10n.ticketCreatedByLabel, style: headingStyle),
                ),
                SizedBox(
                  width: createdWidth,
                  child: Text(l10n.ticketCreated, style: headingStyle),
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
