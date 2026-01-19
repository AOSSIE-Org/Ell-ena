import 'package:flutter/material.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/navigation_service.dart';
import '../../services/supabase_service.dart';
import '../../services/app_shortcuts_service.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';
import 'verify_otp_screen.dart';
import 'team_selection_dialog.dart';

class SignupScreen extends StatefulWidget {
  final Map<String, dynamic>? arguments;

  const SignupScreen({super.key, this.arguments});

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

    print('[SignupScreen] initState called with arguments: ${widget.arguments}');

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
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

  // Unified method to send verification OTP and navigate
  Future<void> _sendOtpAndNavigate(String verifyType, Map<String, dynamic> userData) async {
    setState(() => _isLoading = true);

    try {
      await _supabaseService.client.auth.signInWithOtp(email: _emailController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent. Please check your inbox.'),
            backgroundColor: Colors.green,
          ),
        );

        // Merge existing arguments into userData
        if (widget.arguments != null) userData['initial_args'] = widget.arguments;

        print('[SignupScreen] Navigate to VerifyOTPScreen with userData: $userData');

        NavigationService().navigateTo(
          VerifyOTPScreen(
            email: _emailController.text,
            verifyType: verifyType,
            userData: userData,
          ),
        );
      }
    } catch (e) {
      print('[SignupScreen] Error sending OTP: $e'); // Log for debugging
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send verification email. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCreateTeam() async {
    if (!_createTeamFormKey.currentState!.validate()) return;

    final userData = {
      'teamName': _teamNameController.text,
      'adminName': _nameController.text,
      'password': _passwordController.text,
    };

    await _sendOtpAndNavigate('signup_create', userData);
  }

  Future<void> _handleJoinTeam() async {
    if (!_joinTeamFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Check if the team exists
      final teamExists = await _supabaseService.teamExists(_teamIdController.text);

      if (!teamExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Team ID not found. Please check and try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final userData = {
        'teamId': _teamIdController.text,
        'fullName': _nameController.text,
        'password': _passwordController.text,
      };

      await _sendOtpAndNavigate('signup_join', userData);
    } catch (e) {
      print('[SignupScreen] Error checking team: $e'); // Log for debugging
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to verify team. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenWrapper(
      title: 'Create Account',
      subtitle: 'Join Ell-ena to get started',
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Join the Team'),
            Tab(text: 'Create the Team'),
          ],
          labelColor: Colors.green.shade400,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.green.shade400,
          indicatorSize: TabBarIndicatorSize.tab,
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 350,
          child: TabBarView(
            controller: _tabController,
            children: [
              // Join Team Form
              Form(
                key: _joinTeamFormKey,
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _teamIdController,
                      label: 'Team ID',
                      icon: Icons.people_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter team ID';
                        if (value.length != 6) return 'Team ID must be 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your name';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your email';
                        if (!value.contains('@')) return 'Please enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your password';
                        if (value.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please confirm your password';
                        if (value != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              // Create Team Form
              Form(
                key: _createTeamFormKey,
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _teamNameController,
                      label: 'Team Name',
                      icon: Icons.group,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter team name';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _nameController,
                      label: 'Admin Name',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter admin name';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _emailController,
                      label: 'Admin Email',
                      icon: Icons.email_outlined,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter admin email';
                        if (!value.contains('@')) return 'Please enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your password';
                        if (value.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please confirm your password';
                        if (value != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        CustomButton(
          text: _tabController.index == 0 ? 'Join Team' : 'Create Team',
          onPressed: _isLoading
              ? null
              : (_tabController.index == 0 ? _handleJoinTeam : _handleCreateTeam),
          isLoading: _isLoading,
        ),
        const SizedBox(height: 24),
        // OR divider
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade700)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade700)),
          ],
        ),
        const SizedBox(height: 24),
        // Google Sign-Up Button
        Center(
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            icon: const FaIcon(
              FontAwesomeIcons.google,
              size: 20,
            ),
            label: const Text(
              'Sign up with Google',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
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
          text: 'Already have an account? Sign In',
          onPressed: () {
            NavigationService().navigateToReplacement(
              LoginScreen(arguments: widget.arguments),
            );
          },
          isOutlined: true,
        ),
      ],
    );
  }
}
