import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ell_ena/core/errors/app_error_handler.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/navigation_service.dart';
import '../../services/supabase_service.dart';
import '../home/home_screen.dart';
import '../auth/set_new_password_screen.dart';

class VerifyOTPScreen extends StatefulWidget {
  final String email;
  final String
      verifyType; // 'signup_join', 'signup_create', or 'reset_password'
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
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  Timer? _resendTimer;
  bool _showtimertext = false;
  bool _timerStarted = false;
  bool _isLoading = false;
  int _resendseconds = 60;
  bool _canresend = true;
  bool _otpcomplete = false;
  final _supabaseService = SupabaseService();

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _checkotpcomplete() {
    final iscomplete =
        _controllers.every((controller) => controller.text.isNotEmpty);

    if (_otpcomplete != iscomplete) {
      setState(() {
        _otpcomplete = iscomplete;
      });
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendseconds = 60;
      _canresend = false;
      _timerStarted = true;
      _showtimertext = true;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendseconds == 0) {
        timer.cancel();
        setState(() {
          _canresend = true;
          _timerStarted = false;
          _showtimertext = false;
        });
      } else {
        setState(() {
          _resendseconds--;
        });
      }
    });
  }

  Future<void> _handleVerification() async {
    String otp = _controllers.map((c) => c.text).join();
    if (otp.length == 6) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Verify OTP with Supabase
        final result = await _supabaseService.verifyOTP(
          email: widget.email,
          token: otp,
          type: widget.verifyType,
          userData: widget.userData,
        );

        if (result['success']) {
          // Handle successful verification based on verify type
          if (widget.verifyType == 'signup_create') {
            // Show team ID dialog for team creators
            if (result.containsKey('teamId')) {
              _showTeamIdDialog(result['teamId']);
            }
          } else if (widget.verifyType == 'signup_join') {
            // Navigate directly to home for team joiners
            NavigationService().navigateToReplacement(const HomeScreen());
          } else if (widget.verifyType == 'reset_password') {
            // Navigate to reset password screen
            NavigationService().navigateTo(
              SetNewPasswordScreen(email: widget.email),
            );
          }
        } else {
          if (mounted) {
            AppErrorHandler.instance
                .handle(context, result['error'] ?? 'Verification failed');
          }
        }
      } catch (e) {
        if (mounted) {
          AppErrorHandler.instance.handle(context, e);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _resendCode() async {
    if (!_canresend) {
      setState(() {
        _showtimertext = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _supabaseService.resendVerificationEmail(
        widget.email,
        type: widget.verifyType,
      );

      if (result['success']) {
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Verification code resent successfully. Please check your inbox and spam folder.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (mounted) {
          AppErrorHandler.instance
              .handle(context, result['error'] ?? 'Failed to resend code');
        }
      }
    } catch (e) {
      if (mounted) {
        AppErrorHandler.instance.handle(context, e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Show dialog with the generated team ID
  void _showTeamIdDialog(String teamId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Team Created Successfully!',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your Team ID is:',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      teamId,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
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
              Text(
                'Share this ID with your team members so they can join your team.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                NavigationService().navigateToReplacement(const HomeScreen());
              },
              child: Text(
                'Continue',
                style: TextStyle(color: Colors.green.shade400),
              ),
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
        if (_showtimertext && _timerStarted)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Resend code in 00:${_resendseconds.toString().padLeft(2, '0')}',
              style: TextStyle(
                  color: Colors.red.shade400, fontWeight: FontWeight.w500),
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
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    FocusScope.of(context).nextFocus();
                  } else {
                    FocusScope.of(context).previousFocus();
                  }
                  _checkotpcomplete();
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        DecoratedBox(
          // height:20,
          // padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Color(0xFF1B3043),
              borderRadius: BorderRadius.circular(10)),
          child: Center(
              child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Icon(
                  Icons.email,
                  color: Color(0xFF277FBD),
                ),
                const SizedBox(width: 8),
                Text("Check your spam/junk folder if you don't see the email.",
                    style: TextStyle(
                      color: Color(0xFF277FBD),
                      fontWeight: FontWeight.w500,
                    )),
              ],
            ),
          )),
        ),
        const SizedBox(height: 32),
        CustomButton(
          text: 'Verify Code',
          onPressed: (!_otpcomplete || _isLoading) ? null : _handleVerification,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Didn\'t receive the code? ',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
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
