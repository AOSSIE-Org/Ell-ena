import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// Handles team CRUD, member caching, and user info lookups.
class TeamService {
  final SupabaseClient _client;
  final AuthService _authService;

  List<Map<String, dynamic>> _membersCache = [];
  String? _cachedTeamId;

  TeamService(this._client, this._authService);

  List<Map<String, dynamic>> get membersCache => _membersCache;

  void clearCache() {
    _membersCache = [];
    _cachedTeamId = null;
  }

  // ── Member Cache ───────────────────────────────────────────────────────────

  Future<void> loadTeamMembers(String teamIdOrCode) async {
    if (_cachedTeamId == teamIdOrCode && _membersCache.isNotEmpty) return;
    _membersCache = await getTeamMembers(teamIdOrCode);
    _cachedTeamId = teamIdOrCode;
    debugPrint('Team members loaded: ${_membersCache.length}');
  }

  Future<void> loadTeamMembersIfLoggedIn() async {
    try {
      if (_client.auth.currentUser != null) {
        final profile = await _authService.getCurrentUserProfile();
        if (profile?['team_id'] != null) {
          await loadTeamMembers(profile!['team_id']);
        }
      }
    } catch (e) {
      debugPrint('Error loading team members on init: $e');
    }
  }

  String getUserNameById(String userId) {
    try {
      return _membersCache.firstWhere(
        (m) => m['id'] == userId,
        orElse: () => {'full_name': 'Team Member'},
      )['full_name'];
    } catch (_) {
      return 'Team Member';
    }
  }

  bool isCurrentUser(String userId) =>
      _client.auth.currentUser?.id == userId;

  /// Resolves {id, full_name, role} — cache-first, then DB.
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final cached = _membersCache.firstWhere(
        (m) => m['id'] == userId,
        orElse: () => {},
      );
      if (cached.isNotEmpty) {
        return {'id': cached['id'], 'full_name': cached['full_name'], 'role': cached['role']};
      }

      final res = await _client
          .from('users')
          .select('id, full_name, role')
          .eq('id', userId)
          .limit(1);

      return res.isNotEmpty
          ? {'id': res[0]['id'], 'full_name': res[0]['full_name'], 'role': res[0]['role']}
          : null;
    } catch (e) {
      debugPrint('Error getting user info: $e');
      return null;
    }
  }

  // ── Team Queries ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTeamMembers(String teamIdOrCode) async {
    try {
      if (_client.auth.currentUser == null) return [];

      String teamUuid;
      final uuidRe = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          caseSensitive: false);

      if (uuidRe.hasMatch(teamIdOrCode)) {
        teamUuid = teamIdOrCode;
      } else {
        final res = await _client
            .from('teams')
            .select('id')
            .eq('team_code', teamIdOrCode)
            .limit(1);
        if (res.isEmpty) return [];
        teamUuid = res[0]['id'];
      }

      final res = await _client
          .from('users')
          .select('*')
          .eq('team_id', teamUuid)
          .order('role', ascending: false);

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error getting team members: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getUserTeams(String email) async {
    try {
      final res =
          await _client.from('users').select('team_id, teams(*)').eq('email', email);

      if (res.isEmpty) return {'success': true, 'teams': []};

      final teams = <Map<String, dynamic>>[];
      for (final record in res) {
        if (record['teams'] != null) {
          teams.add({
            'id': record['team_id'],
            'name': record['teams']['name'],
            'team_code': record['teams']['team_code'],
          });
        }
      }
      return {'success': true, 'teams': teams};
    } catch (e) {
      debugPrint('Error getting user teams: $e');
      return {'success': false, 'error': e.toString(), 'teams': []};
    }
  }

  Future<Map<String, dynamic>> switchTeam(String teamId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final check = await _client
          .from('users')
          .select('id')
          .eq('id', user.id)
          .eq('team_id', teamId)
          .limit(1);
      if (check.isEmpty) {
        return {'success': false, 'error': 'User is not a member of this team'};
      }

      final teamRes =
          await _client.from('teams').select('*').eq('id', teamId).limit(1);
      if (teamRes.isEmpty) return {'success': false, 'error': 'Team not found'};

      final cache = _authService.profileCache;
      if (cache != null) {
        cache['team_id'] = teamId;
        cache['teams'] = teamRes[0];
        await _authService.updateUserProfile({'team_id': teamId});
      }

      clearCache();
      await loadTeamMembers(teamId);

      return {'success': true, 'team': teamRes[0]};
    } catch (e) {
      debugPrint('Error switching team: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> teamExists(String teamId) async {
    try {
      final res =
          await _client.rpc('check_team_code_exists', params: {'code': teamId});
      return res == true;
    } catch (e) {
      debugPrint('Error checking team: $e');
      return false;
    }
  }

  // ── Team Creation / Join ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> createTeam({
    required String teamName,
    required String adminName,
    required String adminEmail,
    required String password,
  }) async {
    try {
      final authRes = await _client.auth.signUp(email: adminEmail, password: password);
      if (authRes.user == null) throw Exception('Failed to create user');
      final userId = authRes.user!.id;

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
            'created_by': userId,
            'admin_name': adminName,
            'admin_email': adminEmail,
          }).select();
          teamResponse = res.isNotEmpty ? res.first : null;
        } catch (e) {
          if (e.toString().contains('duplicate') || e.toString().contains('unique')) {
            code = _randomCode();
            debugPrint('Duplicate team code detected, retrying with new code...');
          } else {
            rethrow;
          }
        }
      }

      if (teamResponse == null) {
        throw Exception('Failed to create team after multiple attempts');
      }

      await _client.from('users').insert({
        'id': userId,
        'full_name': adminName,
        'email': adminEmail,
        'team_id': teamResponse['id'],
        'role': 'admin',
      });

      return {'success': true, 'teamId': code, 'teamData': teamResponse};
    } catch (e) {
      debugPrint('Error creating team: $e');
      return {'success': false, 'error': 'Failed to create team. Please try again.'};
    }
  }

  Future<Map<String, dynamic>> joinTeam({
    required String teamId,
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final exists =
          await _client.rpc('check_team_code_exists', params: {'code': teamId});
      if (exists != true) return {'success': false, 'error': 'Team not found'};

      final teamRes = await _client
          .from('teams')
          .select('id')
          .eq('team_code', teamId)
          .limit(1);
      if (teamRes.isEmpty) return {'success': false, 'error': 'Team not found'};

      final authRes = await _client.auth.signUp(email: email, password: password);
      if (authRes.user == null) throw Exception('Failed to create user');

      await _client.from('users').insert({
        'id': authRes.user!.id,
        'full_name': fullName,
        'email': email,
        'team_id': teamRes[0]['id'],
        'role': 'member',
      });

      return {'success': true, 'teamId': teamId};
    } catch (e) {
      debugPrint('Error joining team: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String generateTeamId() => _randomCode();

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
