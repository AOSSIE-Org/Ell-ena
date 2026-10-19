import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/navigation_service.dart';
import '../../services/supabase_service.dart';
import 'login_screen.dart';

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
      final l10n = AppLocalizations.of(context);
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
                content: Text(l10n.authPasswordUpdated),
                backgroundColor: Colors.green,
              ),
            );
            
            // Navigate to login screen
            NavigationService().navigateToReplacement(const LoginScreen());
          }
        } else {
          setState(() {
            _errorMessage = l10n.authPasswordUpdateFailed;
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
    final l10n = AppLocalizations.of(context);
    return AuthScreenWrapper(
      title: l10n.authSetNewPasswordTitle,
      subtitle: l10n.authSetNewPasswordSubtitle,
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
                label: l10n.authNewPasswordLabel,
                icon: Icons.lock_outline,
                controller: _passwordController,
                isPassword: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.authEnterNewPassword;
                  }
                  if (value.length < 6) {
                    return l10n.authPasswordTooShort;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: l10n.authConfirmPasswordLabel,
                icon: Icons.lock_outline,
                controller: _confirmPasswordController,
                isPassword: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.authConfirmPasswordPrompt;
                  }
                  if (value != _passwordController.text) {
                    return l10n.authPasswordsDoNotMatch;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: l10n.authUpdatePassword,
                onPressed: _isLoading ? null : _handleSetNewPassword,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: l10n.authBackToLogin,
                onPressed: () {
                  NavigationService().navigateToReplacement(const LoginScreen());
                },
                isOutlined: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
} 