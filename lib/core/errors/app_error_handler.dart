import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_error.dart';

class AppErrorHandler {
  AppErrorHandler._internal();
  static final AppErrorHandler instance = AppErrorHandler._internal();

  void handle(BuildContext context, dynamic error) {
    // THIS IS THE DATA CAPTURE LINE
    debugPrint('RAW_ERROR_LOG: $error | TYPE: ${error.runtimeType}');

    final appError = mapError(error);
    show(context, appError);
  }

  AppError mapError(dynamic error) {
    final message = _getMessage(error);
    final messageLower = message.toLowerCase();
    final code = _getCode(error);
    final typeName = error.runtimeType.toString();

    // Network: AuthRetryableFetchException or message contains SocketException / Failed host lookup
    if (typeName.contains('AuthRetryableFetchException') ||
        typeName.contains('AuthRetryableFetchError') ||
        messageLower.contains('socketexception') ||
        messageLower.contains('failed host lookup')) {
      return AppError.network(
        code: 'network_error',
        userMessage: 'Network error. Please check your connection.',
        originalError: error,
      );
    }

    if (error is AuthApiException) {
      return _mapAuthException(error);
    }

    // Expired OTP / token
    if (messageLower.contains('otp_expired') ||
        message.contains('Token has expired or is invalid')) {
      return AppError.authExpiredToken(originalError: error);
    }

    // Already exists: Postgrest 23505 or duplicate key
    if (code == '23505' || messageLower.contains('duplicate key value')) {
      return AppError.authUserAlreadyExists(originalError: error);
    }

    // Invalid credentials
    if (code == 'invalid_credentials') {
      return AppError.auth(
        code: 'invalid_credentials',
        userMessage: 'Invalid email or password.',
        originalError: error,
      );
    }

    // Email format / validation
    if (code == 'validation_failed') {
      return AppError.auth(
        code: 'bad_format',
        userMessage: 'Invalid email format.',
        originalError: error,
      );
    }

    // Explicit user_not_found (e.g. from forgot password check)
    if (error == 'user_not_found' || code == 'user_not_found') {
      return AppError.authUserNotFound(originalError: error);
    }

    // Explicit user_already_exists (e.g. from signup check)
    if (error == 'user_already_exists' || code == 'user_already_exists') {
      return AppError.authUserAlreadyExists(originalError: error);
    }

    return AppError.unknown(originalError: error);
  }

  AppError _mapAuthException(AuthApiException e) {
    final code = (e.code ?? '').toString();
    final message = (e.message ?? '').toString();
    final messageLower = message.toLowerCase();

    // Rate Limit
    if (code == 'over_email_send_rate_limit' || message.contains('45 seconds')) {
      return AppError.authRateLimit(originalError: e);
    }

    // Expired OTP
    if (code == 'otp_expired' || messageLower.contains('expired')) {
      return AppError.auth(
        userMessage: 'Token has expired or is invalid.',
        code: 'expired_otp',
        originalError: e,
      );
    }

    // Invalid Format
    if (code == 'validation_failed') {
      return AppError.auth(
        userMessage: 'Invalid email format.',
        code: 'bad_format',
        originalError: e,
      );
    }

    return AppError.auth(
      code: code.isEmpty ? 'auth_error' : code,
      userMessage: message.isEmpty ? 'Authentication error.' : message,
      originalError: e,
    );
  }

  String _getMessage(dynamic error) {
    if (error == null) return '';
    if (error is String) return error;
    try {
      final m = (error as dynamic).message;
      if (m != null) return m.toString();
    } catch (_) {}
    return error.toString();
  }

  String _getCode(dynamic error) {
    if (error == null) return '';
    if (error is String) return error;
    try {
      final c = (error as dynamic).code;
      if (c != null) return c.toString();
    } catch (_) {}
    // Postgrest often puts code in message, e.g. "23505: ..."
    final msg = _getMessage(error);
    final match = RegExp(r'^(\d{5})').firstMatch(msg);
    if (match != null) return match.group(1)!;
    return '';
  }

  void show(BuildContext context, AppError appError) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(appError.userMessage),
          backgroundColor: appError.category == AppErrorCategory.network 
              ? Colors.orange.shade800 
              : Colors.red.shade700,
        ),
      );
  }
}