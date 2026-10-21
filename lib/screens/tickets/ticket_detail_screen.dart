import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../services/supabase_service.dart';
import '../../utils/github_sync_ui.dart';
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
  bool _isGithubSyncing = false;
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
          SnackBar(
            content: Text(AppLocalizations.of(context).ticketLoadDetailsFailed),
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
            content: Text(
                AppLocalizations.of(context).ticketErrorLoadingDetails('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteTicket() async {
    final l10n = AppLocalizations.of(context);
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            l10n.ticketDeleteTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Text(
            l10n.ticketDeleteConfirm,
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
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: Text(l10n.ticketDelete),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.ticketDeletedSuccess),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // Return true to trigger refresh
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.ticketErrorDeleting('${result['error']}')),
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
            content: Text(l10n.ticketErrorDeleting('$e')),
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
              content: Text(l10n.ticketAddCommentFailed('${result['error']}')),
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
            content: Text(l10n.ticketErrorAddingComment('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateTicketStatus(String status) async {
    final l10n = AppLocalizations.of(context);
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
              content: Text(l10n.ticketStatusUpdated),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(l10n.ticketUpdateStatusFailed('${result['error']}')),
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
            content: Text(l10n.ticketErrorUpdatingStatus('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateTicketPriority(String priority) async {
    final l10n = AppLocalizations.of(context);
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
              content: Text(l10n.ticketPriorityUpdated),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(l10n.ticketUpdatePriorityFailed('${result['error']}')),
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
            content: Text(l10n.ticketErrorUpdatingPriority('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openGithubIssue(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final l10n = AppLocalizations.of(context);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error opening GitHub issue: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.ticketCouldNotOpenGithubIssue),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _retryGithubSync() async {
    if (_isGithubSyncing) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isGithubSyncing = true;
    });

    try {
      final result = await _supabaseService.syncTicketToGithub(widget.ticketId);
      if (result['ticket'] is Map) {
        setState(() {
          _ticket = Map<String, dynamic>.from(result['ticket'] as Map);
        });
      } else {
        await _loadTicketDetails();
      }

      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.ticketGithubSyncUpdated),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['error']?.toString() ?? l10n.ticketGithubSyncFailed,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error retrying GitHub sync: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.ticketErrorSyncingGithub('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGithubSyncing = false;
        });
      }
    }
  }

  Widget _buildGithubSyncSection() {
    final l10n = AppLocalizations.of(context);
    final syncToGithub = _ticket!['sync_to_github'] == true;
    final status = _ticket!['github_sync_status'] as String?;
    final issueUrl = _ticket!['gh_issue_url'] as String?;
    final issueId = _ticket!['gh_issue_id'];
    final errorText =
        GithubSyncUi.userErrorMessage(_ticket!['github_sync_error'] as String?);
    final rawError = _ticket!['github_sync_error'] as String?;
    final ambiguous = rawError != null &&
        rawError.contains('[ambiguous_create]');

    if (!GithubSyncUi.shouldShowSection(
      syncToGithub: syncToGithub,
      status: status,
      issueUrl: issueUrl,
    )) {
      return const SizedBox.shrink();
    }

    Color chipColor;
    switch (status) {
      case 'synced':
        chipColor = Colors.green.shade400;
        break;
      case 'pending':
        chipColor = Colors.orange.shade400;
        break;
      case 'failed':
        chipColor = Colors.red.shade400;
        break;
      default:
        chipColor = Colors.grey.shade400;
    }

    final canRetry = syncToGithub &&
        issueId == null &&
        status == 'failed' &&
        !ambiguous;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Divider(color: Theme.of(context).dividerColor),
        const SizedBox(height: 12),
        Text(
          'GitHub',
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: chipColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            GithubSyncUi.statusLabel(status),
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (status == 'synced' &&
            issueUrl != null &&
            issueUrl.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _openGithubIssue(issueUrl),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(
              issueId != null
                  ? l10n.ticketViewOnGithubWithId('$issueId')
                  : l10n.ticketViewOnGithub,
            ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.green.shade300,
            ),
          ),
        ],
        if (status == 'failed' && errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText,
            style: TextStyle(
              color: Colors.red.shade200,
              fontSize: 13,
            ),
          ),
        ],
        if (canRetry) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isGithubSyncing ? null : _retryGithubSync,
            child: _isGithubSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.ticketRetryGithubSync),
          ),
        ],
      ],
    );
  }

  Future<void> _assignTicket(String userId) async {
    final l10n = AppLocalizations.of(context);
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
              content: Text(l10n.ticketAssignedSuccess),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.ticketAssignFailed('${result['error']}')),
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
            content: Text(l10n.ticketErrorAssigning('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show team members dialog for assignment
  void _showAssignDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            l10n.ticketAssignTitle,
            style: Theme.of(context).textTheme.titleLarge,
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
                    l10n.ticketErrorLoadingTeamMembers,
                    style: TextStyle(color: Colors.red.shade400),
                  );
                }

                final teamMembers = snapshot.data ?? [];
                if (teamMembers.isEmpty) {
                  return Text(
                    l10n.ticketNoTeamMembers,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: teamMembers.length,
                  itemBuilder: (context, index) {
                    final member = teamMembers[index];
                    final fullName = member['full_name'] ?? l10n.ticketUnknown;
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
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                      subtitle: Text(
                        isAdmin ? l10n.ticketRoleAdmin : l10n.ticketRoleTeamMember,
                        style: TextStyle(
                          color: isAdmin
                              ? Colors.orange.shade400
                              : Theme.of(context).colorScheme.onSurfaceVariant,
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
                l10n.cancel,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
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
    final l10n = AppLocalizations.of(context);
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(l10n.ticketDetailsTitle),
        ),
        body: const Center(child: CustomLoading()),
      );
    }

    if (_ticket == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(l10n.ticketDetailsTitle),
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
                l10n.ticketNotFound,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.ticketNotFoundMessage,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(_ticket!['ticket_number'] ?? l10n.ticketDetailsTitle),
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
                  PopupMenuItem(
                    value: 'header_status',
                    enabled: false,
                    child: Text(
                      l10n.ticketChangeStatus,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'status:open',
                    child: Text(l10n.ticketStatusOpen),
                  ),
                  PopupMenuItem(
                    value: 'status:in_progress',
                    child: Text(l10n.ticketStatusInProgress),
                  ),
                  PopupMenuItem(
                    value: 'status:resolved',
                    child: Text(l10n.ticketStatusResolved),
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
                      l10n.ticketChangePriority,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'priority:high',
                    child: Text(l10n.ticketPriorityHigh),
                  ),
                  PopupMenuItem(
                    value: 'priority:medium',
                    child: Text(l10n.ticketPriorityMedium),
                  ),
                  PopupMenuItem(
                    value: 'priority:low',
                    child: Text(l10n.ticketPriorityLow),
                  ),
                  const PopupMenuItem(
                    value: 'divider2',
                    enabled: false,
                    child: Divider(),
                  ),
                ],
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.ticketDeleteTitle,
                          style: const TextStyle(color: Colors.red)),
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
                  color: Theme.of(context).colorScheme.surface,
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
                                _ticket!['category'] ?? l10n.ticketCategoryOther,
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
                          _ticket!['title'] ?? l10n.ticketUntitled,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _ticket!['description'] ?? l10n.ticketNoDescriptionProvided,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),
                        _buildGithubSyncSection(),
                        const SizedBox(height: 16),
                        Divider(color: Theme.of(context).dividerColor),
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
                                    l10n.ticketCreatedByLabel,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _ticket!['creator']['full_name'] ??
                                        l10n.ticketUnknown,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
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
                                    l10n.ticketAssignedTo,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _ticket!['assignee']['full_name'] ??
                                        l10n.ticketUnknown,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
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
                                label: Text(l10n.ticketAssign),
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
                  l10n.ticketCommentsCount(_comments.length),
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
                            l10n.ticketNoComments,
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.ticketBeFirstComment,
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
                    color: Theme.of(context).colorScheme.surface,
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
                                  comment['user']['full_name'] ?? l10n.ticketUnknown,
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
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
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
                      hintText: l10n.ticketAddCommentHint,
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
                IconButton(
                  onPressed: _addComment,
                  tooltip: l10n.ticketSendComment,
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
