import 'package:flutter/material.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/navigation_service.dart';
import '../../services/supabase_service.dart';
import '../../services/app_shortcuts_service.dart'; // Add this import
import '../home/home_screen.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final Map<String, dynamic>? arguments;
  
  const LoginScreen({super.key, this.arguments});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    
    // Debug print to check arguments
    print('[LoginScreen] initState called with arguments: ${widget.arguments}');
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Login with Supabase
      final response = await _supabaseService.client.auth.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      
      if (response.user != null) {
        // Get any pending shortcut
        final pendingShortcut = AppShortcutsService.getPendingShortcut();
        print('[LoginScreen] Pending shortcut after login: $pendingShortcut');
        
        // Prepare arguments for HomeScreen
        Map<String, dynamic> homeScreenArgs = widget.arguments ?? {};
        
        // If we have a pending shortcut, add it to arguments
        if (pendingShortcut != null) {
          final screenIndex = _getScreenIndex(pendingShortcut);
          if (screenIndex != null) {
            homeScreenArgs['screen'] = screenIndex;
            homeScreenArgs['initial_route'] = pendingShortcut;
          }
        }
        
        // If no shortcut but we have arguments from widget, use them
        if (homeScreenArgs.isEmpty) {
          // Check if we have arguments passed to LoginScreen
          if (widget.arguments != null && widget.arguments!.containsKey('screen')) {
            homeScreenArgs = widget.arguments!;
          }
        }
        
        print('[LoginScreen] Navigating to HomeScreen with args: $homeScreenArgs');
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeScreen(arguments: homeScreenArgs),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid email or password'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('[LoginScreen] Login error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString()}'), 
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

  // Helper method to convert shortcut route to screen index
  int? _getScreenIndex(String? route) {
    if (route == null) return null;
    
    switch (route) {
      case 'dashboard': return 0;
      case 'calendar': return 1;
      case 'workspace': return 2;
      case 'chat': return 3;
      case 'profile': return 4;
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenWrapper(
      title: 'Welcome Back',
      subtitle: 'Sign in to continue with Ell-ena',
      children: [
        FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
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
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        NavigationService().navigateTo(
                          const ForgotPasswordScreen(),
                        );
                      },
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Colors.green.shade400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Sign In',
                    onPressed: _isLoading ? null : _handleLogin,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account? ',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                      TextButton(
                        onPressed: () {
                          // Pass any arguments to SignupScreen if needed
                          NavigationService().navigateTo(
                            SignupScreen(arguments: widget.arguments),
                          );
                        },
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                            color: Colors.green.shade400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}