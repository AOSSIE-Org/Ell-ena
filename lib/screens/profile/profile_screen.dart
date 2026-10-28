import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Consumer;
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme_mode.dart';
import '../../shell/app_shell.dart';
import '../../shell/shell_refreshable.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/account_actions.dart';
import 'team_members_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    implements ShellRefreshable {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _userTeams = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  Future<void> refreshFromShell() => _loadUserProfile();

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final profile = await _supabaseService.getCurrentUserProfile();

      // Also load all teams associated with the user's email
      if (profile != null && profile['email'] != null) {
        try {
          final teamsResponse =
              await _supabaseService.getUserTeams(profile['email']);
          if (teamsResponse['success'] == true &&
              teamsResponse['teams'] != null) {
            _userTeams =
                List<Map<String, dynamic>>.from(teamsResponse['teams']);
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
            content: Text(
                AppLocalizations.of(context).profileFailedToLoad('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() => confirmAndSignOut(context);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.loading),
            ],
          ),
        ),
      );
    }

    final String fullName =
        _userProfile?['full_name'] ?? l10n.profileUserFallback;
    final String role = _userProfile?['role'] ?? 'member';
    final String roleDisplay =
        role == 'admin' ? l10n.profileTeamAdmin : l10n.profileTeamMember;
    final String teamName =
        _userProfile?['teams']?['name'] ?? l10n.profileYourTeam;
    final String teamCode = _userProfile?['teams']?['team_code'] ?? '';

    if (AppShell.isDesktop(context)) {
      return _buildWideProfile(
        fullName: fullName,
        role: role,
        roleDisplay: roleDisplay,
        teamName: teamName,
      );
    }

    return Scaffold(
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
                  tooltip: l10n.logout,
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
                          color: Colors.white.withValues(alpha: 0.1),
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
                                    border: Border.all(
                                        color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .shadow
                                            .withValues(alpha: 0.2),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    size: 50,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                // Role badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: role == 'admin'
                                        ? Colors.orange.shade400
                                        : Colors.blue.shade400,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: Text(
                                    role == 'admin'
                                        ? l10n.profileAdminBadge
                                        : l10n.profileMemberBadge,
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

  /// Wide screens: identity card beside the same sections as the phone. The
  /// green header and its logout are replaced by the card and the shell's
  /// account menu.
  Widget _buildWideProfile({
    required String fullName,
    required String role,
    required String roleDisplay,
    required String teamName,
  }) {
    final sections = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTeamInfoSection(
          teamName,
          _userProfile?['teams']?['team_code'] ?? '',
        ),
        const SizedBox(height: 24),
        _buildStatsSection(),
        const SizedBox(height: 24),
        _buildSettingsSection(),
        const SizedBox(height: 24),
        _buildPreferencesSection(),
      ],
    );
    final identity = _buildIdentityCard(
      fullName: fullName,
      role: role,
      roleDisplay: roleDisplay,
      teamName: teamName,
    );

    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 900) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [identity, const SizedBox(height: 24), sections],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 320, child: identity),
                    const SizedBox(width: 24),
                    Expanded(child: sections),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityCard({
    required String fullName,
    required String role,
    required String roleDisplay,
    required String teamName,
  }) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                child: Icon(Icons.person, size: 44, color: colorScheme.primary),
              ),
              // Same role badge as the phone header.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: role == 'admin'
                      ? Colors.orange.shade400
                      : Colors.blue.shade400,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.surface, width: 2),
                ),
                child: Text(
                  role == 'admin'
                      ? l10n.profileAdminBadge
                      : l10n.profileMemberBadge,
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
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            roleDisplay,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: colorScheme.outlineVariant),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.groups_outlined, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  teamName,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker() {
    final l10n = AppLocalizations.of(context);
    final selectedLocale = ref.watch(localeControllerProvider);
    final localeController = ref.read(localeControllerProvider.notifier);

    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.selectLanguage,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              ...AppLocalizations.supportedLocales.map((locale) {
                final isSelected =
                    locale.languageCode == selectedLocale.languageCode;
                return ListTile(
                  leading: Icon(
                    Icons.language,
                    color: isSelected ? Colors.green.shade400 : null,
                  ),
                  title: Text(l10n.languageName(locale.languageCode)),
                  trailing: isSelected
                      ? Icon(Icons.check, color: Colors.green.shade400)
                      : null,
                  onTap: () async {
                    await localeController.setLocale(locale);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageSettingItem() {
    final l10n = AppLocalizations.of(context);
    final selectedLocale = ref.watch(localeControllerProvider);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.shade400.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.language_outlined, color: Colors.blue.shade400),
      ),
      title: Text(
        l10n.language,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        l10n.languageName(selectedLocale.languageCode),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: _showLanguagePicker,
    );
  }

  void _showTeamSwitcher() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            AppLocalizations.of(context).switchTeam,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _userTeams.length,
              itemBuilder: (context, index) {
                final team = _userTeams[index];
                final isCurrentTeam = team['id'] == _userProfile?['team_id'];

                final colorScheme = Theme.of(context).colorScheme;
                return ListTile(
                  title: Text(
                    team['name'] ??
                        AppLocalizations.of(context).teamFallbackName,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight:
                          isCurrentTeam ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)
                        .teamCode(team['team_code'] ?? 'N/A'),
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
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
                        return (n != null && n.isNotEmpty ? n[0] : 'T')
                            .toUpperCase();
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
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).cancel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _switchTeam(String teamId) async {
    final l10n = AppLocalizations.of(context);
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
              content: Text(l10n.profileTeamSwitched),
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
              content: Text(l10n.errorSwitchingTeam('${result['error']}')),
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
            content: Text(l10n.errorSwitchingTeam('$e')),
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
        label: Text(
          AppLocalizations.of(context).logout,
          style: const TextStyle(
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
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.profileTeamInformation,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.groups, color: colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.business, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.profileTeamName,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    teamName,
                    style: TextStyle(
                      color: colorScheme.onSurface,
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
                Icon(Icons.key, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.profileTeamId,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      teamCode,
                      style: TextStyle(
                        color: colorScheme.onSurface,
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
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.profileYourActivity,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.insights, color: colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: SupabaseService().getTasks(),
            builder: (context, snapshot) {
              final tasks = snapshot.data ?? const <Map<String, dynamic>>[];
              final completed =
                  tasks.where((t) => t['status'] == 'completed').length;
              // Placeholder dynamic numbers while no time tracking/projects table
              final hours = (tasks.length * 2).toString();
              final projects =
                  (tasks.map((t) => t['team_id']).toSet().length).toString();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(l10n.profileStatTasksCompleted,
                      completed.toString(), Colors.green.shade400),
                  _buildStatItem(
                      l10n.profileStatHoursLogged, hours, Colors.blue.shade400),
                  _buildStatItem(l10n.profileStatTeamProjects, projects,
                      Colors.purple.shade400),
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
            color: color.withValues(alpha: 0.1),
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
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    final bool isAdmin = _userProfile?['role'] == 'admin';
    final String teamId = _userProfile?['teams']?['team_code'] ?? '';
    final l10n = AppLocalizations.of(context);
    final String teamName =
        _userProfile?['teams']?['name'] ?? l10n.profileYourTeam;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settings,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Material(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildSettingItem(
                icon: Icons.person_outline,
                title: l10n.profileEditProfile,
                subtitle: l10n.profileEditProfileSubtitle,
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
                title: l10n.profileNotifications,
                subtitle: l10n.profileNotificationsSubtitle,
                iconColor: Colors.orange.shade400,
              ),
              const Divider(color: Colors.grey),
              _buildSettingItem(
                icon: Icons.security_outlined,
                title: l10n.profileSecurity,
                subtitle: l10n.profileSecuritySubtitle,
                iconColor: Colors.green.shade400,
              ),
              const Divider(color: Colors.grey),
              _buildLanguageSettingItem(),
              // Team Switcher option for users with multiple teams
              if (_userTeams.length > 1) ...[
                const Divider(color: Colors.grey),
                _buildSettingItem(
                  icon: Icons.swap_horiz,
                  title: l10n.switchTeam,
                  subtitle: l10n.profileSwitchTeamSubtitle,
                  iconColor: Colors.purple.shade400,
                  onTap: _showTeamSwitcher,
                ),
              ],
              // Only show Team Members option for admin users
              if (isAdmin && teamId.isNotEmpty) ...[
                const Divider(color: Colors.grey),
                _buildSettingItem(
                  icon: Icons.people_outline,
                  title: l10n.profileTeamMembers,
                  subtitle: l10n.profileTeamMembersSubtitle,
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

  String _themeModeLabel(AppThemeMode mode) {
    final l10n = AppLocalizations.of(context);
    switch (mode) {
      case AppThemeMode.light:
        return l10n.profileThemeLight;
      case AppThemeMode.dark:
        return l10n.profileThemeDark;
      case AppThemeMode.system:
        return l10n.profileThemeSystem;
    }
  }

  void _showThemePicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return Consumer<ThemeController>(
          builder: (context, controller, _) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: AppThemeMode.values.map((mode) {
                  final isSelected = controller.themeMode == mode;
                  return ListTile(
                    leading: Icon(
                      mode == AppThemeMode.light
                          ? Icons.light_mode
                          : mode == AppThemeMode.dark
                              ? Icons.dark_mode
                              : Icons.settings_brightness,
                    ),
                    title: Text(_themeModeLabel(mode)),
                    trailing: isSelected ? const Icon(Icons.check) : null,
                    onTap: () {
                      controller.setThemeMode(mode);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPreferencesSection() {
    return Consumer<ThemeController>(
      builder: (context, themeController, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).profilePreferences,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildThemePreferenceItem(
                    themeController: themeController,
                  ),
                  Divider(color: Theme.of(context).colorScheme.outlineVariant),
                  _buildPreferenceItem(
                    icon: Icons.notifications_active_outlined,
                    title:
                        AppLocalizations.of(context).profilePushNotifications,
                    isSwitch: true,
                    iconColor: Colors.red.shade400,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemePreferenceItem({
    required ThemeController themeController,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.purple.shade400.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.dark_mode_outlined, color: Colors.purple.shade400),
      ),
      title: Text(
        AppLocalizations.of(context).profileTheme,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        _themeModeLabel(themeController.themeMode),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: _showThemePicker,
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle:
          Text(subtitle, style: TextStyle(color: colorScheme.onSurfaceVariant)),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      onTap: onTap ??
          () {
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
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: TextStyle(color: colorScheme.onSurfaceVariant))
          : null,
      trailing: isSwitch
          ? Switch(
              value: true,
              onChanged: (value) {
                // TODO: Implement preference toggle
              },
              activeThumbColor: Colors.green.shade400,
            )
          : Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      onTap: isSwitch ? null : () {/* TODO: Implement preference navigation */},
    );
  }
}

class DotPatternPainter extends CustomPainter {
  final Color color;

  DotPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
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
