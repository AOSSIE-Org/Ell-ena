import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/navigation_service.dart';
import '../../services/supabase_service.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';
import 'verify_otp_screen.dart';
import 'team_selection_dialog.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _joinTeamFormKey = GlobalKey<FormState>();
  final _createTeamFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _teamNameController = TextEditingController();
  final _teamIdController = TextEditingController();
  bool _isLoading = false;
  late TabController _tabController;
  final _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _teamNameController.dispose();
    _teamIdController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Handle team creation
  Future<void> _handleCreateTeam() async {
    if (!_createTeamFormKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);

    setState(() => _isLoading = true);

    try {
      // Only send signup email without creating user upfront
      await _supabaseService.client.auth.signInWithOtp(
        email: _emailController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.authVerificationEmailSent),
            backgroundColor: Colors.green,
          ),
        );

        NavigationService().navigateTo(
          VerifyOTPScreen(
            email: _emailController.text,
            verifyType: 'signup_create',
            userData: {
              'teamName': _teamNameController.text,
              'adminName': _nameController.text,
              'password': _passwordController.text,
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Handle joining a team
  Future<void> _handleJoinTeam() async {
    if (!_joinTeamFormKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);

    setState(() => _isLoading = true);

    try {
      // First check if the team exists
      final teamExists =
          await _supabaseService.teamExists(_teamIdController.text);

      if (!teamExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.authTeamIdNotFound),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      // Only send signup email without creating user upfront
      await _supabaseService.client.auth.signInWithOtp(
        email: _emailController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.authVerificationEmailSent),
            backgroundColor: Colors.green,
          ),
        );

        NavigationService().navigateTo(
          VerifyOTPScreen(
            email: _emailController.text,
            verifyType: 'signup_join',
            userData: {
              'teamId': _teamIdController.text,
              'fullName': _nameController.text,
              'password': _passwordController.text,
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isLoading = true);

    try {
      final result = await _supabaseService.signInWithGoogle();

      if (mounted) {
        if (result['pendingRedirect'] == true) {
          return;
        }
        if (result['success'] == true) {
          if (result['isNewUser'] == true) {
            // New user - show team selection dialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => TeamSelectionDialog(
                userEmail: result['email'] ?? '',
                googleRefreshToken: result['googleRefreshToken'],
              ),
            );
          } else {
            // Existing user - go to home
            NavigationService().navigateToReplacement(const HomeScreen());
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? l10n.authGoogleSignInFailed),
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

  Widget _buildJoinTeamForm() {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _joinTeamFormKey,
      child: Column(
        children: [
          const SizedBox(height: 12), // Spacing for floating label
          CustomTextField(
            controller: _teamIdController,
            label: l10n.authTeamIdLabel,
            icon: Icons.people_outline,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.authEnterTeamId;
              }
              if (value.length != 6) {
                return l10n.authTeamIdLength;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _nameController,
            label: l10n.authFullNameLabel,
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.authEnterName;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _emailController,
            label: l10n.authEmailLabel,
            icon: Icons.email_outlined,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.authEnterEmail;
              }
              if (!value.contains('@')) {
                return l10n.authEnterValidEmail;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _passwordController,
            label: l10n.authPasswordLabel,
            icon: Icons.lock_outline,
            isPassword: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.authEnterPassword;
              }
              if (value.length < 6) {
                return l10n.authPasswordTooShort;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _confirmPasswordController,
            label: l10n.authConfirmPasswordLabel,
            icon: Icons.lock_outline,
            isPassword: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.authConfirmPasswordPrompt;
              }
              if (value != _passwordController.text) {
                return l10n.authPasswordsDoNotMatch;
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCreateTeamForm() {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _createTeamFormKey,
      child: Column(
        children: [
          const SizedBox(height: 12), // Spacing for floating label
          CustomTextField(
            controller: _teamNameController,
            label: l10n.authTeamNameLabel,
            icon: Icons.group,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.authEnterTeamName;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _nameController,
            label: l10n.authAdminNameLabel,
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.authEnterAdminName;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _emailController,
            label: l10n.authAdminEmailLabel,
            icon: Icons.email_outlined,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.authEnterAdminEmail;
              }
              if (!value.contains('@')) {
                return l10n.authEnterValidEmail;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _passwordController,
            label: l10n.authPasswordLabel,
            icon: Icons.lock_outline,
            isPassword: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.authEnterPassword;
              }
              if (value.length < 6) {
                return l10n.authPasswordTooShort;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _confirmPasswordController,
            label: l10n.authConfirmPasswordLabel,
            icon: Icons.lock_outline,
            isPassword: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.authConfirmPasswordPrompt;
              }
              if (value != _passwordController.text) {
                return l10n.authPasswordsDoNotMatch;
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScreenWrapper(
      title: l10n.authCreateAccount,
      subtitle: l10n.authSignUpSubtitle,
      centerOnWideScreens: true,
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.authJoinTheTeamTab),
            Tab(text: l10n.authCreateTheTeamTab),
          ],
          labelColor: Colors.green.shade400,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: Colors.green.shade400,
          indicatorSize: TabBarIndicatorSize.tab,
          onTap: (index) => setState(() {}),
        ),
        const SizedBox(height: 24),
        // Renders the specific form based on selection without fixed height constraints
        _tabController.index == 0
            ? _buildJoinTeamForm()
            : _buildCreateTeamForm(),
        const SizedBox(height: 24),
        CustomButton(
          text: _tabController.index == 0
              ? l10n.authJoinTeam
              : l10n.authCreateTeam,
          onPressed: _isLoading
              ? null
              : (_tabController.index == 0
                  ? _handleJoinTeam
                  : _handleCreateTeam),
          isLoading: _isLoading,
        ),
        const SizedBox(height: 24),
        // OR divider
        Row(
          children: [
            Expanded(child: Divider(color: Theme.of(context).dividerColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.authOr,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: Divider(color: Theme.of(context).dividerColor)),
          ],
        ),
        const SizedBox(height: 24),
        // Google Sign-Up Button
        Center(
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            icon: FaIcon(
              FontAwesomeIcons.google,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
            label: Text(
              l10n.authSignUpWithGoogle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: BorderSide(color: Colors.green.shade400, width: 2),
              padding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        CustomButton(
          text: l10n.authAlreadyHaveAccount,
          onPressed: () {
            NavigationService().navigateToReplacement(
              const LoginScreen(),
            );
          },
          isOutlined: true,
        ),
      ],
    );
  }
}
