import 'package:ell_ena/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/test_harness.dart';

/// Starts Supabase with a session already restored, as on a warm app start,
/// before the [SupabaseService] singleton initialises.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    backend.seedTeam();
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
    await Supabase.instance.client.auth.signInWithPassword(
      email: FakeBackend.userEmail,
      password: 'password',
    );
    backend.log.clear();
    await setUpFakeSupabase();
  });

  test('loads the profile and team members of a restored session', () {
    final service = SupabaseService();

    expect(service.isInitialized, isTrue);
    expect(service.currentUser?.email, FakeBackend.userEmail);
    expect(service.client, same(Supabase.instance.client));
    expect(service.teamMembersCache.map((m) => m['full_name']),
        unorderedEquals(['Ada', 'Bob']));
    expect(service.getUserNameById('user-2'), 'Bob');
    expect(backend.log, ['GET /rest/v1/users', 'GET /rest/v1/users']);
  });

  test('a second initialize does nothing', () async {
    backend.log.clear();

    await SupabaseService().initialize();

    expect(backend.log, isEmpty);
  });

  test('the profile read at start-up is cached on disk', () async {
    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getString('user_profile'), contains(FakeBackend.userEmail));
  });
}
