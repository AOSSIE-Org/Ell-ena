import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/navigation_service.dart';
import '../../services/supabase_service.dart';
import '../home/home_screen.dart';
import '../auth/set_new_password_screen.dart';
import '../../controllers/language_controller.dart';
import 'package:get/get.dart';
import '../../utils/language/sentence_manager.dart';

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
  bool _isLoading = false;
  String? _errorMessage;
  final _supabaseService = SupabaseService();
  final LanguageController _languageController = Get.find<LanguageController>();

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
      final s = SentenceManager(
              currentLanguage: _languageController.selectedLanguage.value)
          .sentences;
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
            String errorMsg = result['error'] ?? s.errorOccurred;

            // Make the error message more user-friendly
            if (errorMsg.contains('expired') ||
                errorMsg.contains('otp_expired')) {
              errorMsg = s.expiredCode;
            } else if (errorMsg.contains('invalid')) {
              errorMsg = s.invalidCode;
            }

            _errorMessage = errorMsg;
          });
        }
      } catch (e) {
        setState(() {
          String errorMsg = e.toString();

          // Make the error message more user-friendly
          if (errorMsg.contains('expired') ||
              errorMsg.contains('otp_expired')) {
            errorMsg = s.expiredCode;
          } else if (errorMsg.contains('invalid')) {
            errorMsg = s.invalidCode;
          } else {
            errorMsg = s.errorOccurred;
          }

          _errorMessage = errorMsg;
        });
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
    final s = SentenceManager(
            currentLanguage: _languageController.selectedLanguage.value)
        .sentences;
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
          SnackBar(
            content: Text(s.codeResent),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          String errorMsg = result['error'] ?? s.failedResend;

          // Make the error message more user-friendly
          if (errorMsg.contains('Rate limit')) {
            errorMsg = s.tooManyAttempts;
          } else if (errorMsg.contains('not found') ||
              errorMsg.contains('Invalid email')) {
            errorMsg = s.emailNotFoundValidation;
          }

          _errorMessage = errorMsg;
        });
      }
    } catch (e) {
      setState(() {
        String errorMsg = e.toString();

        // Make the error message more user-friendly
        if (errorMsg.contains('Rate limit')) {
          errorMsg = s.tooManyAttempts;
        } else if (errorMsg.contains('not found') ||
            errorMsg.contains('Invalid email')) {
          errorMsg = s.emailNotFoundValidation;
        } else if (errorMsg.contains('Assertion failed')) {
          errorMsg = s.unableResend;
        } else {
          errorMsg = s.errorOccurred;
        }

        _errorMessage = errorMsg;
      });
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
        return Obx(() {
          final s = SentenceManager(
                  currentLanguage: _languageController.selectedLanguage.value)
              .sentences;
          return AlertDialog(
            backgroundColor: const Color(0xFF2A2A2A),
            title: Text(
              s.teamCreatedSuccess,
              style: const TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.yourTeamIdIs,
                  style: const TextStyle(color: Colors.grey),
                ),
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
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.green),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: teamId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(s.teamIdCopied),
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
                  s.shareTeamId,
                  style: const TextStyle(color: Colors.grey),
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
                  s.continueBtn,
                  style: TextStyle(color: Colors.green.shade400),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = SentenceManager(
              currentLanguage: _languageController.selectedLanguage.value)
          .sentences;
      return AuthScreenWrapper(
        title: s.verifyEmailTitle,
        subtitle: '${s.enterCodeSent}${widget.email}',
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
            text: s.verifyCodeBtn,
            onPressed: _isLoading ? null : _handleVerification,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                s.didntReceiveCode,
                style: TextStyle(color: Colors.grey.shade400),
              ),
              TextButton(
                onPressed: _isLoading ? null : _resendCode,
                child: Text(
                  s.resendBtn,
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
    });
  }
}
