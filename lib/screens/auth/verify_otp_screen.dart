import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // One extra FocusNode per box, purely to intercept backspace key events on
  // an already-empty box (onChanged never fires for that -- there's no text
  // change) via ancestor bubbling in the focus tree. Never requests focus
  // itself (canRequestFocus: false), so it doesn't interfere with the real
  // per-box FocusNodes above.
  final List<FocusNode> _backspaceListenerNodes = List.generate(
    6,
    (index) => FocusNode(skipTraversal: true, canRequestFocus: false),
  );
  Timer? _resendTimer;
  bool _showtimertext = false;
  bool _timerStarted = false;
  bool _isLoading = false;
  int _resendseconds = 60;
  bool _canresend = true;

  String? _errorMessage;
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
    for (var node in _backspaceListenerNodes) {
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

  // Handles both normal single-digit typing and a multi-digit paste. Paste
  // reaches here as a single onChanged call with the full pasted string,
  // since maxLengthEnforcement is set to none on the field below (default
  // maxLength enforcement would silently truncate a paste to 1 char before
  // onChanged ever sees it).
  void _handleOtpChanged(int index, String value) {
    if (value.length > 1) {
      var target = index;
      for (final digit in value.split('')) {
        if (target > 5) break;
        _controllers[target].text = digit;
        target++;
      }
      final lastFilled = target > 5 ? 5 : target;
      _focusNodes[lastFilled].requestFocus();
      _controllers[lastFilled].selection = TextSelection.collapsed(
        offset: _controllers[lastFilled].text.length,
      );
      _checkotpcomplete();
      return;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }
    _checkotpcomplete();
  }

  // Backspace on an already-empty box: move focus to (and clear) the
  // previous box, matching standard OTP-input UX.
  void _handleBackspaceOnEmpty(int index) {
    if (index == 0) return;
    _focusNodes[index - 1].requestFocus();
    _controllers[index - 1].clear();
    _checkotpcomplete();
  }
  void _showErrorSnackBar(String message) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
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
        _errorMessage = null;
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
          setState(() {
            String errorMsg = result['error'] ?? 'Verification failed';

            // Make the error message more user-friendly
            if (errorMsg.contains('expired') ||
                errorMsg.contains('otp_expired')) {
              errorMsg =
                  'Verification code has expired or invalid. Please request a new code.';
            } else if (errorMsg.contains('invalid')) {
              errorMsg = 'Invalid verification code. Please try again.';
            }

            _errorMessage = errorMsg;
          });
          _showErrorSnackBar(_errorMessage!);
        }
      } catch (e) {
        setState(() {
          String errorMsg = e.toString();

          // Make the error message more user-friendly
          if (errorMsg.contains('expired') ||
              errorMsg.contains('otp_expired')) {
            errorMsg =
                'Verification code has expired. Please request a new code.';
          } else if (errorMsg.contains('invalid')) {
            errorMsg = 'Invalid verification code. Please try again.';
          } else {
            errorMsg = 'An error occurred. Please try again.';
          }

          _errorMessage = errorMsg;
        });
        _showErrorSnackBar(_errorMessage!);
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

    _startResendTimer();
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
            content: Text('Verification code resent successfully. Please check your inbox and spam folder.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          String errorMsg = result['error'] ?? 'Failed to resend code';

          // Make the error message more user-friendly
          if (errorMsg.contains('Rate limit')) {
            errorMsg = 'Too many attempts. Please try again later.';
          } else if (errorMsg.contains('not found') ||
              errorMsg.contains('Invalid email')) {
            errorMsg = 'Email address not found or invalid.';
          }

          _errorMessage = errorMsg;
        });
        _showErrorSnackBar(_errorMessage!);
      }
    } catch (e) {
      setState(() {
        String errorMsg = e.toString();

        // Make the error message more user-friendly
        if (errorMsg.contains('Rate limit')) {
          errorMsg = 'Too many attempts. Please try again later.';
        } else if (errorMsg.contains('not found') ||
            errorMsg.contains('Invalid email')) {
          errorMsg = 'Email address not found or invalid.';
        } else if (errorMsg.contains('Assertion failed')) {
          errorMsg = 'Unable to resend code. Please go back and try again.';
        } else {
          errorMsg = 'An error occurred. Please try again.';
        }

        _errorMessage = errorMsg;
      });
      _showErrorSnackBar(_errorMessage!);
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
    final resendDisabled = _isLoading || !_canresend;
    return AuthScreenWrapper(
      title: 'Verify Email',
      subtitle: 'Enter the 6-digit code sent to ${widget.email}',
      children: [
        
        // if (_errorMessage != null)
        //   Padding(
        //     padding: const EdgeInsets.only(bottom: 16),
        //     child: Text(
        //       _errorMessage!,
        //       style: const TextStyle(color: Colors.red),
        //       textAlign: TextAlign.center,
        //     ),
        //   ),
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
              child: KeyboardListener(
                focusNode: _backspaceListenerNodes[index],
                onKeyEvent: (event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.backspace &&
                      _controllers[index].text.isEmpty) {
                    _handleBackspaceOnEmpty(index);
                  }
                },
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  // Allow a full pasted string to reach onChanged instead of
                  // being silently truncated to 1 char before it gets there.
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                  onChanged: (value) => _handleOtpChanged(index, value),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        DecoratedBox(
          
          // height:20,
          // padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              
            color:Color(0xFF1B3043),
            borderRadius: BorderRadius.circular(10)
          ),
          child: Center(
            child:Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Icon(Icons.email, color: Color(0xFF277FBD),),
                  const SizedBox(width: 8),
                  Expanded(

                    child: Text(
                      "Check your spam/junk folder if you don't\n see the email.",
                      softWrap: true,
                      style:TextStyle(
                        color: Color(0xFF277FBD),
                        fontWeight: FontWeight.w500,
                      )
                    ),
                  ),
                ],
              ),
            )
          ),

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
              onPressed: resendDisabled ? null : _resendCode,
              child: Text(
                'Resend',
                style: TextStyle(
                  color: resendDisabled
                      ? Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.5)
                      : Colors.green.shade400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CustomButton(
          text: 'Back',
          onPressed: () {
            NavigationService().goBack();
          },
          isOutlined: true,
        ),
      ],
    );
  }
}
