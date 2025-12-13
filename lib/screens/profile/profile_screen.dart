import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/data_cache_service.dart';
import '../../services/navigation_service.dart';
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
    setState(() {
      _isLoading = true;
    });

    try {
      final profile = await _supabaseService.getCurrentUserProfile();
      
      // Also load all teams associated with the user's email
      if (profile != null && profile['email'] != null) {
        try {
          final cacheService = DataCacheService();
          final teamsResponse = await cacheService.getUserTeams(
            email: profile['email'],
            forceRefresh: false,
          );
          if (teamsResponse['success'] == true && teamsResponse['teams'] != null) {
            _userTeams = List<Map<String, dynamic>>.from(teamsResponse['teams']);
          }
        } catch (e) {
          debugPrint('Error fetching user teams: $e');
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
        setState(() {
          _isLoading = false;
        });
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
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _supabaseService.signOut();
      if (mounted) {
        NavigationService().navigateToReplacement(const LoginScreen());
      }
    } catch (e) {
      debugPrint('Error logging out: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final String fullName = _userProfile?['full_name'] ?? 'User';
    final String role = _userProfile?['role'] ?? 'member';
    final String roleDisplay = role == 'admin' ? 'Team Admin' : 'Team Member';
    final String teamName = _userProfile?['teams']?['name'] ?? 'Your Team';
    final String teamCode = _userProfile?['teams']?['team_code'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: Colors.transparent,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: _handleLogout,
                  tooltip: 'Logout',
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.green.shade400, Colors.green.shade800],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Dot pattern background
                      CustomPaint(
                        painter: DotPatternPainter(
                          color: Colors.white.withOpacity(0.1),
                        ),
                        size: MediaQuery.of(context).size,
                      ),
                      // Profile content
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                // Role badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: role == 'admin' 
                                        ? Colors.orange.shade400 
                                        : Colors.blue.shade400,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Text(
                                    role == 'admin' ? 'ADMIN' : 'MEMBER',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              roleDisplay,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTeamInfoSection(teamName, teamCode),
                    const SizedBox(height: 24),
                    _buildStatsSection(),
                    const SizedBox(height: 24),
                    _buildSettingsSection(),
                    const SizedBox(height: 24),
                    _buildPreferencesSection(),
                    const SizedBox(height: 24),
                    _buildLogoutButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showTeamSwitcher() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: const Text(
            'Switch Team',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _userTeams.length,
              itemBuilder: (context, index) {
                final team = _userTeams[index];
                final isCurrentTeam = team['id'] == _userProfile?['team_id'];
                
                return ListTile(
                  title: Text(
                    team['name'] ?? 'Team',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isCurrentTeam ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    'Team Code: ${team['team_code'] ?? 'N/A'}',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: isCurrentTeam 
                        ? Colors.green.shade400 
                        : Colors.grey.shade700,
                     child: Text(
                      (() {
                        final n = (team['name'] as String?)?.trim();
                        return (n != null && n.isNotEmpty ? n[0] : 'T').toUpperCase();
                      })(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  trailing: isCurrentTeam 
                      ? Icon(Icons.check, color: Colors.green.shade400)
                      : null,
                  onTap: () {
                    if (!isCurrentTeam) {
                      _switchTeam(team['id']);
                    }
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _switchTeam(String teamId) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final result = await _supabaseService.switchTeam(teamId);
      
      if (result['success'] == true) {
        // Reload profile with new team
        await _loadUserProfile();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Team switched successfully'),
              backgroundColor: Colors.green.shade600,
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error switching team: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error switching team: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error switching team: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text(
          'Logout',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
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

  Widget _buildTeamInfoSection(String teamName, String teamCode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Team Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.groups, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.business, color: Colors.grey),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Team Name',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    teamName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (teamCode.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.key, color: Colors.grey),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Team ID',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      teamCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Activity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.insights, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: DataCacheService().getTasks(),
            builder: (context, snapshot) {
              final tasks = snapshot.data ?? const <Map<String, dynamic>>[];
              final completed = tasks.where((t) => t['status'] == 'completed').length;
              // Placeholder dynamic numbers while no time tracking/projects table
              final hours = (tasks.length * 2).toString();
              final projects =  (tasks.map((t) => t['team_id']).toSet().length).toString();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Tasks\nCompleted', completed.toString(), Colors.green.shade400),
                  _buildStatItem('Hours\nLogged', hours, Colors.blue.shade400),
                  _buildStatItem('Team\nProjects', projects, Colors.purple.shade400),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    final bool isAdmin = _userProfile?['role'] == 'admin';
    final String teamId = _userProfile?['teams']?['team_code'] ?? '';
    final String teamName = _userProfile?['teams']?['name'] ?? 'Your Team';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _buildSettingItem(
                icon: Icons.person_outline,
                title: 'Edit Profile',
                subtitle: 'Update your personal information',
                iconColor: Colors.blue.shade400,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(
                        userProfile: _userProfile!,
                        onProfileUpdated: () {
                          _loadUserProfile();
                        },
                      ),
                    ),
                  );
                },
              ),
              const Divider(color: Colors.grey),
              _buildSettingItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Manage your notification preferences',
                iconColor: Colors.orange.shade400,
              ),
              const Divider(color: Colors.grey),
              _buildSettingItem(
                icon: Icons.security_outlined,
                title: 'Security',
                subtitle: 'Configure security settings',
                iconColor: Colors.green.shade400,
              ),
              // Team Switcher option for users with multiple teams
              if (_userTeams.length > 1) ...[
                const Divider(color: Colors.grey),
                _buildSettingItem(
                  icon: Icons.swap_horiz,
                  title: 'Switch Team',
                  subtitle: 'Change to another team',
                  iconColor: Colors.purple.shade400,
                  onTap: _showTeamSwitcher,
                ),
              ],
              // Only show Team Members option for admin users
              if (isAdmin && teamId.isNotEmpty) ...[
                const Divider(color: Colors.grey),
                _buildSettingItem(
                  icon: Icons.people_outline,
                  title: 'Team Members',
                  subtitle: 'Manage your team members',
                  iconColor: Colors.purple.shade400,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TeamMembersScreen(
                          teamId: teamId,
                          teamName: teamName,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preferences',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _buildPreferenceItem(
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                isSwitch: true,
                iconColor: Colors.purple.shade400,
              ),
              const Divider(color: Colors.grey),
              _buildPreferenceItem(
                icon: Icons.notifications_active_outlined,
                title: 'Push Notifications',
                isSwitch: true,
                iconColor: Colors.red.shade400,
              ),
              const Divider(color: Colors.grey),
              _buildPreferenceItem(
                icon: Icons.language_outlined,
                title: 'Language',
                subtitle: 'English (US)',
                iconColor: Colors.blue.shade400,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    VoidCallback? onTap,
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
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade400)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white70),
      onTap: onTap ?? () {
        // Default implementation if no specific onTap is provided
        // TODO: Implement settings navigation
      },
    );
  }

  Widget _buildPreferenceItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color iconColor,
    bool isSwitch = false,
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
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle:
          subtitle != null
              ? Text(subtitle, style: TextStyle(color: Colors.grey.shade400))
              : null,
      trailing:
          isSwitch
              ? Switch(
                value: true,
                onChanged: (value) {
                  // TODO: Implement preference toggle
                },
                activeColor: Colors.green.shade400,
              )
              : const Icon(Icons.chevron_right, color: Colors.white70),
      onTap:
          isSwitch
              ? null
              : () {
                // TODO: Implement preference navigation
              },
    );
  }
}

class DotPatternPainter extends CustomPainter {
  final Color color;

  DotPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

    const spacing = 30.0;
    const dotSize = 2.0;

    for (var x = 0.0; x < size.width; x += spacing) {
      for (var y = 0.0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotSize, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotPatternPainter oldDelegate) => false;
}