import 'package:flutter/foundation.dart';

enum AppErrorCategory { auth, database, network, unknown }

@immutable
class AppError {
  final AppErrorCategory category;
  final String code;
  final String userMessage;
  final dynamic originalError;

  const AppError({
    required this.category,
    required this.code,
    required this.userMessage,
    this.originalError,
  });

  factory AppError.auth({required String code, required String userMessage, dynamic originalError}) =>
      AppError(category: AppErrorCategory.auth, code: code, userMessage: userMessage, originalError: originalError);

  factory AppError.authWeakPassword({dynamic originalError}) =>
      AppError(category: AppErrorCategory.auth, code: 'weak_password', userMessage: 'Password is too weak. Please use a stronger one.', originalError: originalError);

  factory AppError.authExpiredToken({dynamic originalError}) =>
      AppError(category: AppErrorCategory.auth, code: 'expired_token', userMessage: 'Token has expired or is invalid.', originalError: originalError);

  factory AppError.authUserAlreadyExists({dynamic originalError}) =>
      AppError(category: AppErrorCategory.auth, code: 'user_already_exists', userMessage: 'User already exists.', originalError: originalError);

  factory AppError.authUserNotFound({dynamic originalError}) =>
      AppError(category: AppErrorCategory.auth, code: 'user_not_found', userMessage: 'User does not exist.', originalError: originalError);

  factory AppError.authRateLimit({dynamic originalError}) => AppError(
        category: AppErrorCategory.auth,
        code: 'rate_limit',
        userMessage: 'Please wait a moment before requesting another code.',
        originalError: originalError,
      );

  factory AppError.database({required String code, required String userMessage, dynamic originalError}) =>
      AppError(category: AppErrorCategory.database, code: code, userMessage: userMessage, originalError: originalError);

  factory AppError.network({required String code, required String userMessage, dynamic originalError}) =>
      AppError(category: AppErrorCategory.network, code: code, userMessage: userMessage, originalError: originalError);

  factory AppError.unknown({String code = 'unknown', String userMessage = 'Something went wrong', dynamic originalError}) =>
      AppError(category: AppErrorCategory.unknown, code: code, userMessage: userMessage, originalError: originalError);
}