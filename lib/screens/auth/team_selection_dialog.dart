import 'package:flutter/material.dart';
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
  bool _isJoiningTeam = true;

  @override
  void dispose() {
    _teamCodeController.dispose();
    _teamNameController.dispose();
    _userNameController.dispose();
    super.dispose();
  }

  void _switchMode(bool join) {
    setState(() {
      _isJoiningTeam = join;

      // Clear irrelevant fields
      if (join) {
        _teamNameController.clear();
      } else {
        _teamCodeController.clear();
      }
    });
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

      if (!mounted) return;

      if (result != null && result['success'] == true) {
        Navigator.of(context).pop();
        NavigationService().navigateToReplacement(const HomeScreen());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result?['error'] ?? 'Failed to join team'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

      if (!mounted) return;

      if (result != null && result['success'] == true) {
        _showTeamIdDialog(result['teamId']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result?['error'] ?? 'Failed to create team'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showTeamIdDialog(String teamId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Team Created Successfully!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your Team ID is:'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  teamId,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Share this ID with your team members so they can join.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!mounted) return;

                Navigator.of(context).pop(); // close ID dialog
                Navigator.of(context).pop(); // close main dialog
                NavigationService()
                    .navigateToReplacement(const HomeScreen());
              },
              child: const Text(
                'Continue',
                style: TextStyle(color: Colors.green),
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
      onPopInvoked: (didPop) {}, // Prevent back button completely
      child: AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Complete Your Setup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose how you want to proceed:'),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _OptionCard(
                      title: 'Join Team',
                      icon: Icons.group_add,
                      isSelected: _isJoiningTeam,
                      onTap: () => _switchMode(true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _OptionCard(
                      title: 'Create Team',
                      icon: Icons.add_business,
                      isSelected: !_isJoiningTeam,
                      onTap: () => _switchMode(false),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _userNameController,
                      label: 'Your Name',
                      icon: Icons.person_outline,
                      validator: (value) =>
                          value == null || value.isEmpty
                              ? 'Please enter your name'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    _isJoiningTeam
                        ? CustomTextField(
                            controller: _teamCodeController,
                            label: 'Team Code',
                            icon: Icons.qr_code,
                            validator: (value) =>
                                value == null || value.isEmpty
                                    ? 'Please enter team code'
                                    : null,
                          )
                        : CustomTextField(
                            controller: _teamNameController,
                            label: 'Team Name',
                            icon: Icons.business,
                            validator: (value) =>
                                value == null || value.isEmpty
                                    ? 'Please enter team name'
                                    : null,
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
                : (_isJoiningTeam
                    ? _handleJoinTeam
                    : _handleCreateTeam),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _isJoiningTeam
                        ? 'Join Team'
                        : 'Create Team',
                    style: const TextStyle(
                        color: Colors.green),
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
              ? Colors.green.withOpacity(0.15)
              : Theme.of(context)
                  .colorScheme
                  .surfaceContainerLow,
          border: Border.all(
            color: isSelected
                ? Colors.green
                : Theme.of(context)
                    .colorScheme
                    .outline,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.green
                  : Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}