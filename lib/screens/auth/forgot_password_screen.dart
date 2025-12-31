import 'package:flutter/material.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/navigation_service.dart';
import '../../services/supabase_service.dart';
import 'verify_otp_screen.dart';
import '../../controllers/language_controller.dart';
import 'package:get/get.dart';
import '../../utils/language/sentence_manager.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _supabaseService = SupabaseService();
  final LanguageController _languageController = Get.find<LanguageController>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Request password reset email from Supabase
        await _supabaseService.client.auth.resetPasswordForEmail(
          _emailController.text,
        );

        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(SentenceManager(
                      currentLanguage:
                          _languageController.selectedLanguage.value)
                  .sentences
                  .resetCodeSent),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to verification screen
          NavigationService().navigateTo(
            VerifyOTPScreen(
              email: _emailController.text,
              verifyType: 'reset_password',
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          // Show user-friendly error message
          setState(() {
            final s = SentenceManager(
                    currentLanguage: _languageController.selectedLanguage.value)
                .sentences;
            String errorMsg = s.errorOccurred;

            // Parse the error message to be more user-friendly
            if (e.toString().contains('Invalid email')) {
              errorMsg = s.invalidEmailError;
            } else if (e.toString().contains('Email not found')) {
              errorMsg = s.emailNotFoundError;
            } else if (e.toString().contains('Rate limit')) {
              errorMsg = s.tooManyAttempts;
            }

            _errorMessage = errorMsg;
          });
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
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
        title: s.resetPasswordTitle,
        subtitle: s.resetPasswordSubtitle,
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
          Form(
            key: _formKey,
            child: Column(
              children: [
                CustomTextField(
                  label: s.email,
                  icon: Icons.email_outlined,
                  controller: _emailController,
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
                const SizedBox(height: 24),
                CustomButton(
                  text: s.sendResetCodeBtn,
                  onPressed: _isLoading ? null : _handleResetPassword,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: s.backToLoginBtn,
                  onPressed: () {
                    NavigationService().goBack();
                  },
                  isOutlined: true,
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}
