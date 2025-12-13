import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_widgets.dart';
import 'home/home_screen.dart';
import '../services/navigation_service.dart';

class TeamSelectionDialog extends StatefulWidget {
  final String email;
  final String fullName;
  final String? googleRefreshToken;

  const TeamSelectionDialog({
    super.key,
    required this.email,
    required this.fullName,
    this.googleRefreshToken,
  });

  @override
  State<TeamSelectionDialog> createState() => _TeamSelectionDialogState();
}

class _TeamSelectionDialogState extends State<TeamSelectionDialog> {
  final _supabaseService = SupabaseService();
  final _teamCodeController = TextEditingController();
  final _teamNameController = TextEditingController();
  final _joinFormKey = GlobalKey<FormState>();
  final _createFormKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _selectedOption = 'join'; // 'join' or 'create'

  @override
  void dispose() {
    _teamCodeController.dispose();
    _teamNameController.dispose();
    super.dispose();
  }

  Future<void> _handleJoinTeam() async {
    if (!_joinFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _supabaseService.joinTeamViaOAuth(
        email: widget.email,
        fullName: widget.fullName,
        teamCode: _teamCodeController.text.toUpperCase(),
        googleRefreshToken: widget.googleRefreshToken,
      );

      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully joined team!'),
              backgroundColor: Colors.green,
            ),
          );
          NavigationService().navigateToReplacement(const HomeScreen());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Failed to join team'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleCreateTeam() async {
    if (!_createFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _supabaseService.createTeamViaOAuth(
        email: widget.email,
        fullName: widget.fullName,
        teamName: _teamNameController.text,
        googleRefreshToken: widget.googleRefreshToken,
      );

      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Team created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          NavigationService().navigateToReplacement(const HomeScreen());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Failed to create team'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevents dismissal
      child: Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Row(
                children: [
                  Icon(Icons.people, color: Colors.green.shade400, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Complete Your Setup',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Join an existing team or create a new one',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              // Option Cards
              Row(
                children: [
                  Expanded(
                    child: _OptionCard(
                      title: 'Join Team',
                      icon: Icons.login,
                      isSelected: _selectedOption == 'join',
                      onTap: () => setState(() => _selectedOption = 'join'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OptionCard(
                      title: 'Create Team',
                      icon: Icons.add_circle_outline,
                      isSelected: _selectedOption == 'create',
                      onTap: () => setState(() => _selectedOption = 'create'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Forms
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _selectedOption == 'join'
                    ? _buildJoinForm()
                    : _buildCreateForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJoinForm() {
    return Form(
      key: _joinFormKey,
      child: Column(
        key: const ValueKey('join'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomTextField(
            controller: _teamCodeController,
            label: 'Team Code',
            icon: Icons.vpn_key,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter team code';
              }
              if (value.length != 6) {
                return 'Team code must be 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the 6-character team code provided by your admin',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Join Team',
            onPressed: _isLoading ? null : _handleJoinTeam,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    return Form(
      key: _createFormKey,
      child: Column(
        key: const ValueKey('create'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomTextField(
            controller: _teamNameController,
            label: 'Team Name',
            icon: Icons.group,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter team name';
              }
              if (value.length < 3) {
                return 'Team name must be at least 3 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a name for your new team workspace',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Create Team',
            onPressed: _isLoading ? null : _handleCreateTeam,
            isLoading: _isLoading,
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.green.shade800.withOpacity(0.3)
              : const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.green.shade400 : Colors.grey.shade800,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.green.shade400 : Colors.grey.shade400,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade400,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
