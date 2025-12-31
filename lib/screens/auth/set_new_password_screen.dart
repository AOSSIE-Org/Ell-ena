import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/navigation_service.dart';
import '../../services/supabase_service.dart';
import 'login_screen.dart';
import '../../controllers/language_controller.dart';
import 'package:get/get.dart';
import '../../utils/language/sentence_manager.dart';

class SetNewPasswordScreen extends StatefulWidget {
  final String email;

  const SetNewPasswordScreen({
    super.key,
    required this.email,
  });

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _supabaseService = SupabaseService();
  final LanguageController _languageController = Get.find<LanguageController>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSetNewPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Update the user's password
        final response = await _supabaseService.client.auth.updateUser(
          UserAttributes(
            password: _passwordController.text,
          ),
        );

        if (response.user != null) {
          if (mounted) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(SentenceManager(
                        currentLanguage:
                            _languageController.selectedLanguage.value)
                    .sentences
                    .passwordUpdatedSuccess),
                backgroundColor: Colors.green,
              ),
            );

            // Navigate to login screen
            NavigationService().navigateToReplacement(const LoginScreen());
          }
        } else {
          setState(() {
            _errorMessage = SentenceManager(
                    currentLanguage: _languageController.selectedLanguage.value)
                .sentences
                .failedUpdatePassword;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
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

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = SentenceManager(
              currentLanguage: _languageController.selectedLanguage.value)
          .sentences;
      return AuthScreenWrapper(
        title: s.setNewPasswordTitle,
        subtitle: s.setNewPasswordSubtitle,
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
                  label: s.newPasswordLabel,
                  icon: Icons.lock_outline,
                  controller: _passwordController,
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
                  label: s.confirmPasswordLabel,
                  icon: Icons.lock_outline,
                  controller: _confirmPasswordController,
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
                const SizedBox(height: 24),
                CustomButton(
                  text: s.updatePasswordBtn,
                  onPressed: _isLoading ? null : _handleSetNewPassword,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: s.backToLoginBtn,
                  onPressed: () {
                    NavigationService()
                        .navigateToReplacement(const LoginScreen());
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
