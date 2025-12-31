import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/navigation_service.dart';
import '../../services/supabase_service.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';
import 'verify_otp_screen.dart';
import 'team_selection_dialog.dart';
import '../../controllers/language_controller.dart';
import 'package:get/get.dart';
import '../../utils/language/sentence_manager.dart';

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
  final LanguageController _languageController = Get.find<LanguageController>();

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
          SnackBar(
            content: Text(SentenceManager(
                    currentLanguage: _languageController.selectedLanguage.value)
                .sentences
                .sentVerificationEmail),
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
      final teamExists =
          await _supabaseService.teamExists(_teamIdController.text);

      if (!teamExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(SentenceManager(
                      currentLanguage:
                          _languageController.selectedLanguage.value)
                  .sentences
                  .teamIdNotFound),
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
            content: Text(SentenceManager(
                    currentLanguage: _languageController.selectedLanguage.value)
                .sentences
                .sentVerificationEmail),
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

      if (mounted) {
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
              content: Text(result['error'] ??
                  SentenceManager(
                          currentLanguage:
                              _languageController.selectedLanguage.value)
                      .sentences
                      .googleSignInFailed),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${SentenceManager(currentLanguage: _languageController.selectedLanguage.value).sentences.errorPrefix}$e'),
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

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = SentenceManager(
              currentLanguage: _languageController.selectedLanguage.value)
          .sentences;
      return AuthScreenWrapper(
        title: s.createAccountTitle,
        subtitle: s.joinAppSubtitle,
        children: [
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: s.joinTeamTab),
              Tab(text: s.createTeamTab),
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
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        CustomTextField(
                          controller: _teamIdController,
                          label: s.teamIdLabel,
                          icon: Icons.people_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return s.enterTeamId;
                            }
                            if (value.length != 6) {
                              return s.teamIdLength;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _nameController,
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
                        CustomTextField(
                          controller: _emailController,
                          label: s.email,
                          icon: Icons.email_outlined,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return s.enterEmail;
                            }
                            if (!value.contains('@')) {
                              return s.validEmail;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _passwordController,
                          label: s.password,
                          icon: Icons.lock_outline,
                          isPassword: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return s.enterPassword;
                            }
                            if (value.length < 6) {
                              return s.passwordLength;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _confirmPasswordController,
                          label: s.confirmPasswordLabel,
                          icon: Icons.lock_outline,
                          isPassword: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return s.confirmPasswordValidator;
                            }
                            if (value != _passwordController.text) {
                              return s.passwordsDoNotMatch;
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Create Team Tab
                Form(
                  key: _createTeamFormKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        CustomTextField(
                          controller: _teamNameController,
                          label: s.teamNameLabel,
                          icon: Icons.group,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return s.enterTeamName;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _nameController,
                          label: s.adminNameLabel,
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return s.enterAdminName;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _emailController,
                          label: s.adminEmailLabel,
                          icon: Icons.email_outlined,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return s.enterAdminEmail;
                            }
                            if (!value.contains('@')) {
                              return s.validEmail;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _passwordController,
                          label: s.password,
                          icon: Icons.lock_outline,
                          isPassword: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return s.enterPassword;
                            }
                            if (value.length < 6) {
                              return s.passwordLength;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _confirmPasswordController,
                          label: s.confirmPasswordLabel,
                          icon: Icons.lock_outline,
                          isPassword: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return s.confirmPasswordValidator;
                            }
                            if (value != _passwordController.text) {
                              return s.passwordsDoNotMatch;
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: _tabController.index == 0 ? s.joinTeamBtn : s.createTeamBtn,
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
              Expanded(child: Divider(color: Colors.grey.shade700)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  s.or,
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
              label: Text(
                s.signUpGoogle,
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
            text: s.alreadyHaveAccount,
            onPressed: () {
              NavigationService().navigateToReplacement(
                const LoginScreen(),
              );
            },
            isOutlined: true,
          ),
        ],
      );
    });
  }
}
