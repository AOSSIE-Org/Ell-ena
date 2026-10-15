import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/supabase_service.dart';
import '../../widgets/account_actions.dart';
import '../shell_destination.dart';

/// Main action of a page, shown as a button in the top bar.
class ShellPageAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const ShellPageAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}

/// Wide-screen page header: title, page action, refresh, team switcher and
/// account menu.
class ShellTopBar extends StatefulWidget {
  static const double height = 64;

  final ShellDestination destination;

  /// Replaces the phone's floating add button on wide screens.
  final ShellPageAction? pageAction;

  /// Reloads the open page; null hides the refresh button.
  final Future<void> Function()? onRefresh;

  /// Called after the user switches to another team.
  final VoidCallback? onTeamChanged;
  final VoidCallback? onOpenProfile;

  const ShellTopBar({
    super.key,
    required this.destination,
    this.pageAction,
    this.onRefresh,
    this.onTeamChanged,
    this.onOpenProfile,
  });

  @override
  State<ShellTopBar> createState() => ShellTopBarState();
}

class ShellTopBarState extends State<ShellTopBar> {
  final _supabaseService = SupabaseService();
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _teams = [];
  bool _isRefreshing = false;
  bool _isSwitchingTeam = false;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount({bool forceRefresh = false}) async {
    try {
      final profile = await _supabaseService.getCurrentUserProfile(
        forceRefresh: forceRefresh,
      );
      var teams = <Map<String, dynamic>>[];
      final email = profile?['email'] as String?;
      if (email != null) {
        final response = await _supabaseService.getUserTeams(email);
        if (response['success'] == true && response['teams'] != null) {
          teams = List<Map<String, dynamic>>.from(response['teams']);
        }
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _teams = teams;
      });
    } catch (e) {
      debugPrint('Error loading account for top bar: $e');
    }
  }

  /// Same as pressing the refresh button; used by the R shortcut.
  Future<void> refresh() => _refresh();

  Future<void> _refresh() async {
    final onRefresh = widget.onRefresh;
    if (onRefresh == null || _isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await Future.wait([onRefresh(), _loadAccount(forceRefresh: true)]);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _switchTeam() async {
    final teamId = await showTeamSwitcherDialog(
      context,
      teams: _teams,
      currentTeamId: _profile?['team_id'] as String?,
    );
    if (teamId == null || !mounted) return;

    setState(() => _isSwitchingTeam = true);
    try {
      final result = await _supabaseService.switchTeam(teamId);
      if (!mounted) return;
      if (result['success'] == true) {
        await _loadAccount(forceRefresh: true);
        widget.onTeamChanged?.call();
      } else {
        _showError(
          AppLocalizations.of(context).errorSwitchingTeam('${result['error']}'),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError(AppLocalizations.of(context).errorSwitchingTeam('$e'));
      }
    } finally {
      if (mounted) setState(() => _isSwitchingTeam = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Material(
      color: colorScheme.surface,
      child: Container(
        height: ShellTopBar.height,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.destination.labelFor(l10n),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.pageAction != null) ...[
              Tooltip(
                message: '${widget.pageAction!.label} (N)',
                child: FilledButton.icon(
                  onPressed: widget.pageAction!.onPressed,
                  icon: Icon(widget.pageAction!.icon),
                  label: Text(widget.pageAction!.label),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (widget.onRefresh != null) ...[
              _RefreshButton(isRefreshing: _isRefreshing, onPressed: _refresh),
              const SizedBox(width: 8),
            ],
            if (_teamName != null) ...[
              _TeamButton(
                teamName: _teamName!,
                canSwitch: _teams.length > 1,
                isSwitching: _isSwitchingTeam,
                onPressed: _switchTeam,
              ),
              const SizedBox(width: 8),
            ],
            _AccountMenu(
              name: _name,
              email: _profile?['email'] as String?,
              onOpenProfile: widget.onOpenProfile,
            ),
          ],
        ),
      ),
    );
  }

  String? get _teamName => _profile?['teams']?['name'] as String?;

  String? get _name {
    final name = (_profile?['full_name'] as String?)?.trim();
    return name == null || name.isEmpty ? null : name;
  }
}

class _RefreshButton extends StatelessWidget {
  final bool isRefreshing;
  final VoidCallback onPressed;

  const _RefreshButton({required this.isRefreshing, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '${AppLocalizations.of(context).refresh} (R)',
      onPressed: isRefreshing ? null : onPressed,
      icon: isRefreshing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
    );
  }
}

class _TeamButton extends StatelessWidget {
  final String teamName;
  final bool canSwitch;
  final bool isSwitching;
  final VoidCallback onPressed;

  const _TeamButton({
    required this.teamName,
    required this.canSwitch,
    required this.isSwitching,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.groups_outlined, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(teamName, overflow: TextOverflow.ellipsis),
        ),
        if (canSwitch) ...[
          const SizedBox(width: 4),
          isSwitching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.unfold_more, size: 18, color: colorScheme.primary),
        ],
      ],
    );

    return Tooltip(
      message: canSwitch ? AppLocalizations.of(context).switchTeam : teamName,
      child: OutlinedButton(
        onPressed: canSwitch && !isSwitching ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          disabledForegroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outlineVariant),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: label,
      ),
    );
  }
}

enum _AccountAction { profile, signOut }

class _AccountMenu extends StatelessWidget {
  final String? name;
  final String? email;
  final VoidCallback? onOpenProfile;

  const _AccountMenu({this.name, this.email, this.onOpenProfile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final initial = (name ?? email ?? '?').substring(0, 1).toUpperCase();

    return PopupMenuButton<_AccountAction>(
      tooltip: name ?? l10n.profile,
      position: PopupMenuPosition.under,
      onSelected: (action) {
        switch (action) {
          case _AccountAction.profile:
            onOpenProfile?.call();
            break;
          case _AccountAction.signOut:
            confirmAndSignOut(context);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_AccountAction>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name ?? l10n.profile,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              if (email != null)
                Text(
                  email!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<_AccountAction>(
          value: _AccountAction.profile,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.profile),
          ),
        ),
        PopupMenuItem<_AccountAction>(
          value: _AccountAction.signOut,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout, color: colorScheme.error),
            title: Text(
              l10n.logout,
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
              child: Text(
                initial,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (name != null) ...[
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  name!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.expand_more, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
