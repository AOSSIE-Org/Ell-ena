import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for Clipboard if needed, though used in verify_otp not here? Ah, verify_otp used it. This file doesn't use clipboard? Wait, _showTeamIdDialog *doesn't* have copy button here? Let me check source.
import '../../services/supabase_service.dart';
import '../../services/navigation_service.dart';
import '../../widgets/custom_widgets.dart';
import '../home/home_screen.dart';
import 'package:get/get.dart';
import '../../utils/language/sentence_manager.dart';

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

      if (mounted) {
        if (result['success']) {
          Navigator.of(context).pop();
          NavigationService().navigateToReplacement(const HomeScreen());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  result['error'] ?? SentenceManager.instance.failedJoinTeam),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${SentenceManager.instance.errorPrefix}$e'),
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
              content: Text(
                  result['error'] ?? SentenceManager.instance.failedCreateTeam),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${SentenceManager.instance.errorPrefix}$e'),
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
        return Obx(() {
          final s = SentenceManager.instance;
          return AlertDialog(
            backgroundColor: const Color(0xFF2A2A2A),
            title: Text(
              s.teamCreatedSuccess,
              style: const TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.yourTeamIdIs,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    teamId,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  s.shareTeamId,
                  style: const TextStyle(color: Colors.grey),
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
                  s.continueBtn,
                  style: TextStyle(color: Colors.green.shade400),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent dismissal
      child: Obx(() {
        final s = SentenceManager.instance;
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: Text(
            s.completeSetupTitle,
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.completeSetupSubtitle,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                // Toggle between Join and Create
                Row(
                  children: [
                    Expanded(
                      child: _OptionCard(
                        title: s.joinTeamBtn,
                        icon: Icons.group_add,
                        isSelected: _isJoiningTeam,
                        onTap: () => setState(() => _isJoiningTeam = true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _OptionCard(
                        title: s.createTeamBtn,
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
                        label: s.fullNameLabel,
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return s.enterName;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_isJoiningTeam)
                        CustomTextField(
                          controller: _teamCodeController,
                          label: s.teamCodeLabel,
                          icon: Icons.qr_code,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return s.enterTeamCode;
                            }
                            return null;
                          },
                        )
                      else
                        CustomTextField(
                          controller: _teamNameController,
                          label: s.teamNameLabel,
                          icon: Icons.business,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return s.enterTeamName;
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
                      _isJoiningTeam ? s.joinTeamBtn : s.createTeamBtn,
                      style: TextStyle(color: Colors.green.shade400),
                    ),
            ),
          ],
        );
      }),
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
              : const Color(0xFF1A1A1A),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey.shade800,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.green : Colors.grey,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
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
