import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Categories of failures we surface to users with consistent copy.
enum AppErrorKind {
  network,
  timeout,
  authentication,
  server,
  unknown,
}

/// User-facing error details derived from an exception or status code.
class AppErrorInfo {
  final AppErrorKind kind;
  final String message;

  const AppErrorInfo({
    required this.kind,
    required this.message,
  });
}

/// Maps network / auth / API failures to clear, consistent messages.
///
/// Prefer [messageFor] when returning `error` fields from services, and
/// [showSnackBar] when presenting failures in the UI.
class AppErrorHandler {
  AppErrorHandler._();

  static const String networkMessage =
      'No internet connection. Please check your network and try again.';
  static const String timeoutMessage =
      'The request is taking longer than expected. Please try again.';
  static const String authenticationMessage =
      'Your session has expired. Please sign in again.';
  static const String serverMessage =
      'Something went wrong on our end. Please try again later.';
  static const String unknownMessage =
      'Something went wrong. Please try again.';

  /// Classify [error] (and optional HTTP [statusCode]) into a user message.
  static AppErrorInfo classify(Object? error, {int? statusCode}) {
    if (statusCode != null) {
      final fromStatus = _fromStatusCode(statusCode);
      if (fromStatus != null) return fromStatus;
    }

    if (error == null) {
      return const AppErrorInfo(
        kind: AppErrorKind.unknown,
        message: unknownMessage,
      );
    }

    if (error is TimeoutException) {
      return const AppErrorInfo(
        kind: AppErrorKind.timeout,
        message: timeoutMessage,
      );
    }

    if (error is http.ClientException) {
      return const AppErrorInfo(
        kind: AppErrorKind.network,
        message: networkMessage,
      );
    }

    if (error is AuthException) {
      return _fromAuthException(error);
    }

    if (error is PostgrestException) {
      return _fromPostgrestException(error);
    }

    return _fromMessage(error.toString());
  }

  /// Returns a user-friendly message for [error].
  ///
  /// Short, already-friendly domain messages (e.g. "Team not found") are kept.
  /// Technical exception dumps are replaced with the mapped copy above.
  static String messageFor(
    Object? error, {
    int? statusCode,
    String? fallback,
  }) {
    if (statusCode != null) {
      final fromStatus = _fromStatusCode(statusCode);
      if (fromStatus != null) {
        return fromStatus.message;
      }
    }

    if (error is String) {
      final trimmed = error.trim();
      if (trimmed.isEmpty) {
        return fallback ?? unknownMessage;
      }

      final classified = _fromMessage(trimmed);
      if (classified.kind != AppErrorKind.unknown) {
        return classified.message;
      }

      if (_looksUserFacing(trimmed)) {
        return trimmed;
      }

      return fallback ?? unknownMessage;
    }

    final info = classify(error, statusCode: statusCode);
    if (info.kind == AppErrorKind.unknown && fallback != null) {
      return fallback;
    }
    return info.message;
  }

  /// Shows a consistent floating error [SnackBar] for [error].
  static void showSnackBar(
    BuildContext context,
    Object? error, {
    int? statusCode,
    String? fallback,
    Color backgroundColor = Colors.red,
  }) {
    if (!context.mounted) return;

    final message = messageFor(
      error,
      statusCode: statusCode,
      fallback: fallback,
    );

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  static AppErrorInfo? _fromStatusCode(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return const AppErrorInfo(
        kind: AppErrorKind.authentication,
        message: authenticationMessage,
      );
    }
    if (statusCode == 408 || statusCode == 504) {
      return const AppErrorInfo(
        kind: AppErrorKind.timeout,
        message: timeoutMessage,
      );
    }
    if (statusCode >= 500) {
      return const AppErrorInfo(
        kind: AppErrorKind.server,
        message: serverMessage,
      );
    }
    if (statusCode == 0) {
      return const AppErrorInfo(
        kind: AppErrorKind.network,
        message: networkMessage,
      );
    }
    return null;
  }

