import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/navigation_service.dart';
import '../../widgets/custom_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_screen.dart';

class TeamSelectionDialog extends StatefulWidget {
  final String userEmail;
  final String? googleRefreshToken;

  const TeamSelectionDialog({
    super.key,
    required this.userEmail,
    this.googleRefreshToken,
  });

  @override
  State<TeamSelectionDialog> createState() => _TeamSelectionDialogState();
}

class _TeamSelectionDialogState extends State<TeamSelectionDialog> {
  final _supabaseService = SupabaseService();
  final _teamCodeController = TextEditingController();
  final _teamNameController = TextEditingController();
  final _userNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isJoiningTeam = true; // true = join, false = create

  @override
  void dispose() {
    _teamCodeController.dispose();
    _teamNameController.dispose();
    _userNameController.dispose();
    super.dispose();
  }

  Future<void> _handleJoinTeam() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);

    setState(() => _isLoading = true);

    try {
      final result = await _supabaseService.joinTeamWithGoogle(
        email: widget.userEmail,
        teamCode: SupabaseService.normalizeTeamCode(_teamCodeController.text),
        fullName: _userNameController.text.trim(),
        googleRefreshToken: widget.googleRefreshToken,
      );

      if (mounted) {
        if (result['success']) {
          Navigator.of(context).pop();
          NavigationService().navigateToReplacement(const HomeScreen());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? l10n.authFailedToJoinTeam),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.authErrorWithDetails(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleCreateTeam() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);

    setState(() => _isLoading = true);

    try {
      final result = await _supabaseService.createTeamWithGoogle(
        email: widget.userEmail,
        teamName: _teamNameController.text.trim(),
        adminName: _userNameController.text.trim(),
        googleRefreshToken: widget.googleRefreshToken,
      );

      if (mounted) {
        if (result['success']) {
          // Show team ID dialog
          _showTeamIdDialog(result['teamId']);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? l10n.authFailedToCreateTeam),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.authErrorWithDetails(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showTeamIdDialog(String teamId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            l10n.authTeamCreatedTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.authYourTeamIdIs,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  teamId,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.authShareTeamId,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                NavigationService().navigateToReplacement(const HomeScreen());
              },
              child: Text(
                l10n.authContinue,
                style: TextStyle(color: Colors.green.shade400),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.authCompleteSetup,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.authChooseHowToProceed,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              // Toggle between Join and Create
              Row(
                children: [
                  Expanded(
                    child: _OptionCard(
                      title: l10n.authJoinTeam,
                      icon: Icons.group_add,
                      isSelected: _isJoiningTeam,
                      onTap: () => setState(() => _isJoiningTeam = true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _OptionCard(
                      title: l10n.authCreateTeam,
                      icon: Icons.add_business,
                      isSelected: !_isJoiningTeam,
                      onTap: () => setState(() => _isJoiningTeam = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _userNameController,
                      label: l10n.authYourNameLabel,
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.authEnterName;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_isJoiningTeam)
                      CustomTextField(
                        controller: _teamCodeController,
                        label: l10n.authTeamCodeLabel,
                        icon: Icons.qr_code,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.authEnterTeamCode;
                          }
                          return null;
                        },
                      )
                    else
                      CustomTextField(
                        controller: _teamNameController,
                        label: l10n.authTeamNameLabel,
                        icon: Icons.business,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.authEnterTeamName;
                          }
                          return null;
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading
                ? null
                : (_isJoiningTeam ? _handleJoinTeam : _handleCreateTeam),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isJoiningTeam ? l10n.authJoinTeam : l10n.authCreateTeam,
                    style: TextStyle(color: Colors.green.shade400),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.green.withValues(alpha: 0.2)
              : Theme.of(context).colorScheme.surfaceContainerLow,
          border: Border.all(
            color: isSelected
                ? Colors.green
                : Theme.of(context).colorScheme.outline,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.green
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
