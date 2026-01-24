import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/navigation_service.dart';
import '../../services/supabase_service.dart';
import '../../services/app_shortcuts_service.dart';
import '../home/home_screen.dart';
import '../auth/set_new_password_screen.dart';

class VerifyOTPScreen extends StatefulWidget {
  final String email;
  final String verifyType; // 'signup_join', 'signup_create', or 'reset_password'
  final Map<String, dynamic> userData;

  const VerifyOTPScreen({
    super.key,
    required this.email,
    required this.verifyType,
    this.userData = const {},
  });

  @override
  State<VerifyOTPScreen> createState() => _VerifyOTPScreenState();
}

class _VerifyOTPScreenState extends State<VerifyOTPScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  String? _errorMessage;
  final _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    // Removed debug prints for production safety
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _handleVerification() async {
    String otp = _controllers.map((c) => c.text).join();
    if (otp.length == 6) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final result = await _supabaseService.verifyOTP(
          email: widget.email,
          token: otp,
          type: widget.verifyType,
          userData: widget.userData,
        );

        if (result['success']) {
          if (widget.verifyType == 'signup_create' && result.containsKey('teamId')) {
            _showTeamIdDialog(result['teamId']);
          } else if (widget.verifyType == 'signup_join') {
            _navigateToHomeScreen();
          } else if (widget.verifyType == 'reset_password') {
            NavigationService().navigateTo(
              SetNewPasswordScreen(email: widget.email),
            );
          }
        } else {
          setState(() {
            _errorMessage = _friendlyErrorMessage(result['error']);
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = _friendlyErrorMessage(e.toString());
        });
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  String _friendlyErrorMessage(String? rawMessage) {
    if (rawMessage == null) return 'Verification failed. Please try again.';
    if (rawMessage.contains('expired') || rawMessage.contains('otp_expired')) {
      return 'Verification code has expired. Please request a new code.';
    } else if (rawMessage.contains('invalid')) {
      return 'Invalid verification code. Please try again.';
    }
    return 'An error occurred. Please try again.';
  }

  void _navigateToHomeScreen() {
    final pendingShortcut = AppShortcutsService.getPendingShortcut();

    // Use a copy of initial_args safely
    Map<String, dynamic> homeScreenArgs = {};
    final initialArgs = widget.userData['initial_args'];
    if (initialArgs is Map<String, dynamic>) {
      homeScreenArgs = Map<String, dynamic>.from(initialArgs);
    }

    if (pendingShortcut != null) {
      final screenIndex = _getScreenIndex(pendingShortcut);
      if (screenIndex != null) {
        homeScreenArgs['screen'] = screenIndex;
        homeScreenArgs['initial_route'] = pendingShortcut;
      }
    }

    if (homeScreenArgs.isEmpty) {
      homeScreenArgs = {'screen': 0};
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => HomeScreen(arguments: homeScreenArgs),
      ),
    );
  }

  int? _getScreenIndex(String? route) {
    switch (route) {
      case 'dashboard':
        return 0;
      case 'calendar':
        return 1;
      case 'workspace':
        return 2;
      case 'chat':
        return 3;
      case 'profile':
        return 4;
      default:
        return null;
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _supabaseService.resendVerificationEmail(
        widget.email,
        type: widget.verifyType,
      );

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code resent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _errorMessage = _friendlyErrorMessage(result['error']);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = _friendlyErrorMessage(e.toString());
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showTeamIdDialog(String teamId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text('Team Created Successfully!',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your Team ID is:', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      teamId,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.green),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: teamId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Team ID copied to clipboard'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Share this ID with your team members so they can join your team.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToHomeScreen();
              },
              child: Text('Continue', style: TextStyle(color: Colors.green.shade400)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenWrapper(
      title: 'Verify Email',
      subtitle: 'Enter the 6-digit code sent to ${widget.email}',
      children: [
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            6,
            (index) => SizedBox(
              width: 50,
              height: 60,
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                keyboardType: TextInputType.number,
                maxLength: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    if (index < 5) {
                      _focusNodes[index + 1].requestFocus();
                    } else {
                      _focusNodes[index].unfocus();
                      _handleVerification();
                    }
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        CustomButton(
          text: 'Verify Code',
          onPressed: _isLoading ? null : _handleVerification,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Didn\'t receive the code? ',
              style: TextStyle(color: Colors.grey.shade400),
            ),
            TextButton(
              onPressed: _isLoading ? null : _resendCode,
              child: Text(
                'Resend',
                style: TextStyle(
                  color: Colors.green.shade400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