  static AppErrorInfo _fromAuthException(AuthException error) {
    final lower = error.message.toLowerCase();

    if (_isNetworkMessage(lower) || _isTimeoutMessage(lower)) {
      return _fromMessage(error.message);
    }

    if (_isAuthSessionMessage(lower) ||
        lower.contains('jwt') ||
        lower.contains('refresh token') ||
        lower.contains('not authenticated')) {
      return const AppErrorInfo(
        kind: AppErrorKind.authentication,
        message: authenticationMessage,
      );
    }

    if (_looksUserFacing(error.message)) {
      return AppErrorInfo(
        kind: AppErrorKind.authentication,
        message: error.message,
      );
    }

    return const AppErrorInfo(
      kind: AppErrorKind.authentication,
      message: authenticationMessage,
    );
  }

  static AppErrorInfo _fromPostgrestException(PostgrestException error) {
    final code = int.tryParse(error.code ?? '');
    if (code != null) {
      final fromStatus = _fromStatusCode(code);
      if (fromStatus != null) return fromStatus;
    }

    final lower = '${error.message} ${error.code ?? ''}'.toLowerCase();
    if (_isNetworkMessage(lower)) {
      return const AppErrorInfo(
        kind: AppErrorKind.network,
        message: networkMessage,
      );
    }
    if (_isTimeoutMessage(lower)) {
      return const AppErrorInfo(
        kind: AppErrorKind.timeout,
        message: timeoutMessage,
      );
    }
    if (_isAuthSessionMessage(lower)) {
      return const AppErrorInfo(
        kind: AppErrorKind.authentication,
        message: authenticationMessage,
      );
    }

    if (_looksUserFacing(error.message)) {
      return AppErrorInfo(
        kind: AppErrorKind.server,
        message: error.message,
      );
    }

    return const AppErrorInfo(
      kind: AppErrorKind.server,
      message: serverMessage,
    );
  }

  static AppErrorInfo _fromMessage(String raw) {
    final cleaned = raw
        .replaceFirst(RegExp(r'^(Exception|Error):\s*', caseSensitive: false), '')
        .trim();
    final lower = cleaned.toLowerCase();

    if (_isNetworkMessage(lower)) {
      return const AppErrorInfo(
        kind: AppErrorKind.network,
        message: networkMessage,
      );
    }
    if (_isTimeoutMessage(lower)) {
      return const AppErrorInfo(
        kind: AppErrorKind.timeout,
        message: timeoutMessage,
      );
    }
    if (_isAuthSessionMessage(lower)) {
      return const AppErrorInfo(
        kind: AppErrorKind.authentication,
        message: authenticationMessage,
      );
    }
    if (_isServerMessage(lower)) {
      return const AppErrorInfo(
        kind: AppErrorKind.server,
        message: serverMessage,
      );
    }

    if (_looksUserFacing(cleaned)) {
      return AppErrorInfo(
        kind: AppErrorKind.unknown,
        message: cleaned,
      );
    }

    return const AppErrorInfo(
      kind: AppErrorKind.unknown,
      message: unknownMessage,
    );
  }

  static bool _isNetworkMessage(String lower) {
    return lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('network error') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection abort') ||
        lower.contains('clientexception') ||
        lower.contains('no internet') ||
        lower.contains('offline') ||
        lower.contains('failed to connect') ||
        lower.contains('xmlhttprequest error') ||
        lower.contains('software caused connection abort');
  }

  static bool _isTimeoutMessage(String lower) {
    return lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('timeoutexception') ||
        lower.contains('taking longer');
  }

  static bool _isAuthSessionMessage(String lower) {
    return lower.contains('session has expired') ||
        lower.contains('session expired') ||
        lower.contains('jwt expired') ||
        lower.contains('invalid jwt') ||
        lower.contains('invalid claim') ||
        lower.contains('refresh_token') ||
        lower.contains('not authenticated') ||
        lower.contains('unauthorized') ||
        lower.contains('user not authenticated');
  }

  static bool _isServerMessage(String lower) {
    return lower.contains('internal server error') ||
        lower.contains('bad gateway') ||
        lower.contains('service unavailable') ||
        lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503');
  }

  static bool _looksUserFacing(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty || trimmed.length > 160) return false;

    final lower = trimmed.toLowerCase();
    if (lower.contains('exception') ||
        lower.contains('socket') ||
        lower.contains('stacktrace') ||
        lower.contains('http://') ||
        lower.contains('https://') ||
        lower.startsWith('error:') ||
        RegExp(r'\n').hasMatch(trimmed)) {
      return false;
    }

    return true;
  }
}
