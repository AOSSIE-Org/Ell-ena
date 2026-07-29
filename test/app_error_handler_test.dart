import 'dart:async';

import 'package:ell_ena/utils/app_error_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AppErrorHandler', () {
    test('maps network failures', () {
      final info = AppErrorHandler.classify(
        http.ClientException('Connection refused'),
      );
      expect(info.kind, AppErrorKind.network);
      expect(info.message, AppErrorHandler.networkMessage);

      expect(
        AppErrorHandler.messageFor(
          Exception('SocketException: Failed host lookup'),
        ),
        AppErrorHandler.networkMessage,
      );
    });

    test('maps timeouts', () {
      final info = AppErrorHandler.classify(
        TimeoutException('Timed out'),
      );
      expect(info.kind, AppErrorKind.timeout);
      expect(info.message, AppErrorHandler.timeoutMessage);

      expect(
        AppErrorHandler.messageFor('Authentication timed out'),
        AppErrorHandler.timeoutMessage,
      );
    });

    test('maps authentication / session failures', () {
      final info = AppErrorHandler.classify(
        AuthException('JWT expired'),
      );
      expect(info.kind, AppErrorKind.authentication);
      expect(info.message, AppErrorHandler.authenticationMessage);

      expect(
        AppErrorHandler.messageFor(null, statusCode: 401),
        AppErrorHandler.authenticationMessage,
      );
    });

    test('maps server / HTTP 5xx failures', () {
      expect(
        AppErrorHandler.messageFor('upstream failed', statusCode: 503),
        AppErrorHandler.serverMessage,
      );
      expect(
        AppErrorHandler.messageFor('Internal Server Error'),
        AppErrorHandler.serverMessage,
      );
    });

    test('preserves short domain messages', () {
      expect(
        AppErrorHandler.messageFor('Team not found'),
        'Team not found',
      );
      expect(
        AppErrorHandler.messageFor('User not authenticated'),
        AppErrorHandler.authenticationMessage,
      );
    });

    test('uses fallback for unknown technical dumps', () {
      expect(
        AppErrorHandler.messageFor(
          'Exception: Instance of \'_HttpClientConnection\'\n#0 ...',
          fallback: 'Could not complete the request',
        ),
        'Could not complete the request',
      );
    });
  });
}
