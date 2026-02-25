import 'package:flutter/material.dart';
import 'package:ell_ena/core/errors/app_error_handler.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        // Request password reset email from Supabase
        await _supabaseService.client.auth.resetPasswordForEmail(
          _emailController.text,
        );
        
        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reset code sent to your email'),
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
          AppErrorHandler.instance.handle(context, e);
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
    return AuthScreenWrapper(
      title: 'Reset Password',
      subtitle: 'Enter your email to receive a reset code',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              CustomTextField(
                label: 'Email',
                icon: Icons.email_outlined,
                controller: _emailController,
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
              const SizedBox(height: 24),
              CustomButton(
                text: 'Send Reset Code',
                onPressed: _isLoading ? null : _handleResetPassword,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Back to Login',
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