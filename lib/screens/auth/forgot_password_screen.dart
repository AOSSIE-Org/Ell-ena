import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/navigation_service.dart';
import '../../services/supabase_service.dart';
import 'verify_otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _supabaseService = SupabaseService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (_formKey.currentState!.validate()) {
      final l10n = AppLocalizations.of(context);
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
              content: Text(l10n.authResetCodeSent),
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
            String errorMsg = l10n.authGenericError;
            
            // Parse the error message to be more user-friendly
            if (e.toString().contains('Invalid email')) {
              errorMsg = l10n.authInvalidEmailAddress;
            } else if (e.toString().contains('Email not found')) {
              errorMsg = l10n.authEmailNotFound;
            } else if (e.toString().contains('Rate limit')) {
              errorMsg = l10n.authTooManyAttempts;
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
    final l10n = AppLocalizations.of(context);
    return AuthScreenWrapper(
      title: l10n.authResetPasswordTitle,
      subtitle: l10n.authResetPasswordSubtitle,
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
                label: l10n.authEmailLabel,
                icon: Icons.email_outlined,
                controller: _emailController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.authEnterEmail;
                  }
                  if (!value.contains('@')) {
                    return l10n.authEnterValidEmail;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: l10n.authSendResetCode,
                onPressed: _isLoading ? null : _handleResetPassword,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: l10n.authBackToLogin,
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
  }
}