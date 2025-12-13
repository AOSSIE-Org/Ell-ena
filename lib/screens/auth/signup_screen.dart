import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/navigation_service.dart';
import '../../services/supabase_service.dart';
import '../home/home_screen.dart';
import '../team_selection_dialog.dart';
import 'login_screen.dart';
import 'verify_otp_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
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

    setState(() => _isLoading = true);

    try {
      // Only send signup email without creating user upfront
      await _supabaseService.client.auth.signInWithOtp(
        email: _emailController.text,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent. Please check your inbox.'),
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

    setState(() => _isLoading = true);

    try {
      // First check if the team exists
      final teamExists = await _supabaseService.teamExists(_teamIdController.text);
      
      if (!teamExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Team ID not found. Please check and try again.'),
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
          const SnackBar(
            content: Text('Verification email sent. Please check your inbox.'),
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
    setState(() => _isLoading = true);

    try {
      final result = await _supabaseService.signInWithGoogle();
      
      if (result['success']) {
        // Wait for OAuth callback and check user status
        await Future.delayed(const Duration(seconds: 2));
        
        final statusResult = await _supabaseService.checkUserTeamStatus();
        
        if (mounted) {
          if (statusResult['success']) {
            if (statusResult['needsTeamSetup'] == true) {
              // Show team selection dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => TeamSelectionDialog(
                  email: statusResult['email'] ?? '',
                  fullName: statusResult['fullName'] ?? '',
                  googleRefreshToken: _supabaseService.client.auth.currentSession?.providerRefreshToken,
                ),
              );
            } else {
              // User already has a team, navigate to home
              NavigationService().navigateToReplacement(const HomeScreen());
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(statusResult['error'] ?? 'Failed to check user status'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Failed to sign in with Google'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
          height: 350, // Adjust height as needed
          child: TabBarView(
            controller: _tabController,
            children: [
              // Join Team Tab
              Form(
                key: _joinTeamFormKey,
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _teamIdController,
                      label: 'Team ID',
                      icon: Icons.people_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter team ID';
                        }
                        if (value.length != 6) {
                          return 'Team ID must be 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
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
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
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
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              // Create Team Tab
              Form(
                key: _createTeamFormKey,
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _teamNameController,
                      label: 'Team Name',
                      icon: Icons.group,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter team name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _nameController,
                      label: 'Admin Name',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter admin name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _emailController,
                      label: 'Admin Email',
                      icon: Icons.email_outlined,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter admin email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
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
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
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
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
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
        const SizedBox(height: 24),
        CustomButton(
          text: _tabController.index == 0 ? 'Join Team' : 'Create Team',
          onPressed: _isLoading 
              ? null 
              : (_tabController.index == 0 ? _handleJoinTeam : _handleCreateTeam),
          isLoading: _isLoading,
        ),
        const SizedBox(height: 24),
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
        _GoogleSignInButton(
          onPressed: _isLoading ? null : _handleGoogleSignIn,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 16),
        CustomButton(
          text: 'Already have an account? Sign In',
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

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const _GoogleSignInButton({
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Image.asset(
                'assets/google_logo.png',
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.g_mobiledata,
                  size: 32,
                  color: Colors.white,
                ),
              ),
        label: Text(
          isLoading ? 'Signing up...' : 'Sign up with Google',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: BorderSide(color: Colors.grey.shade700, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
