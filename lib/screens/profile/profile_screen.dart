import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/supabase_service.dart';
import '../../services/navigation_service.dart';
import '../../providers/theme_provider.dart';

import '../auth/login_screen.dart';
import 'team_members_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _userTeams = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    try {
      final profile = await _supabaseService.getCurrentUserProfile();

      if (profile != null && profile['email'] != null) {
        final teamsResponse =
            await _supabaseService.getUserTeams(profile['email']);
        if (teamsResponse['success'] == true) {
          _userTeams =
              List<Map<String, dynamic>>.from(teamsResponse['teams'] ?? []);
        }
      }

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoading = true);

    try {
      await _supabaseService.signOut();
      if (mounted) {
        NavigationService().navigateToReplacement(const LoginScreen());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPreferencesSection(),
            const SizedBox(height: 24),
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  // -------------------- PREFERENCES --------------------

  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preferences',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  return _buildPreferenceItem(
                    icon: Icons.dark_mode_outlined,
                    title: 'Dark Mode',
                    isSwitch: true,
                    iconColor: Colors.purple.shade400,
                    switchValue: themeProvider.isDarkMode,
                    onSwitchChanged: (_) {
                      themeProvider.toggleTheme();
                    },
                  );
                },
              ),
              const Divider(),
              _buildPreferenceItem(
                icon: Icons.notifications_active_outlined,
                title: 'Push Notifications',
                isSwitch: true,
                iconColor: Colors.red.shade400,
                switchValue: false,
                onSwitchChanged: (_) {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color iconColor,
    bool isSwitch = false,
    bool? switchValue,
    ValueChanged<bool>? onSwitchChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: isSwitch
          ? Switch(
              value: switchValue ?? false,
              onChanged: onSwitchChanged,
            )
          : const Icon(Icons.chevron_right),
    );
  }

  // -------------------- LOGOUT --------------------

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout),
        label: const Text('Logout'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade400,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
