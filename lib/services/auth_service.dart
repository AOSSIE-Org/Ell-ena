import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles authentication, user profile, OTP, and Google OAuth.
class AuthService {
  final SupabaseClient _client;

  Map<String, dynamic>? _profileCache;

  AuthService(this._client);

  User? get currentUser => _client.auth.currentUser;
  Map<String, dynamic>? get profileCache => _profileCache;

  // ── Profile Cache ──────────────────────────────────────────────────────────

  Future<void> loadCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user_profile');
      if (raw != null) _profileCache = json.decode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error loading cached profile: $e');
    }
  }

  Future<void> _saveProfile(Map<String, dynamic> profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile', json.encode(profile));
      _profileCache = profile;
    } catch (e) {
      debugPrint('Error saving profile cache: $e');
    }
  }

  Future<void> clearCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_profile');
      _profileCache = null;
    } catch (e) {
      debugPrint('Error clearing profile cache: $e');
    }
  }

  // ── Profile ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getCurrentUserProfile(
      {bool forceRefresh = false}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;
      if (!forceRefresh && _profileCache != null) return _profileCache;

      final response = await _client
          .from('users')
          .select('*, teams(name, team_code)')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) await _saveProfile(response);
      return response;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return _profileCache;
    }
  }

  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      await _client.from('users').update(data).eq('id', user.id);

      if (_profileCache != null) {
        final updated = Map<String, dynamic>.from(_profileCache!);
        data.forEach((k, v) => updated[k] = v);
        await _saveProfile(updated);
      }
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _client.auth.signOut();
    await clearCachedProfile();
  }

  // ── Google OAuth ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      final redirectUrl = dotenv.env['OAUTH_REDIRECT_URL'] ??
          'io.supabase.ellena://login-callback';

      final completer = Completer<Map<String, dynamic>>();
      StreamSubscription<AuthState>? sub;

      sub = _client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.signedIn && data.session != null) {
          _processOAuthUser(data.session!.user, data.session!).then((result) {
            sub?.cancel();
            if (!completer.isCompleted) completer.complete(result);
          });
        }
      });

      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
        queryParams: const {'access_type': 'offline', 'prompt': 'consent'},
      );

      if (!launched) {
        await sub.cancel();
        return {'success': false, 'error': 'Failed to launch Google sign-in'};
      }

      return await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          sub?.cancel();
          return {'success': false, 'error': 'Authentication timed out'};
        },
      );
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _processOAuthUser(
      User user, Session session) async {
    try {
      final existing = await _client
          .from('users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existing != null) {
        return {'success': true, 'isNewUser': false, 'email': user.email};
      }
      return {
        'success': true,
        'isNewUser': true,
        'email': user.email,
        'googleRefreshToken': session.providerRefreshToken,
      };
    } catch (e) {
      debugPrint('Error processing OAuth user: $e');
      return {'success': false, 'error': 'Failed to process authentication'};
    }
  }

  Future<Map<String, dynamic>> joinTeamWithGoogle({
    required String email,
    required String teamCode,
    required String fullName,
    String? googleRefreshToken,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final authedEmail = user.email;
      if (authedEmail == null ||
          authedEmail.toLowerCase() != email.toLowerCase()) {
        return {'success': false, 'error': 'Email mismatch for authenticated user'};
      }

      final exists =
          await _client.rpc('check_team_code_exists', params: {'code': teamCode});
      if (exists != true) return {'success': false, 'error': 'Team not found'};

      final teamResponse = await _client
          .from('teams')
          .select('id')
          .eq('team_code', teamCode)
          .limit(1);
      if (teamResponse.isEmpty) return {'success': false, 'error': 'Team not found'};

      await _client.from('users').insert({
        'id': user.id,
        'full_name': fullName,
        'email': authedEmail,
        'team_id': teamResponse[0]['id'],
        'role': 'member',
        'google_refresh_token': googleRefreshToken,
      });

      return {'success': true, 'teamCode': teamCode};
    } catch (e) {
      debugPrint('Error joining team with Google: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createTeamWithGoogle({
    required String email,
    required String teamName,
    required String adminName,
    String? googleRefreshToken,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final authedEmail = user.email;
      if (authedEmail == null ||
          authedEmail.toLowerCase() != email.toLowerCase()) {
        return {'success': false, 'error': 'Email mismatch for authenticated user'};
      }

      final teamCode = await _uniqueTeamCode();
      if (teamCode == null) {
        return {'success': false, 'error': 'Unable to generate unique team code'};
      }

      Map<String, dynamic>? teamResponse;
      String code = teamCode;
      for (int i = 0; i < 3 && teamResponse == null; i++) {
        try {
          final res = await _client.from('teams').insert({
            'name': teamName,
            'team_code': code,
            'created_by': user.id,
            'admin_name': adminName,
            'admin_email': authedEmail,
          }).select();
          teamResponse = res.isNotEmpty ? res.first : null;
        } catch (e) {
          if (e.toString().contains('duplicate') ||
              e.toString().contains('unique')) {
            code = _randomCode();
          } else {
            rethrow;
          }
        }
      }

      if (teamResponse == null) {
        throw Exception('Failed to create team after multiple attempts');
      }

      await _client.from('users').insert({
        'id': user.id,
        'full_name': adminName,
        'email': authedEmail,
        'team_id': teamResponse['id'],
        'role': 'admin',
        'google_refresh_token': googleRefreshToken,
      });

      return {'success': true, 'teamId': code, 'teamData': teamResponse};
    } catch (e) {
      debugPrint('Error creating team with Google: $e');
      return {'success': false, 'error': 'Failed to create team. Please try again.'};
    }
  }

  // ── OTP ────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> verifyOTP({
    required String email,
    required String token,
    required String type,
    Map<String, dynamic> userData = const {},
  }) async {
    try {
      final response = await _client.auth.verifyOTP(
        token: token.trim(),
        type: OtpType.email,
        email: email,
      );

      if (response.user == null) {
        return {'success': false, 'error': 'Invalid verification code'};
      }

      await Future.delayed(const Duration(milliseconds: 500));

      final password = userData['password'] as String?;
      if (password != null && password.isNotEmpty) {
        try {
          await _client.auth.updateUser(UserAttributes(password: password));
        } catch (e) {
          debugPrint('Error setting password: $e');
        }
      }

      if (type == 'signup_create' && userData.isNotEmpty) {
        return await _createTeamAfterOTP(response.user!, email, userData);
      } else if (type == 'signup_join' && userData.isNotEmpty) {
        return await _joinTeamAfterOTP(response.user!, userData);
      } else if (type == 'reset_password') {
        return {'success': true};
      }

      return {'success': true};
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _createTeamAfterOTP(
      User user, String email, Map<String, dynamic> userData) async {
    try {
      final teamCode = await _uniqueTeamCode();
      if (teamCode == null) {
        return {'success': false, 'error': 'Failed to generate team code'};
      }

      final res = await _client.from('teams').insert({
        'name': userData['teamName'] ?? 'New Team',
        'team_code': teamCode,
        'created_by': user.id,
        'admin_name': userData['adminName'] ?? '',
        'admin_email': email,
      }).select();

      if (res.isEmpty) throw Exception('Failed to create team');

      await _client.from('users').insert({
        'id': user.id,
        'full_name': userData['adminName'] ?? '',
        'email': email,
        'team_id': res.first['id'],
        'role': 'admin',
      });

      return {'success': true, 'teamId': teamCode};
    } catch (e) {
      debugPrint('Error creating team after OTP: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _joinTeamAfterOTP(
      User user, Map<String, dynamic> userData) async {
    try {
      final teamRes = await _client
          .from('teams')
          .select('id')
          .eq('team_code', userData['teamId'])
          .limit(1);

      if (teamRes.isEmpty) return {'success': false, 'error': 'Team not found'};

      await _client.from('users').insert({
        'id': user.id,
        'full_name': userData['fullName'] ?? '',
        'email': user.email,
        'team_id': teamRes[0]['id'],
        'role': 'member',
      });

      return {'success': true};
    } catch (e) {
      debugPrint('Error joining team after OTP: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resendVerificationEmail(String email,
      {String type = 'signup'}) async {
    try {
      switch (type) {
        case 'reset_password':
          await _client.auth.resetPasswordForEmail(email);
          return {'success': true};
        case 'email_change':
          await _client.auth.resend(type: OtpType.emailChange, email: email);
          return {'success': true};
        case 'signup':
        case 'signup_create':
        case 'signup_join':
          await _client.auth.resend(type: OtpType.signup, email: email);
          return {'success': true};
        default:
          return {'success': false, 'error': 'Invalid OTP type: $type'};
      }
    } catch (e) {
      debugPrint('Error resending verification email: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _randomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<String?> _uniqueTeamCode() async {
    for (int i = 0; i < 10; i++) {
      final code = _randomCode();
      try {
        final res =
            await _client.rpc('check_team_code_exists', params: {'code': code});
        if (res == false) return code;
      } catch (e) {
        debugPrint('Error checking team code: $e');
        if (i >= 2) return null;
      }
    }
    return null;
  }
}
