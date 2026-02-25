import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_ena/core/errors/app_error_handler.dart';
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
              const SnackBar(
                content: Text('Password updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
            
            // Navigate to login screen
            NavigationService().navigateToReplacement(const LoginScreen());
          }
        } else {
          if (mounted) {
            AppErrorHandler.instance
                .handle(context, 'Failed to update password');
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

  @override
  Widget build(BuildContext context) {
    return AuthScreenWrapper(
      title: 'Set New Password',
      subtitle: 'Create a new password for your account',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              CustomTextField(
                label: 'New Password',
                icon: Icons.lock_outline,
                controller: _passwordController,
                isPassword: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Confirm Password',
                icon: Icons.lock_outline,
                controller: _confirmPasswordController,
                isPassword: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Update Password',
                onPressed: _isLoading ? null : _handleSetNewPassword,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Back to Login',
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