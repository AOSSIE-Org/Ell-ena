import 'package:flutter/material.dart';
import 'package:ell_ena/core/errors/app_error_handler.dart';
import '../../services/supabase_service.dart';
import '../../services/navigation_service.dart';
import '../../widgets/custom_widgets.dart';
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

    setState(() => _isLoading = true);

    try {
      final result = await _supabaseService.joinTeamWithGoogle(
        email: widget.userEmail,
        teamCode: _teamCodeController.text.trim(),
        fullName: _userNameController.text.trim(),
        googleRefreshToken: widget.googleRefreshToken,
      );

      if (result['success'] == true) {
        if (mounted) {
          Navigator.of(context).pop();
          NavigationService().navigateToReplacement(const HomeScreen());
        }
      } else {
        if (mounted) {
          AppErrorHandler.instance
              .handle(context, result['error'] ?? 'Failed to join team');
        }
      }
    } catch (e) {
      if (mounted) {
        AppErrorHandler.instance.handle(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleCreateTeam() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _supabaseService.createTeamWithGoogle(
        email: widget.userEmail,
        teamName: _teamNameController.text.trim(),
        adminName: _userNameController.text.trim(),
        googleRefreshToken: widget.googleRefreshToken,
      );

      if (result['success'] == true) {
        if (mounted) {
          // Show team ID dialog
          _showTeamIdDialog(result['teamId']);
        }
      } else {
        if (mounted) {
          AppErrorHandler.instance
              .handle(context, result['error'] ?? 'Failed to create team');
        }
      }
    } catch (e) {
      if (mounted) {
        AppErrorHandler.instance.handle(context, e);
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
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Team Created Successfully!',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your Team ID is:',
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
                'Share this ID with your team members so they can join your team.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!mounted) return;
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                NavigationService().navigateToReplacement(const HomeScreen());
              },
              child: Text(
                'Continue',
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
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Complete Your Setup',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose how you want to proceed:',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              // Toggle between Join and Create
              Row(
                children: [
                  Expanded(
                    child: _OptionCard(
                      title: 'Join Team',
                      icon: Icons.group_add,
                      isSelected: _isJoiningTeam,
                      onTap: () => setState(() => _isJoiningTeam = true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _OptionCard(
                      title: 'Create Team',
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
                      label: 'Your Name',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_isJoiningTeam)
                      CustomTextField(
                        controller: _teamCodeController,
                        label: 'Team Code',
                        icon: Icons.qr_code,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter team code';
                          }
                          return null;
                        },
                      )
                    else
                      CustomTextField(
                        controller: _teamNameController,
                        label: 'Team Name',
                        icon: Icons.business,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter team name';
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
                    _isJoiningTeam ? 'Join Team' : 'Create Team',
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
              ? Colors.green.withOpacity(0.2)
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
