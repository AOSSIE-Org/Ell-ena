import 'dart:convert';

import 'package:ell_ena/services/ai_service.dart';
import 'package:ell_ena/services/app_startup.dart';
import 'package:ell_ena/services/supabase_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/fake_backend.dart';

/// The singletons before (and after a failed) start-up. This file never calls
/// `setUpFakeSupabase`, so nothing here may reach a network.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Serves [contents] as the bundled `.env`.
  void serveEnv(String contents) {
    rootBundle.evict('.env');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      if (key == '.env') return ByteData.sublistView(utf8.encode(contents));
      return null;
    });
  }

  group('before initialize', () {
    final service = SupabaseService();
    const notReady = {
      'success': false,
      'error': 'Supabase is not initialized',
    };

    test('reports no user and no readiness', () {
      expect(service.isInitialized, isFalse);
      expect(service.currentUser, isNull);
    });

    test('every write answers "not initialized"', () async {
      final date = DateTime(2026);
      final answers = <Map<String, dynamic>>[
        await service.getUserTeams('a@b.c'),
        await service.switchTeam('t'),
        await service.createTeam(
            teamName: 't', adminName: 'a', adminEmail: 'e', password: 'p'),
        await service.joinTeam(
            teamId: 't', fullName: 'f', email: 'e', password: 'p'),
        await service.signInWithGoogle(),
        await service.joinTeamWithGoogle(
            email: 'e', teamCode: 't', fullName: 'f'),
        await service.createTeamWithGoogle(
            email: 'e', teamName: 't', adminName: 'a'),
        await service.verifyOTP(email: 'e', token: '1', type: 'signup'),
        await service.resendVerificationEmail('e'),
        await service.createTask(title: 't'),
        await service.updateTaskStatus(taskId: 't', status: 's'),
        await service.updateTaskTicket(taskId: 't'),
        await service.updateTaskApproval(taskId: 't', approvalStatus: 'a'),
        await service.addTaskComment(taskId: 't', content: 'c'),
        await service.deleteTask('t'),
        await service.createTicket(title: 't', priority: 'p', category: 'c'),
        await service.syncTicketToGithub('t'),
        await service.updateTicketStatus(ticketId: 't', status: 's'),
        await service.updateTicketPriority(ticketId: 't', priority: 'p'),
        await service.updateTicketApproval(ticketId: 't', approvalStatus: 'a'),
        await service.addTicketComment(ticketId: 't', content: 'c'),
        await service.deleteTicket('t'),
        await service.assignTicket(ticketId: 't', userId: 'u'),
        await service.createMeeting(title: 't', meetingDate: date),
        await service.startBot(meetingId: 'm', meetingUrl: 'u'),
        await service.updateMeeting(
            meetingId: 'm', title: 't', meetingDate: date),
        await service.deleteMeeting('m'),
      ];

      for (final answer in answers) {
        expect(answer, notReady);
      }
      expect(
        await service.fetchAndProcessTranscript(
            meetingId: 'm', meetingUrl: 'u'),
        notReady,
      );
    });

    test('every read comes back empty', () async {
      expect(await service.teamExists('ABC123'), isFalse);
      expect(await service.getCurrentUserProfile(), isNull);
      expect(await service.updateUserProfile({'a': 1}), isFalse);
      expect(await service.getTeamMembers('ABC123'), isEmpty);
      expect(await service.getTasks(), isEmpty);
      expect(await service.getTaskDetails('t'), isNull);
      expect(await service.getTickets(), isEmpty);
      expect(await service.getTicketDetails('t'), isNull);
      expect(await service.getMeetings(), isEmpty);
      expect(await service.getMeetingDetails('m'), isNull);
      await service.loadTeamMembers('ABC123');
      expect(service.teamMembersCache, isEmpty);
      await service.signOut();
    });
  });

  group('failed start-up', () {
    test('initialize throws when the Supabase keys are missing', () async {
      serveEnv('GEMINI_API_KEY=key\n');

      await expectLater(
        SupabaseService().initialize(),
        throwsA(predicate(
            (e) => e.toString().contains('Missing required Supabase'))),
      );
      expect(SupabaseService().isInitialized, isFalse);
    });

    test('AIService needs a Gemini key', () async {
      serveEnv('SUPABASE_URL=\n');

      await expectLater(
        AIService().initialize(),
        throwsA(predicate((e) => e.toString().contains('Missing Gemini'))),
      );
      expect(AIService().isInitialized, isFalse);
    });

    test('AIService fails when Supabase cannot start', () async {
      serveEnv('GEMINI_API_KEY=key\n');

      await expectLater(AIService().initialize(), throwsException);
      expect(AIService().isInitialized, isFalse);
    });

    test('AppStartup surfaces the failure and allows a retry', () async {
      serveEnv('GEMINI_API_KEY=key\n');

      await expectLater(AppStartup.ensureInitialized(), throwsException);
      expect(AppStartup.isReady, isFalse);

      final retry = AppStartup.ensureInitialized();
      await expectLater(retry, throwsException);
      expect(AppStartup.isReady, isFalse);
    });

    test('a missing .env file is treated as missing keys', () async {
      rootBundle.evict('.env');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (_) async => null);

      await expectLater(SupabaseService().initialize(), throwsException);
      await expectLater(
        AIService().initialize(),
        throwsA(predicate((e) => e.toString().contains('Missing Gemini'))),
      );
    });

    // Last: this one succeeds, so the singleton stays initialised afterwards.
    test('start-up restores the profile cached by an earlier session',
        () async {
      final backend = FakeBackend();
      SharedPreferences.setMockInitialValues({
        'user_profile': jsonEncode({
          'id': FakeBackend.userId,
          'full_name': 'Cached Ada',
          'team_id': null,
        }),
      });
      serveEnv('SUPABASE_URL=https://fake.supabase.co\n'
          'SUPABASE_ANON_KEY=anon-key\n');
      await Supabase.initialize(
        url: 'https://fake.supabase.co',
        anonKey: 'anon-key',
        httpClient: backend.client,
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
          detectSessionInUri: false,
          autoRefreshToken: false,
        ),
      );

      await SupabaseService().initialize();
      await Supabase.instance.client.auth.signInWithPassword(
          email: FakeBackend.userEmail, password: 'password');
      backend.log.clear();

      final profile = await SupabaseService().getCurrentUserProfile();
      expect(profile!['full_name'], 'Cached Ada');
      expect(backend.log, isEmpty);
    });
  });
}
