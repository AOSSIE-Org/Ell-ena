import 'package:ell_ena/services/supabase_service.dart';

import '../support/test_harness.dart';

/// A fresh [SupabaseService] (empty caches) whose client is signed in as
/// [FakeBackend.userEmail]. Clears the backend log afterwards.
Future<SupabaseService> signedInService({Intercept? intercept}) async {
  final client = fakeSupabaseClient(intercept: intercept);
  await client.auth.signInWithPassword(
    email: FakeBackend.userEmail,
    password: 'password',
  );
  backend.log.clear();
  backend.sent.clear();
  return SupabaseService.withClient(client);
}

/// A fresh [SupabaseService] with no session.
SupabaseService signedOutService() =>
    SupabaseService.withClient(fakeSupabaseClient());

/// The non-GET requests sent to [path], as `METHOD /path` keys.
List<String> writesTo(String path) => [
      for (final entry in backend.sent)
        if (entry.key.endsWith(' $path')) entry.key,
    ];
