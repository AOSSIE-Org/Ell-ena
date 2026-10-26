import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
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
      final l10n = AppLocalizations.of(context);
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
            String errorMsg = result['error'] ?? l10n.authVerificationFailed;

            // Make the error message more user-friendly
            if (errorMsg.contains('expired') ||
                errorMsg.contains('otp_expired')) {
              errorMsg = l10n.authCodeExpiredOrInvalid;
            } else if (errorMsg.contains('invalid')) {
              errorMsg = l10n.authInvalidCode;
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
            errorMsg = l10n.authCodeExpired;
          } else if (errorMsg.contains('invalid')) {
            errorMsg = l10n.authInvalidCode;
          } else {
            errorMsg = l10n.authGenericError;
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

    final l10n = AppLocalizations.of(context);
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

      if (!mounted) return;
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.authCodeResent),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          String errorMsg = result['error'] ?? l10n.authResendFailed;

          // Make the error message more user-friendly
          if (errorMsg.contains('Rate limit')) {
            errorMsg = l10n.authTooManyAttempts;
          } else if (errorMsg.contains('not found') ||
              errorMsg.contains('Invalid email')) {
            errorMsg = l10n.authEmailNotFoundOrInvalid;
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
          errorMsg = l10n.authTooManyAttempts;
        } else if (errorMsg.contains('not found') ||
            errorMsg.contains('Invalid email')) {
          errorMsg = l10n.authEmailNotFoundOrInvalid;
        } else if (errorMsg.contains('Assertion failed')) {
          errorMsg = l10n.authUnableToResend;
        } else {
          errorMsg = l10n.authGenericError;
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
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            l10n.authTeamCreatedTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.authYourTeamIdIs,
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
                      tooltip: l10n.authCopyTeamId,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: teamId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.authTeamIdCopied),
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
                l10n.authShareTeamId,
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
                l10n.authContinue,
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
    final l10n = AppLocalizations.of(context);
    return AuthScreenWrapper(
      title: l10n.authVerifyEmailTitle,
      subtitle: l10n.authVerifyEmailSubtitle(widget.email),
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
              l10n.authResendCodeIn(
                  '00:${_resendseconds.toString().padLeft(2, '0')}'),
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
                    if (index < 5) {
                      _focusNodes[index + 1].requestFocus();
                    } else {
                      _focusNodes[index].unfocus();
                      // _handleVerification();
                    }
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
              
            color: const Color(0xFF277FBD).withValues(alpha: 0.12),
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
                      l10n.authCheckSpamFolder,
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
          text: l10n.authVerifyCode,
          onPressed: (!_otpcomplete || _isLoading) ? null : _handleVerification,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.authDidNotReceiveCode,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            TextButton(
              onPressed: _isLoading ? null : _resendCode,
              child: Text(
                l10n.authResend,
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
