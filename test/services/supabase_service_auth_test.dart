import 'dart:convert';

import 'package:ell_ena/services/supabase_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/test_harness.dart';
import 'supabase_service_fixtures.dart';

void main() {
  setUpAll(setUpFakeSupabase);
  setUp(() => resetFakeSupabase(signedIn: false));

  /// Answers `check_team_code_exists` from [taken], recording each code.
  List<String> stubTeamCodes(Set<String> taken, {bool takenByDefault = false}) {
    final asked = <String>[];
    backend.rpcs['check_team_code_exists'] = (body) {
      final code = body['code'] as String;
      asked.add(code);
      return takenByDefault || taken.contains(code);
    };
    return asked;
  }

  group('team codes', () {
    test('generateTeamId makes six uppercase letters or digits', () {
      final service = signedOutService();
      final ids = List.generate(200, (_) => service.generateTeamId());

      for (final id in ids) {
        expect(id, matches(RegExp(r'^[A-Z0-9]{6}$')));
      }
      expect(ids.toSet().length, greaterThan(190));
    });

    test('teamExists follows the RPC answer and fails closed', () async {
      final service = await signedInService();
      stubTeamCodes({'ABC123'});

      expect(await service.teamExists('ABC123'), isTrue);
      expect(await service.teamExists('NOPE00'), isFalse);

      backend.rpcs.remove('check_team_code_exists');
      expect(await service.teamExists('ABC123'), isFalse);
    });
  });

  group('getUserTeams', () {
    test('lists the teams attached to the email', () async {
      backend.table('users').add({
        'id': 'user-1b',
        'email': FakeBackend.userEmail,
        'team_id': 'team-2',
        'teams': {'name': 'Second', 'team_code': 'SEC222'},
      });
      backend.table('users').add({
        'id': 'user-1c',
        'email': FakeBackend.userEmail,
        'team_id': null,
        'teams': null,
      });
      final service = await signedInService();

      final result = await service.getUserTeams(FakeBackend.userEmail);

      expect(result['success'], isTrue);
      expect(result['teams'], [
        {
          'id': FakeBackend.teamId,
          'name': 'Analytical Engines',
          'team_code': 'ABC123'
        },
        {'id': 'team-2', 'name': 'Second', 'team_code': 'SEC222'},
      ]);
    });

    test('returns an empty list for unknown emails and errors safely',
        () async {
      final service = await signedInService();
      expect(await service.getUserTeams('nobody@example.com'),
          {'success': true, 'teams': []});

      backend.failures['users'] = 500;
      final failed = await service.getUserTeams(FakeBackend.userEmail);
      expect(failed['success'], isFalse);
      expect(failed['teams'], isEmpty);
    });
  });

  group('switchTeam', () {
    test('updates the cached profile and reloads members', () async {
      backend.seedSecondTeam();
      final service = await signedInService();
      await service.getCurrentUserProfile();
      backend.moveUserToSecondTeam();

      final result = await service.switchTeam(FakeBackend.secondTeamId);

      expect(result['success'], isTrue);
      expect(result['team']['team_code'], FakeBackend.secondTeamCode);
      final profile = await service.getCurrentUserProfile();
      expect(profile!['team_id'], FakeBackend.secondTeamId);
      expect(profile['teams']['name'], FakeBackend.secondTeamName);
      // Ada's main row moved to the second team; Bob stayed behind.
      expect(service.teamMembersCache.map((m) => m['full_name']), ['Ada']);
      final prefs = await SharedPreferences.getInstance();
      final stored = jsonDecode(prefs.getString('user_profile')!) as Map;
      expect(stored['team_id'], FakeBackend.secondTeamId);
    });

    test('refuses teams the user is not in or that do not exist', () async {
      final service = await signedInService();

      expect((await service.switchTeam('team-9'))['error'],
          'User is not a member of this team');

      backend.table('teams').clear();
      expect((await service.switchTeam(FakeBackend.teamId))['error'],
          'Team not found');
    });

    test('works without a cached profile and reports errors', () async {
      final service = await signedInService();
      expect((await service.switchTeam(FakeBackend.teamId))['success'], isTrue);

      backend.failures['users'] = 500;
      expect(
          (await service.switchTeam(FakeBackend.teamId))['success'], isFalse);
    });
  });

  group('team members', () {
    test('getTeamMembers resolves a team code to its members', () async {
      final service = await signedInService();

      final members = await service.getTeamMembers('ABC123');

      expect(
          members.map((m) => m['full_name']), unorderedEquals(['Ada', 'Bob']));
      expect(backend.log.first, 'GET /rest/v1/teams');
      expect(backend.log.last, 'GET /rest/v1/users');
    });

    test('getTeamMembers takes a UUID directly', () async {
      final service = await signedInService();

      final members = await service.getTeamMembers(FakeBackend.teamId);

      expect(members, hasLength(2));
      expect(backend.log, isNot(contains('GET /rest/v1/teams')));
    });

    test('getTeamMembers returns nothing for unknown codes or errors',
        () async {
      final service = await signedInService();
      expect(await service.getTeamMembers('ZZZZZZ'), isEmpty);

      backend.failures['teams'] = 500;
      expect(await service.getTeamMembers('ABC123'), isEmpty);
    });

    test('loadTeamMembers caches per team and names come from the cache',
        () async {
      final service = await signedInService();

      await service.loadTeamMembers(FakeBackend.teamId);
      final requests = backend.log.length;
      await service.loadTeamMembers(FakeBackend.teamId);

      expect(backend.log.length, requests);
      expect(service.getUserNameById('user-2'), 'Bob');
      expect(service.getUserNameById('stranger'), 'Team Member');
    });

    test('loadTeamMembers keeps going when the lookup throws', () async {
      final service = await signedInService(
        intercept: (r) => r.url.path.endsWith('/users')
            ? throw http.ClientException('down')
            : null,
      );

      await service.loadTeamMembers(FakeBackend.teamId);

      expect(service.teamMembersCache, isEmpty);
    });

    test('getUserNameById tolerates a malformed cache row', () async {
      backend.table('users').add({
        'id': 'odd',
        'team_id': FakeBackend.teamId,
        'full_name': 42,
        'role': 'x'
      });
      final service = await signedInService();
      await service.loadTeamMembers(FakeBackend.teamId);

      expect(service.getUserNameById('odd'), 'Team Member');
    });

    test('isCurrentUser compares with the session user', () async {
      final service = await signedInService();

      expect(service.isCurrentUser(FakeBackend.userId), isTrue);
      expect(service.isCurrentUser('user-2'), isFalse);
      expect(signedOutService().isCurrentUser(FakeBackend.userId), isFalse);
    });
  });

  group('createTeam', () {
    test('signs up the admin, picks a free code, and creates both rows',
        () async {
      final asked = stubTeamCodes({});
      final service = signedOutService();

      final result = await service.createTeam(
        teamName: 'Engines',
        adminName: 'Ada',
        adminEmail: 'new@example.com',
        password: 'secret!',
      );

      expect(result['success'], isTrue);
      expect(result['teamId'], asked.single);
      expect(backend.log.first, 'POST /auth/v1/signup');
      final team = backend.bodiesFor('POST', '/rest/v1/teams').single as Map;
      expect(team, {
        'name': 'Engines',
        'team_code': asked.single,
        'created_by': FakeBackend.userId,
        'admin_name': 'Ada',
        'admin_email': 'new@example.com',
      });
      final user = backend.bodiesFor('POST', '/rest/v1/users').single as Map;
      expect(user['role'], 'admin');
      expect(user['team_id'], result['teamData']['id']);
    });

    test('retries taken codes', () async {
      var calls = 0;
      backend.rpcs['check_team_code_exists'] = (_) => ++calls < 3;
      final service = signedOutService();

      final result = await service.createTeam(
          teamName: 'T', adminName: 'A', adminEmail: 'a@b.c', password: 'p');

      expect(result['success'], isTrue);
      expect(calls, 3);
    });

    test('gives up after three failed uniqueness checks', () async {
      final service = signedOutService();

      final result = await service.createTeam(
          teamName: 'T', adminName: 'A', adminEmail: 'a@b.c', password: 'p');

      expect(result, {
        'success': false,
        'error': 'Failed to create team. Please try again.',
      });
      expect(backend.bodiesFor('POST', '/rest/v1/teams'), isEmpty);
    });

    test('retries a duplicate code on insert', () async {
      stubTeamCodes({});
      var inserts = 0;
      final service = SupabaseService.withClient(fakeSupabaseClient(
        intercept: (r) {
          if (r.method == 'POST' && r.url.path.endsWith('/teams')) {
            inserts++;
            if (inserts == 1) {
              return http.Response(
                  '{"message":"duplicate key value violates unique constraint"}',
                  409);
            }
          }
          return null;
        },
      ));

      final result = await service.createTeam(
          teamName: 'T', adminName: 'A', adminEmail: 'a@b.c', password: 'p');

      expect(result['success'], isTrue);
      expect(inserts, 2);
    });

    test('fails after three duplicate inserts or an empty insert', () async {
      stubTeamCodes({});
      final duplicates = SupabaseService.withClient(fakeSupabaseClient(
        intercept: (r) => r.method == 'POST' && r.url.path.endsWith('/teams')
            ? http.Response('{"message":"duplicate"}', 409)
            : null,
      ));
      expect(
        (await duplicates.createTeam(
            teamName: 'T',
            adminName: 'A',
            adminEmail: 'a@b.c',
            password: 'p'))['success'],
        isFalse,
      );

      final otherError = SupabaseService.withClient(fakeSupabaseClient(
        intercept: (r) => r.method == 'POST' && r.url.path.endsWith('/teams')
            ? http.Response('{"message":"permission denied"}', 403)
            : null,
      ));
      expect(
        (await otherError.createTeam(
            teamName: 'T',
            adminName: 'A',
            adminEmail: 'a@b.c',
            password: 'p'))['success'],
        isFalse,
      );
      expect(backend.bodiesFor('POST', '/rest/v1/users'), isEmpty);
    });

    test('fails when sign-up returns no user', () async {
      stubTeamCodes({});
      final noUser = SupabaseService.withClient(fakeSupabaseClient(
        intercept: (r) =>
            r.url.path.endsWith('/signup') ? http.Response('{}', 200) : null,
      ));
      expect(
        (await noUser.createTeam(
            teamName: 'T',
            adminName: 'A',
            adminEmail: 'a@b.c',
            password: 'p'))['success'],
        isFalse,
      );
      expect(backend.bodiesFor('POST', '/rest/v1/teams'), isEmpty);
    });

    test('fails when sign-up is rejected', () async {
      backend.authFailures['/signup'] = 422;
      final service = signedOutService();

      final result = await service.createTeam(
          teamName: 'T', adminName: 'A', adminEmail: 'a@b.c', password: 'p');

      expect(result['success'], isFalse);
    });
  });

  group('joinTeam', () {
    test('signs up a member of an existing team', () async {
      stubTeamCodes({'ABC123'});
      final service = signedOutService();

      final result = await service.joinTeam(
        teamId: 'ABC123',
        fullName: 'Grace',
        email: 'grace@example.com',
        password: 'pw',
      );

      expect(result, {'success': true, 'teamId': 'ABC123'});
      expect(backend.bodiesFor('POST', '/rest/v1/users').single, {
        'id': FakeBackend.userId,
        'full_name': 'Grace',
        'email': 'grace@example.com',
        'team_id': FakeBackend.teamId,
        'role': 'member',
      });
    });

    test('refuses unknown teams before signing up', () async {
      stubTeamCodes({});
      final service = signedOutService();

      final result = await service.joinTeam(
          teamId: 'NOPE00', fullName: 'G', email: 'g@x.y', password: 'p');

      expect(result, {'success': false, 'error': 'Team not found'});
      expect(backend.log, isNot(contains('POST /auth/v1/signup')));
    });

    test('refuses a code the RPC knows but the table does not', () async {
      stubTeamCodes({'GHOST1'});
      final service = signedOutService();

      final result = await service.joinTeam(
          teamId: 'GHOST1', fullName: 'G', email: 'g@x.y', password: 'p');

      expect(result['error'], 'Team not found');
    });

    test('reports a sign-up that returns no user', () async {
      stubTeamCodes({'ABC123'});
      final service = SupabaseService.withClient(fakeSupabaseClient(
        intercept: (r) =>
            r.url.path.endsWith('/signup') ? http.Response('{}', 200) : null,
      ));

      final result = await service.joinTeam(
          teamId: 'ABC123', fullName: 'G', email: 'g@x.y', password: 'p');

      expect(result['success'], isFalse);
      expect(result['error'], contains('Failed to create user'));
    });

    test('reports sign-up failures', () async {
      stubTeamCodes({'ABC123'});
      backend.authFailures['/signup'] = 400;
      final service = signedOutService();

      final result = await service.joinTeam(
          teamId: 'ABC123', fullName: 'G', email: 'g@x.y', password: 'p');

      expect(result['success'], isFalse);
      expect(backend.bodiesFor('POST', '/rest/v1/users'), isEmpty);
    });
  });

  group('Google team setup', () {
    test('joinTeamWithGoogle creates a member profile with the token',
        () async {
      stubTeamCodes({'ABC123'});
      final service = await signedInService();

      final result = await service.joinTeamWithGoogle(
        email: FakeBackend.userEmail.toUpperCase(),
        teamCode: 'ABC123',
        fullName: 'Ada',
        googleRefreshToken: 'g-token',
      );

      expect(result, {'success': true, 'teamCode': 'ABC123'});
      final body = backend.bodiesFor('POST', '/rest/v1/users').single as Map;
      expect(body['email'], FakeBackend.userEmail);
      expect(body['role'], 'member');
      expect(body['google_refresh_token'], 'g-token');
    });

    test('joinTeamWithGoogle checks the session, email, and team', () async {
      stubTeamCodes({'GHOST1'});
      expect(
        (await signedOutService().joinTeamWithGoogle(
            email: 'a', teamCode: 'ABC123', fullName: 'A'))['error'],
        'User not authenticated',
      );

      final service = await signedInService();
      expect(
        (await service.joinTeamWithGoogle(
            email: 'other@example.com',
            teamCode: 'ABC123',
            fullName: 'A'))['error'],
        'Email mismatch for authenticated user',
      );
      expect(
        (await service.joinTeamWithGoogle(
            email: FakeBackend.userEmail,
            teamCode: 'NOPE00',
            fullName: 'A'))['error'],
        'Team not found',
      );
      expect(
        (await service.joinTeamWithGoogle(
            email: FakeBackend.userEmail,
            teamCode: 'GHOST1',
            fullName: 'A'))['error'],
        'Team not found',
      );

      backend.rpcs.remove('check_team_code_exists');
      expect(
        (await service.joinTeamWithGoogle(
            email: FakeBackend.userEmail,
            teamCode: 'ABC123',
            fullName: 'A'))['success'],
        isFalse,
      );
    });

    test('createTeamWithGoogle creates the team and an admin profile',
        () async {
      final asked = stubTeamCodes({});
      final service = await signedInService();

      final result = await service.createTeamWithGoogle(
        email: FakeBackend.userEmail,
        teamName: 'Engines',
        adminName: 'Ada',
        googleRefreshToken: 'g-token',
      );

      expect(result['success'], isTrue);
      expect(result['teamId'], asked.single);
      final team = backend.bodiesFor('POST', '/rest/v1/teams').single as Map;
      expect(team['admin_email'], FakeBackend.userEmail);
      final user = backend.bodiesFor('POST', '/rest/v1/users').single as Map;
      expect(user['role'], 'admin');
      expect(user['google_refresh_token'], 'g-token');
    });

    test('createTeamWithGoogle checks the session and email', () async {
      expect(
        (await signedOutService().createTeamWithGoogle(
            email: 'a', teamName: 'T', adminName: 'A'))['error'],
        'User not authenticated',
      );
      final service = await signedInService();
      expect(
        (await service.createTeamWithGoogle(
            email: 'other@example.com',
            teamName: 'T',
            adminName: 'A'))['error'],
        'Email mismatch for authenticated user',
      );
    });

    test('createTeamWithGoogle retries codes and duplicate inserts', () async {
      var checks = 0;
      backend.rpcs['check_team_code_exists'] = (_) => ++checks < 2;
      var inserts = 0;
      final service = await signedInService(
        intercept: (r) {
          if (r.method == 'POST' && r.url.path.endsWith('/teams')) {
            inserts++;
            if (inserts == 1) {
              return http.Response('{"message":"unique violation"}', 409);
            }
          }
          return null;
        },
      );

      final result = await service.createTeamWithGoogle(
          email: FakeBackend.userEmail, teamName: 'T', adminName: 'A');

      expect(result['success'], isTrue);
      expect(checks, 2);
      expect(inserts, 2);
    });

    test('createTeamWithGoogle fails cleanly', () async {
      final noRpc = await signedInService();
      expect(
        (await noRpc.createTeamWithGoogle(
            email: FakeBackend.userEmail,
            teamName: 'T',
            adminName: 'A'))['error'],
        'Failed to create team. Please try again.',
      );

      stubTeamCodes({});
      final duplicates = await signedInService(
        intercept: (r) => r.method == 'POST' && r.url.path.endsWith('/teams')
            ? http.Response('{"message":"duplicate"}', 409)
            : null,
      );
      expect(
        (await duplicates.createTeamWithGoogle(
            email: FakeBackend.userEmail,
            teamName: 'T',
            adminName: 'A'))['success'],
        isFalse,
      );

      final forbidden = await signedInService(
        intercept: (r) => r.method == 'POST' && r.url.path.endsWith('/teams')
            ? http.Response('{"message":"forbidden"}', 403)
            : null,
      );
      expect(
        (await forbidden.createTeamWithGoogle(
            email: FakeBackend.userEmail,
            teamName: 'T',
            adminName: 'A'))['success'],
        isFalse,
      );
    });
  });

  group('signInWithGoogle', () {
    late List<MethodCall> launches;

    setUp(() {
      launches = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          launches.add(call);
          return true;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/url_launcher'), null);
    });

    test('opens Google and reports an existing user once signed in', () async {
      final client = Supabase.instance.client;
      final service = SupabaseService.withClient(client);

      final pending = service.signInWithGoogle();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await client.auth.signInWithPassword(
          email: FakeBackend.userEmail, password: 'password');
      final result = await pending;

      expect(result, {
        'success': true,
        'isNewUser': false,
        'email': FakeBackend.userEmail,
      });
      expect(launches, isNotEmpty);
      final url = launches.first.arguments['url'] as String;
      expect(url, contains('/auth/v1/authorize'));
      expect(url, contains('provider=google'));
      expect(url, contains('access_type=offline'));
      expect(url,
          contains(Uri.encodeComponent('io.supabase.ellena://login-callback')));
    });

    test('flags new users who still need a team', () async {
      backend.table('users').removeWhere((u) => u['id'] == FakeBackend.userId);
      final client = Supabase.instance.client;
      final service = SupabaseService.withClient(client);

      final pending = service.signInWithGoogle();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await client.auth.signInWithPassword(
          email: FakeBackend.userEmail, password: 'password');
      final result = await pending;

      expect(result['isNewUser'], isTrue);
      expect(result['email'], FakeBackend.userEmail);
      expect(result.containsKey('googleRefreshToken'), isTrue);
    });

    test('reports a failed profile lookup', () async {
      final client = Supabase.instance.client;
      final service = SupabaseService.withClient(client);

      final pending = service.signInWithGoogle();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      backend.failures['users'] = 500;
      await client.auth.signInWithPassword(
          email: FakeBackend.userEmail, password: 'password');

      expect(await pending,
          {'success': false, 'error': 'Failed to process authentication'});
    });

    test('uses a configured redirect URL on mobile', () async {
      final saved = Map<String, String>.from(dotenv.env);
      addTearDown(() => dotenv.testLoad(mergeWith: saved));
      dotenv.testLoad(fileInput: 'OAUTH_REDIRECT_URL=ellena-dev://callback');
      final client = Supabase.instance.client;
      final service = SupabaseService.withClient(client);

      final pending = service.signInWithGoogle();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await client.auth.signInWithPassword(
          email: FakeBackend.userEmail, password: 'password');
      await pending;

      final url = launches.first.arguments['url'] as String;
      expect(url, contains(Uri.encodeComponent('ellena-dev://callback')));
    });

    test('reports a browser that will not open', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async => false,
      );
      final service = SupabaseService.withClient(Supabase.instance.client);

      expect(await service.signInWithGoogle(),
          {'success': false, 'error': 'Failed to launch Google sign-in'});
    });

    test('reports launch errors', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async => throw PlatformException(code: 'NO_BROWSER'),
      );
      final service = SupabaseService.withClient(Supabase.instance.client);

      final result = await service.signInWithGoogle();

      expect(result['success'], isFalse);
      expect(result['error'], contains('NO_BROWSER'));
    });
  });

  testWidgets('signInWithGoogle gives up after a minute without a session',
      (tester) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => true);
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final service = SupabaseService.withClient(Supabase.instance.client);
    Map<String, dynamic>? result;

    service.signInWithGoogle().then((value) => result = value);
    // Sign-in setup awaits SharedPreferences, whose cached future belongs to
    // the real zone; let it run so the 60 s timeout is armed on fake time.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 59));
    expect(result, isNull);
    await tester.pump(const Duration(seconds: 2));

    expect(result, {'success': false, 'error': 'Authentication timed out'});
  });

  group('profile', () {
    test('getCurrentUserProfile caches until forced', () async {
      final service = await signedInService();

      final first = await service.getCurrentUserProfile();
      backend.table('users').first['full_name'] = 'Countess';
      final cached = await service.getCurrentUserProfile();
      final fresh = await service.getCurrentUserProfile(forceRefresh: true);

      expect(first!['full_name'], 'Ada');
      expect(cached!['full_name'], 'Ada');
      expect(fresh!['full_name'], 'Countess');
      expect(backend.log.where((l) => l == 'GET /rest/v1/users'), hasLength(2));
    });

    test('getCurrentUserProfile falls back to the cache on errors', () async {
      final service = await signedInService();
      await service.getCurrentUserProfile();
      backend.failures['users'] = 500;

      final profile = await service.getCurrentUserProfile(forceRefresh: true);

      expect(profile!['full_name'], 'Ada');
    });

    test('getCurrentUserProfile is null without a profile row or session',
        () async {
      backend.table('users').clear();
      expect(await (await signedInService()).getCurrentUserProfile(), isNull);
      expect(await signedOutService().getCurrentUserProfile(), isNull);
    });

    test('updateUserProfile writes the row and merges the cache', () async {
      final service = await signedInService();
      await service.getCurrentUserProfile();

      final ok = await service.updateUserProfile({'full_name': 'Ada L.'});

      expect(ok, isTrue);
      expect(backend.bodiesFor('PATCH', '/rest/v1/users'), [
        {'full_name': 'Ada L.'}
      ]);
      final cached = await service.getCurrentUserProfile();
      expect(cached!['full_name'], 'Ada L.');
      expect(cached['email'], FakeBackend.userEmail);
    });

    test('updateUserProfile without a cache, session, or on error', () async {
      final service = await signedInService();
      expect(await service.updateUserProfile({'full_name': 'X'}), isTrue);
      expect(backend.table('users').first['full_name'], 'X');

      expect(await signedOutService().updateUserProfile({'a': 1}), isFalse);

      backend.failures['users'] = 500;
      expect(await service.updateUserProfile({'full_name': 'Y'}), isFalse);
    });

    test('signOut ends the session and clears caches', () async {
      final service = await signedInService();
      await service.getCurrentUserProfile();
      await service.loadTeamMembers(FakeBackend.teamId);

      await service.signOut();

      expect(service.currentUser, isNull);
      expect(service.teamMembersCache, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_profile'), isNull);
      expect(backend.log, contains('POST /auth/v1/logout'));
    });
  });

  group('verifyOTP', () {
    test('rejects a verification that returns no session', () async {
      final service = SupabaseService.withClient(fakeSupabaseClient(
        intercept: (r) => r.url.path.endsWith('/verify')
            ? http.Response(jsonEncode({'user': null}), 200)
            : null,
      ));

      final result =
          await service.verifyOTP(email: 'a@b.c', token: '1', type: 'signup');

      expect(result['success'], isFalse);
    });

    test('signup_create sets the password and creates the team', () async {
      final asked = stubTeamCodes({});
      final service = signedOutService();

      final result = await service.verifyOTP(
        email: 'new@example.com',
        token: ' 123456 ',
        type: 'signup_create',
        userData: {
          'password': 'secret',
          'teamName': 'Engines',
          'adminName': 'Ada',
        },
      );

      expect(result, {'success': true, 'teamId': asked.single});
      final verify = backend.bodiesFor('POST', '/auth/v1/verify').single as Map;
      expect(verify['token'], '123456');
      expect(verify['email'], 'new@example.com');
      expect(backend.bodiesFor('PUT', '/auth/v1/user').single,
          containsPair('password', 'secret'));
      expect(
          (backend.bodiesFor('POST', '/rest/v1/teams').single as Map)['name'],
          'Engines');
      final user = backend.bodiesFor('POST', '/rest/v1/users').single as Map;
      expect(user['role'], 'admin');
      expect(user['full_name'], 'Ada');
    });

    test('signup_create uses defaults and survives code-check errors',
        () async {
      final service = signedOutService();

      final result = await service.verifyOTP(
        email: 'new@example.com',
        token: '1',
        type: 'signup_create',
        userData: {'other': true},
      );

      expect(result['success'], isTrue);
      final team = backend.bodiesFor('POST', '/rest/v1/teams').single as Map;
      expect(team['name'], 'New Team');
      expect(team['admin_name'], '');
      expect(backend.bodiesFor('PUT', '/auth/v1/user'), isEmpty);
    });

    test('signup_create reports a failed team insert', () async {
      stubTeamCodes({});
      final empty = SupabaseService.withClient(fakeSupabaseClient(
        intercept: (r) => r.method == 'POST' && r.url.path.endsWith('/teams')
            ? http.Response('[]', 201)
            : null,
      ));
      final result = await empty.verifyOTP(
          email: 'a@b.c',
          token: '1',
          type: 'signup_create',
          userData: {'x': 1});
      expect(result['success'], isFalse);
      expect(result['error'], contains('Failed to create team'));
    });

    test('a failing password update does not block verification', () async {
      backend.authFailures['/user'] = 422;
      final service = signedOutService();

      final result = await service.verifyOTP(
        email: 'a@b.c',
        token: '1',
        type: 'signup',
        userData: {'password': 'weak'},
      );

      expect(result, {'success': true});
    });

    test('signup_join adds the member to the team', () async {
      final service = signedOutService();

      final result = await service.verifyOTP(
        email: 'grace@example.com',
        token: '1',
        type: 'signup_join',
        userData: {'teamId': 'ABC123', 'fullName': 'Grace'},
      );

      expect(result, {'success': true});
      final user = backend.bodiesFor('POST', '/rest/v1/users').single as Map;
      expect(user['team_id'], FakeBackend.teamId);
      expect(user['role'], 'member');
      expect(user['full_name'], 'Grace');
    });

    test('signup_join reports unknown teams and insert errors', () async {
      final service = signedOutService();
      expect(
        await service.verifyOTP(
            email: 'g@x.y',
            token: '1',
            type: 'signup_join',
            userData: {'teamId': 'NOPE00'}),
        {'success': false, 'error': 'Team not found'},
      );

      final failing = SupabaseService.withClient(fakeSupabaseClient(
        intercept: (r) => r.method == 'POST' && r.url.path.endsWith('/users')
            ? http.Response('{"message":"conflict"}', 409)
            : null,
      ));
      expect(
        (await failing.verifyOTP(
            email: 'g@x.y',
            token: '1',
            type: 'signup_join',
            userData: {'teamId': 'ABC123'}))['success'],
        isFalse,
      );
    });

    test('reset_password and plain codes just succeed', () async {
      final service = signedOutService();

      expect(
          await service.verifyOTP(
              email: 'a@b.c', token: '1', type: 'reset_password'),
          {'success': true});
      expect(
          await service.verifyOTP(
              email: 'a@b.c', token: '1', type: 'signup_create'),
          {'success': true});
      expect(backend.bodiesFor('POST', '/rest/v1/teams'), isEmpty);
    });

    test('reports an invalid code', () async {
      backend.authFailures['/verify'] = 403;
      final service = signedOutService();

      final result =
          await service.verifyOTP(email: 'a@b.c', token: '0', type: 'signup');

      expect(result['success'], isFalse);
    });
  });

  group('resendVerificationEmail', () {
    test('resends sign-up codes for every sign-up flavour', () async {
      final service = signedOutService();

      for (final type in ['signup', 'signup_create', 'signup_join']) {
        expect(await service.resendVerificationEmail('a@b.c', type: type),
            {'success': true});
      }

      final bodies = backend.bodiesFor('POST', '/auth/v1/resend');
      expect(bodies, hasLength(3));
      for (final body in bodies) {
        expect(body, containsPair('type', 'signup'));
        expect(body, containsPair('email', 'a@b.c'));
      }
    });

    test('resends email-change codes', () async {
      final service = signedOutService();

      await service.resendVerificationEmail('a@b.c', type: 'email_change');

      expect(backend.bodiesFor('POST', '/auth/v1/resend').single,
          containsPair('type', 'email_change'));
    });

    test('sends a password reset email for reset_password', () async {
      final service = signedOutService();

      expect(
          await service.resendVerificationEmail('a@b.c',
              type: 'reset_password'),
          {'success': true});
      expect(backend.bodiesFor('POST', '/auth/v1/recover').single,
          containsPair('email', 'a@b.c'));
    });

    test('rejects unknown types and reports failures', () async {
      final service = signedOutService();
      expect(await service.resendVerificationEmail('a@b.c', type: 'magic'),
          {'success': false, 'error': 'Invalid OTP type: magic'});

      backend.authFailures['/resend'] = 429;
      expect(
          (await service.resendVerificationEmail('a@b.c'))['success'], isFalse);
    });
  });

  group('signed-out guards', () {
    test('every action refuses without a session', () async {
      final service = signedOutService();
      const notAuthed = {'success': false, 'error': 'User not authenticated'};

      expect(await service.switchTeam('t'), notAuthed);
      expect(await service.createTask(title: 't'), notAuthed);
      expect(
          await service.updateTaskStatus(taskId: 't', status: 's'), notAuthed);
      expect(await service.updateTaskTicket(taskId: 't'), notAuthed);
      expect(await service.updateTaskApproval(taskId: 't', approvalStatus: 'a'),
          notAuthed);
      expect(
          await service.addTaskComment(taskId: 't', content: 'c'), notAuthed);
      expect(await service.deleteTask('t'), notAuthed);
      expect(
          await service.createTicket(title: 't', priority: 'p', category: 'c'),
          notAuthed);
      expect(await service.syncTicketToGithub('t'), notAuthed);
      expect(await service.updateTicketStatus(ticketId: 't', status: 's'),
          notAuthed);
      expect(await service.updateTicketPriority(ticketId: 't', priority: 'p'),
          notAuthed);
      expect(
          await service.updateTicketApproval(
              ticketId: 't', approvalStatus: 'a'),
          notAuthed);
      expect(await service.addTicketComment(ticketId: 't', content: 'c'),
          notAuthed);
      expect(await service.deleteTicket('t'), notAuthed);
      expect(await service.assignTicket(ticketId: 't', userId: 'u'), notAuthed);
      expect(
          await service.createMeeting(title: 't', meetingDate: DateTime(2026)),
          notAuthed);
      expect(
          await service.updateMeeting(
              meetingId: 'm', title: 't', meetingDate: DateTime(2026)),
          notAuthed);
      expect(await service.deleteMeeting('m'), notAuthed);

      expect(await service.getTasks(), isEmpty);
      expect(await service.getTickets(), isEmpty);
      expect(await service.getMeetings(), isEmpty);
      expect(await service.getTeamMembers('ABC123'), isEmpty);
      expect(await service.getTaskDetails('t'), isNull);
      expect(await service.getTicketDetails('t'), isNull);
      expect(await service.getMeetingDetails('m'), isNull);
      expect(backend.log, isEmpty);
    });

    test('team-scoped actions refuse users without a team', () async {
      backend.table('users').first['team_id'] = null;
      final service = await signedInService();

      expect(await service.getMeetings(), isEmpty);
      expect(
          (await service.createMeeting(
              title: 't', meetingDate: DateTime(2026)))['error'],
          'User not associated with a team');
    });
  });
}
