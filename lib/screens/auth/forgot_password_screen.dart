import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/navigation_service.dart';
import 'new_password_screen.dart';

class VerifyOTPScreen extends StatefulWidget {
  final String email;

  const VerifyOTPScreen({
    super.key,
    required this.email,
  });

  @override
  State<VerifyOTPScreen> createState() => _VerifyOTPScreenState();
}

class _VerifyOTPScreenState extends State<VerifyOTPScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _supabase.auth.verifyOTP(
        email: widget.email,
        token: _otpController.text.trim(),
        type: OtpType.recovery, // IMPORTANT for password reset
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("OTP verified successfully"),
          backgroundColor: Colors.green,
        ),
      );

      NavigationService().navigateTo(
        const NewPasswordScreen(),
      );
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = "Invalid or expired OTP. Please try again.";
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenWrapper(
      title: "Verify OTP",
      subtitle: "Enter the 6-digit code sent to ${widget.email}",
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
                label: "OTP Code",
                icon: Icons.lock_outline,
                controller: _otpController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter the OTP";
                  }
                  if (value.length != 6) {
                    return "OTP must be 6 digits";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: "Verify",
                onPressed: _isLoading ? null : _verifyOtp,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: "Back",
                onPressed: () => NavigationService().goBack(),
                isOutlined: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}