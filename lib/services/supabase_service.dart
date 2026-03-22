import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  late final SupabaseClient _client;
  bool _isInitialized = false;
  bool _disposed = false;

  List<Map<String, dynamic>> _teamMembersCache = [];
  String? _currentTeamId;

  Map<String, dynamic>? _userProfileCache;

  final _tasksStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final _ticketsStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final _meetingsStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  Stream<List<Map<String, dynamic>>> get tasksStream =>
      _tasksStreamController.stream;
  Stream<List<Map<String, dynamic>>> get ticketsStream =>
      _ticketsStreamController.stream;
  Stream<List<Map<String, dynamic>>> get meetingsStream =>
      _meetingsStreamController.stream;

  // Centralized user embed projection constant.
  // All joins that need user info use this single constant so future
  // schema changes only require updating one place.
  static const String _userEmbed = 'id, full_name, role';

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  bool get isInitialized => _isInitialized;

  List<Map<String, dynamic>> get teamMembersCache => _teamMembersCache;

  User? get currentUser => _isInitialized ? _client.auth.currentUser : null;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await dotenv.load().catchError((e) {
        debugPrint('Error loading .env file: $e');
      });

      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

      if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
        throw Exception(
            'Missing required Supabase configuration. Please check your .env file.');
      }

      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      _client = Supabase.instance.client;
      _isInitialized = true;

      await _loadCachedUserProfile();
      await _loadTeamMembersIfLoggedIn();
    } catch (e) {
      debugPrint('Error initializing Supabase: $e');
      rethrow;
    }
  }

  Future<void> _loadCachedUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedProfile = prefs.getString('user_profile');
      if (cachedProfile != null) {
        _userProfileCache = json.decode(cachedProfile) as Map<String, dynamic>;
        debugPrint('Loaded user profile from cache');
      }
    } catch (e) {
      debugPrint('Error loading cached user profile: $e');
    }
  }

  Future<void> _saveUserProfileToCache(Map<String, dynamic> profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile', json.encode(profile));
      _userProfileCache = profile;
      debugPrint('Saved user profile to cache');
    } catch (e) {
      debugPrint('Error saving user profile to cache: $e');
    }
  }

  Future<void> _clearCachedUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_profile');
      _userProfileCache = null;
      debugPrint('Cleared user profile cache');
    } catch (e) {
      debugPrint('Error clearing cached user profile: $e');
    }
  }

  Future<Map<String, dynamic>> getUserTeams(String email) async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final response = await _client
          .from('users')
          .select('team_id, teams(*)')
          .eq('email', email);

      if (response.isEmpty) {
        return {'success': true, 'teams': []};
      }

      final List<Map<String, dynamic>> teams = [];
      for (var record in response) {
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
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final user = _client.auth.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      final checkResponse = await _client
          .from('users')
          .select('id, team_id')
          .eq('id', user.id)
          .eq('team_id', teamId)
          .limit(1);

      if (checkResponse.isEmpty) {
        return {'success': false, 'error': 'User is not a member of this team'};
      }

      final teamResponse =
          await _client.from('teams').select('*').eq('id', teamId).limit(1);

      if (teamResponse.isEmpty) {
        return {'success': false, 'error': 'Team not found'};
      }

      if (_userProfileCache != null) {
        _userProfileCache!['team_id'] = teamId;
        _userProfileCache!['teams'] = teamResponse[0];
        await _saveUserProfileToCache(_userProfileCache!);
      }

      _teamMembersCache = [];
      _currentTeamId = teamId;
      await loadTeamMembers(teamId);

      return {'success': true, 'team': teamResponse[0]};
    } catch (e) {
      debugPrint('Error switching team: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> _loadTeamMembersIfLoggedIn() async {
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        final userProfile = await getCurrentUserProfile();
        if (userProfile != null && userProfile['team_id'] != null) {
          await loadTeamMembers(userProfile['team_id']);
        }
      }
    } catch (e) {
      debugPrint('Error loading team members on init: $e');
    }
  }

  Future<void> loadTeamMembers(String teamIdOrCode) async {
    try {
      if (!_isInitialized) return;
      if (_currentTeamId == teamIdOrCode && _teamMembersCache.isNotEmpty) return;

      final members = await getTeamMembers(teamIdOrCode);
      _teamMembersCache = members;
      _currentTeamId = teamIdOrCode;
      debugPrint('Team members loaded: ${_teamMembersCache.length}');
    } catch (e) {
      debugPrint('Error loading team members: $e');
    }
  }

  String getUserNameById(String userId) {
    try {
      final member = _teamMembersCache.firstWhere(
        (member) => member['id'] == userId,
        orElse: () => {'full_name': 'Team Member'},
      );
      return member['full_name'];
    } catch (e) {
      return 'Team Member';
    }
  }

  bool isCurrentUser(String userId) {
    final currentUserId = _client.auth.currentUser?.id;
    return currentUserId != null && currentUserId == userId;
  }

  SupabaseClient get client => _client;

  String generateTeamId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  Future<Map<String, dynamic>> createTeam({
    required String teamName,
    required String adminName,
    required String adminEmail,
    required String password,
  }) async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final authResponse = await _client.auth.signUp(
        email: adminEmail,
        password: password,
      );

      if (authResponse.user == null) throw Exception('Failed to create user');

      final userId = authResponse.user!.id;
      String teamId;
      bool isUnique = false;
      int attempts = 0;

      do {
        teamId = generateTeamId();
        attempts++;
        try {
          final response = await _client.rpc(
            'check_team_code_exists',
            params: {'code': teamId},
          );
          isUnique = response == false;
        } catch (e) {
          debugPrint('Error checking team code: $e');
          if (attempts >= 3) {
            throw Exception(
                'Unable to verify team code uniqueness. Please try again.');
          }
        }
      } while (!isUnique && attempts < 10);

      Map<String, dynamic>? teamResponse;
      int insertAttempts = 0;

      while (teamResponse == null && insertAttempts < 3) {
        try {
          final teamInsertResponse = await _client.from('teams').insert({
            'name': teamName,
            'team_code': teamId,
            'created_by': userId,
            'admin_name': adminName,
            'admin_email': adminEmail,
          }).select();
          teamResponse =
              teamInsertResponse.isNotEmpty ? teamInsertResponse.first : null;
        } catch (e) {
          if (e.toString().contains('duplicate') ||
              e.toString().contains('unique')) {
            teamId = generateTeamId();
            insertAttempts++;
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

      return {'success': true, 'teamId': teamId, 'teamData': teamResponse};
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
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final teamExistsResponse = await _client.rpc(
        'check_team_code_exists',
        params: {'code': teamId},
      );

      if (teamExistsResponse != true) {
        return {'success': false, 'error': 'Team not found'};
      }

      final teamResponse = await _client
          .from('teams')
          .select('id')
          .eq('team_code', teamId)
          .limit(1);

      if (teamResponse.isEmpty) {
        return {'success': false, 'error': 'Team not found'};
      }

      final teamIdUuid = teamResponse[0]['id'];
      final authResponse = await _client.auth.signUp(email: email, password: password);

      if (authResponse.user == null) throw Exception('Failed to create user');

      await _client.from('users').insert({
        'id': authResponse.user!.id,
        'full_name': fullName,
        'email': email,
        'team_id': teamIdUuid,
        'role': 'member',
      });

      return {'success': true, 'teamId': teamId};
    } catch (e) {
      debugPrint('Error joining team: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> teamExists(String teamId) async {
    try {
      if (!_isInitialized) return false;
      final response = await _client.rpc(
        'check_team_code_exists',
        params: {'code': teamId},
      );
      return response == true;
    } catch (e) {
      debugPrint('Error checking team: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final redirectUrl = dotenv.env['OAUTH_REDIRECT_URL'] ??
          'io.supabase.ellena://login-callback';

      final completer = Completer<Map<String, dynamic>>();
      StreamSubscription<AuthState>? authSubscription;

      authSubscription = _client.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        final session = data.session;
        if (event == AuthChangeEvent.signedIn && session != null) {
          _processAuthenticatedUser(session.user, session).then((result) {
            authSubscription?.cancel();
            if (!completer.isCompleted) completer.complete(result);
          });
        }
      });

      final response = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
        queryParams: const {'access_type': 'offline', 'prompt': 'consent'},
      );

      if (!response) {
        await authSubscription.cancel();
        return {'success': false, 'error': 'Failed to launch Google sign-in'};
      }

      return await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          authSubscription?.cancel();
          return {'success': false, 'error': 'Authentication timed out'};
        },
      );
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _processAuthenticatedUser(
      User user, Session session) async {
    try {
      final existingProfile = await _client
          .from('users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existingProfile != null) {
        return {'success': true, 'isNewUser': false, 'email': user.email};
      } else {
        return {
          'success': true,
          'isNewUser': true,
          'email': user.email,
          'googleRefreshToken': session.providerRefreshToken,
        };
      }
    } catch (e) {
      debugPrint('Error processing authenticated user: $e');
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
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final authedEmail = user.email;
      if (authedEmail == null ||
          authedEmail.toLowerCase() != email.toLowerCase()) {
        return {'success': false, 'error': 'Email mismatch for authenticated user'};
      }

      final teamExistsResponse = await _client.rpc(
        'check_team_code_exists',
        params: {'code': teamCode},
      );

      if (teamExistsResponse != true) {
        return {'success': false, 'error': 'Team not found'};
      }

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
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final authedEmail = user.email;
      if (authedEmail == null ||
          authedEmail.toLowerCase() != email.toLowerCase()) {
        return {'success': false, 'error': 'Email mismatch for authenticated user'};
      }

      String teamId;
      bool isUnique = false;
      int attempts = 0;

      do {
        teamId = generateTeamId();
        attempts++;
        try {
          final response = await _client.rpc(
            'check_team_code_exists',
            params: {'code': teamId},
          );
          isUnique = response == false;
        } catch (e) {
          debugPrint('Error checking team code: $e');
          if (attempts >= 3) {
            throw Exception(
                'Unable to verify team code uniqueness. Please try again.');
          }
        }
      } while (!isUnique && attempts < 10);

      Map<String, dynamic>? teamResponse;
      int insertAttempts = 0;

      while (teamResponse == null && insertAttempts < 3) {
        try {
          final teamInsertResponse = await _client.from('teams').insert({
            'name': teamName,
            'team_code': teamId,
            'created_by': user.id,
            'admin_name': adminName,
            'admin_email': authedEmail,
          }).select();
          teamResponse =
              teamInsertResponse.isNotEmpty ? teamInsertResponse.first : null;
        } catch (e) {
          if (e.toString().contains('duplicate') ||
              e.toString().contains('unique')) {
            teamId = generateTeamId();
            insertAttempts++;
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
        'id': user.id,
        'full_name': adminName,
        'email': authedEmail,
        'team_id': teamResponse['id'],
        'role': 'admin',
        'google_refresh_token': googleRefreshToken,
      });

      return {'success': true, 'teamId': teamId, 'teamData': teamResponse};
    } catch (e) {
      debugPrint('Error creating team with Google: $e');
      return {'success': false, 'error': 'Failed to create team. Please try again.'};
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile(
      {bool forceRefresh = false}) async {
    try {
      if (!_isInitialized) return null;
      final user = _client.auth.currentUser;
      if (user == null) return null;

      if (!forceRefresh && _userProfileCache != null) return _userProfileCache;

      final response = await _client
          .from('users')
          .select('*, teams(name, team_code)')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) await _saveUserProfileToCache(response);

      return response;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return _userProfileCache;
    }
  }

  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    try {
      if (!_isInitialized) return false;
      final user = _client.auth.currentUser;
      if (user == null) return false;

      await _client.from('users').update(data).eq('id', user.id);

      if (_userProfileCache != null) {
        final updatedProfile = Map<String, dynamic>.from(_userProfileCache!);
        data.forEach((key, value) => updatedProfile[key] = value);
        await _saveUserProfileToCache(updatedProfile);
      }

      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    if (!_isInitialized) return;
    await _client.auth.signOut();
    await _clearCachedUserProfile();
    _teamMembersCache = [];
    _currentTeamId = null;
  }

  Future<Map<String, dynamic>> verifyOTP({
    required String email,
    required String token,
    required String type,
    Map<String, dynamic> userData = const {},
  }) async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final response = await _client.auth.verifyOTP(
        token: token.trim(),
        type: OtpType.email,
        email: email,
      );

      if (response.user == null) {
        return {'success': false, 'error': 'Invalid verification code'};
      }

      await Future.delayed(const Duration(milliseconds: 500));

      String? password = userData['password'] as String?;
      if (password != null && password.isNotEmpty) {
        try {
          await _client.auth.updateUser(UserAttributes(password: password));
        } catch (e) {
          debugPrint('Error setting password: $e');
        }
      }

      if (type == 'signup_create' && userData.isNotEmpty) {
        try {
          String teamId;
          bool isUnique = false;
          int attempts = 0;

          do {
            teamId = generateTeamId();
            attempts++;
            try {
              final checkResponse = await _client.rpc(
                'check_team_code_exists',
                params: {'code': teamId},
              );
              isUnique = checkResponse == false;
            } catch (e) {
              debugPrint('Error checking team code: $e');
              if (attempts >= 3) isUnique = true;
            }
          } while (!isUnique && attempts < 10);

          final teamInsertResponse = await _client.from('teams').insert({
            'name': userData['teamName'] ?? 'New Team',
            'team_code': teamId,
            'created_by': response.user!.id,
            'admin_name': userData['adminName'] ?? '',
            'admin_email': email,
          }).select();

          final teamResponse =
              teamInsertResponse.isNotEmpty ? teamInsertResponse.first : null;

          if (teamResponse == null) throw Exception('Failed to create team');

          await _client.from('users').insert({
            'id': response.user!.id,
            'full_name': userData['adminName'] ?? '',
            'email': email,
            'team_id': teamResponse['id'],
            'role': 'admin',
          });

          return {'success': true, 'teamId': teamId};
        } catch (e) {
          debugPrint('Error creating team after verification: $e');
          return {'success': false, 'error': e.toString()};
        }
      } else if (type == 'signup_join' && userData.isNotEmpty) {
        try {
          final teamResponse = await _client
              .from('teams')
              .select('id')
              .eq('team_code', userData['teamId'])
              .limit(1);

          if (teamResponse.isEmpty) {
            return {'success': false, 'error': 'Team not found'};
          }

          await _client.from('users').insert({
            'id': response.user!.id,
            'full_name': userData['fullName'] ?? '',
            'email': email,
            'team_id': teamResponse[0]['id'],
            'role': 'member',
          });

          return {'success': true};
        } catch (e) {
          debugPrint('Error joining team after verification: $e');
          return {'success': false, 'error': e.toString()};
        }
      } else if (type == 'reset_password') {
        return {'success': true};
      }

      return {'success': true};
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resendVerificationEmail(String email,
      {String type = 'signup'}) async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final OtpType otpType;
      switch (type) {
        case 'signup':
        case 'signup_create':
        case 'signup_join':
          otpType = OtpType.signup;
          break;
        case 'email_change':
          otpType = OtpType.emailChange;
          break;
        case 'reset_password':
          await _client.auth.resetPasswordForEmail(email);
          return {'success': true};
        default:
          return {'success': false, 'error': 'Invalid OTP type: $type'};
      }

      await _client.auth.resend(type: otpType, email: email);
      return {'success': true};
    } catch (e) {
      debugPrint('Error resending verification email: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getTeamMembers(String teamIdOrCode) async {
    try {
      if (!_isInitialized) return [];
      final user = _client.auth.currentUser;
      if (user == null) return [];

      String teamIdUuid;
      final uuidPattern = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          caseSensitive: false);

      if (uuidPattern.hasMatch(teamIdOrCode)) {
        teamIdUuid = teamIdOrCode;
      } else {
        final teamResponse = await _client
            .from('teams')
            .select('id')
            .eq('team_code', teamIdOrCode)
            .limit(1);

        if (teamResponse.isEmpty) return [];
        teamIdUuid = teamResponse[0]['id'];
      }

      final response = await _client
          .from('users')
          .select('*')
          .eq('team_id', teamIdUuid)
          .order('role', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting team members: $e');
      return [];
    }
  }

  // ─── Task methods ────────────────────────────────────────────────────────────

  // FIX: Replaced N+1 _getUserInfo loop with a single joined query.
  // Uses _userEmbed constant for the projection so schema changes only
  // need to be made in one place.
  Future<List<Map<String, dynamic>>> getTasks({
    bool filterByAssignment = false,
    String? filterByStatus,
    String? filterByDueDate,
  }) async {
    try {
      if (!_isInitialized) return [];
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final userProfile = await getCurrentUserProfile();
      if (userProfile == null || userProfile['team_id'] == null) return [];

      final teamId = userProfile['team_id'];
      final userId = user.id;
      final isAdmin = userProfile['role'] == 'admin';

      var query = _client.from('tasks').select('''
        *,
        creator:created_by($_userEmbed),
        assignee:assigned_to($_userEmbed)
      ''').eq('team_id', teamId);

      if (filterByAssignment || !isAdmin) {
        query = query.eq('assigned_to', userId);
      }

      if (filterByStatus != null) {
        query = query.eq('status', filterByStatus);
      }

      if (filterByDueDate != null) {
        try {
          final date = DateTime.parse(filterByDueDate);
          final startOfDay = DateTime(date.year, date.month, date.day);
          final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
          query = query
              .gte('due_date', startOfDay.toIso8601String())
              .lte('due_date', endOfDay.toIso8601String());
        } catch (e) {
          debugPrint('Error parsing due date filter: $e');
        }
      }

      final response = await query.order('created_at', ascending: false);
      final tasks = List<Map<String, dynamic>>.from(response);

      if (!_disposed && !_tasksStreamController.isClosed) {
        _tasksStreamController.add(tasks);
      }

      return tasks;
    } catch (e) {
      debugPrint('Error getting tasks: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createTask({
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedToUserId,
  }) async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final userProfile = await getCurrentUserProfile();
      if (userProfile == null || userProfile['team_id'] == null) {
        return {'success': false, 'error': 'User not associated with a team'};
      }

      final Map<String, dynamic> taskData = {
        'title': title,
        'description': description,
        'status': 'todo',
        'approval_status': 'pending',
        'team_id': userProfile['team_id'],
        'created_by': user.id,
      };

      if (assignedToUserId != null && assignedToUserId.isNotEmpty) {
        taskData['assigned_to'] = assignedToUserId;
      }

      if (dueDate != null) {
        taskData['due_date'] = dueDate.toIso8601String();
      }

      final response = await _client.from('tasks').insert(taskData).select();

      if (response.isEmpty) {
        return {'success': false, 'error': 'Failed to create task'};
      }

      return {'success': true, 'task': response[0]};
    } catch (e) {
      debugPrint('Error creating task: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      await _client.from('tasks').update({'status': status}).eq('id', taskId);
      return {'success': true};
    } catch (e) {
      debugPrint('Error updating task status: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateTaskApproval({
    required String taskId,
    required String approvalStatus,
  }) async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final userProfile = await getCurrentUserProfile();
      if (userProfile == null || userProfile['role'] != 'admin') {
        return {'success': false, 'error': 'Only admins can approve tasks'};
      }

      await _client
          .from('tasks')
          .update({'approval_status': approvalStatus}).eq('id', taskId);

      return {'success': true};
    } catch (e) {
      debugPrint('Error updating task approval: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // FIX: Replaced separate per-field and per-comment _getUserInfo calls with joins.
  // Now 2 queries total (task + comments) regardless of comment count.
  Future<Map<String, dynamic>?> getTaskDetails(String taskId) async {
    try {
      if (!_isInitialized) return null;
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final taskResponse = await _client.from('tasks').select('''
        *,
        creator:created_by($_userEmbed),
        assignee:assigned_to($_userEmbed)
      ''').eq('id', taskId).single();

      final commentsResponse = await _client
          .from('task_comments')
          .select('*, user:user_id($_userEmbed)')
          .eq('task_id', taskId)
          .order('created_at', ascending: true);

      return {
        'task': taskResponse,
        'comments': List<Map<String, dynamic>>.from(commentsResponse),
      };
    } catch (e) {
      debugPrint('Error getting task details: $e');
      return null;
    }
  }

  // FIX: User info joined in the same insert select, no extra query needed.
  Future<Map<String, dynamic>> addTaskComment({
    required String taskId,
    required String content,
  }) async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final response = await _client.from('task_comments').insert({
        'task_id': taskId,
        'user_id': user.id,
        'content': content,
      }).select('*, user:user_id($_userEmbed)');

      if (response.isEmpty) {
        return {'success': false, 'error': 'Failed to add comment'};
      }

      return {'success': true, 'comment': response[0]};
    } catch (e) {
      debugPrint('Error adding task comment: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteTask(String taskId) async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final response =
          await _client.from('tasks').delete().eq('id', taskId).select('id');

      if (response.isEmpty) {
        final checkTask = await _client
            .from('tasks')
            .select('id')
            .eq('id', taskId)
            .maybeSingle();

        return {
          'success': false,
          'error': checkTask != null
              ? 'Permission denied: You can only delete tasks you created or if you are an admin'
              : 'Task not found or permission denied',
        };
      }

      return {'success': true};
    } catch (e) {
      debugPrint('Error deleting task: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── Ticket methods ───────────────────────────────────────────────────────────

  List<String> getTicketCategories() {
    return [
      'Bug',
      'Feature Request',
      'UI/UX',
      'Performance',
      'Documentation',
      'Security',
      'Other'
    ];
  }

  // FIX: Replaced N+1 _getUserInfo loop with a single joined query.
  // FIX: Now publishes result to ticketsStream so all subscribers
  // (createTicket, updateTicketStatus, etc.) receive the refreshed list.
  Future<List<Map<String, dynamic>>> getTickets({
    bool filterByAssignment = false,
    String? filterByStatus,
    String? filterByPriority,
  }) async {
    try {
      if (!_isInitialized) return [];
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final userProfile = await getCurrentUserProfile();
      if (userProfile == null || userProfile['team_id'] == null) return [];

      final teamId = userProfile['team_id'];
      final userId = user.id;
      final isAdmin = userProfile['role'] == 'admin';

      var query = _client.from('tickets').select('''
        *,
        creator:created_by($_userEmbed),
        assignee:assigned_to($_userEmbed)
      ''').eq('team_id', teamId);

      if (filterByAssignment || !isAdmin) {
        query = query.eq('assigned_to', userId);
      }

      if (filterByStatus != null) {
        query = query.eq('status', filterByStatus);
      }

      if (filterByPriority != null) {
        query = query.eq('priority', filterByPriority);
      }

      final response = await query.order('created_at', ascending: false);
      final tickets = List<Map<String, dynamic>>.from(response);

      if (!_disposed && !_ticketsStreamController.isClosed) {
        _ticketsStreamController.add(tickets);
      }

      return tickets;
    } catch (e) {
      debugPrint('Error getting tickets: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createTicket({
    required String title,
    String? description,
    required String priority,
    required String category,
    String? assignedToUserId,
  }) async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final userProfile = await getCurrentUserProfile();
      if (userProfile == null || userProfile['team_id'] == null) {
        return {'success': false, 'error': 'User not associated with a team'};
      }

      final Map<String, dynamic> ticketData = {
        'title': title,
        'description': description,
        'priority': priority,
        'category': category,
        'status': 'open',
        'approval_status': 'pending',
        'team_id': userProfile['team_id'],
        'created_by': user.id,
      };

      if (assignedToUserId != null && assignedToUserId.isNotEmpty) {
        ticketData['assigned_to'] = assignedToUserId;
      }

      final response =
          await _client.from('tickets').insert(ticketData).select();

      if (response.isEmpty) {
        return {'success': false, 'error': 'Failed to create ticket'};
      }

      await getTickets();
      return {'success': true, 'ticket': response[0]};
    } catch (e) {
      debugPrint('Error creating ticket: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateTicketStatus({
    required String ticketId,
    required String status,
  }) async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      await _client
          .from('tickets')
          .update({'status': status}).eq('id', ticketId);

      await getTickets();
      return {'success': true};
    } catch (e) {
      debugPrint('Error updating ticket status: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateTicketPriority({
    required String ticketId,
    required String priority,
  }) async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      await _client
          .from('tickets')
          .update({'priority': priority}).eq('id', ticketId);

      await getTickets();
      return {'success': true};
    } catch (e) {
      debugPrint('Error updating ticket priority: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateTicketApproval({
    required String ticketId,
    required String approvalStatus,
  }) async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final userProfile = await getCurrentUserProfile();
      if (userProfile == null || userProfile['role'] != 'admin') {
        return {'success': false, 'error': 'Only admins can approve tickets'};
      }

      await _client
          .from('tickets')
          .update({'approval_status': approvalStatus}).eq('id', ticketId);

      await getTickets();
      return {'success': true};
    } catch (e) {
      debugPrint('Error updating ticket approval: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // FIX: Replaced separate per-field and per-comment _getUserInfo calls with joins.
  // Now 2 queries total (ticket + comments) regardless of comment count.
  Future<Map<String, dynamic>?> getTicketDetails(String ticketId) async {
    try {
      if (!_isInitialized) return null;
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final ticketResponse = await _client.from('tickets').select('''
        *,
        creator:created_by($_userEmbed),
        assignee:assigned_to($_userEmbed)
      ''').eq('id', ticketId).single();

      final commentsResponse = await _client
          .from('ticket_comments')
          .select('*, user:user_id($_userEmbed)')
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);

      return {
        'ticket': ticketResponse,
        'comments': List<Map<String, dynamic>>.from(commentsResponse),
      };
    } catch (e) {
      debugPrint('Error getting ticket details: $e');
      return null;
    }
  }

  // FIX: User info joined in the same insert select, no extra query needed.
  Future<Map<String, dynamic>> addTicketComment({
    required String ticketId,
    required String content,
  }) async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final response = await _client.from('ticket_comments').insert({
        'ticket_id': ticketId,
        'user_id': user.id,
        'content': content,
      }).select('*, user:user_id($_userEmbed)');

      if (response.isEmpty) {
        return {'success': false, 'error': 'Failed to add comment'};
      }

      return {'success': true, 'comment': response[0]};
    } catch (e) {
      debugPrint('Error adding ticket comment: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteTicket(String ticketId) async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final response = await _client
          .from('tickets')
          .delete()
          .eq('id', ticketId)
          .select('id');

      if (response.isEmpty) {
        final checkTicket = await _client
            .from('tickets')
            .select('id')
            .eq('id', ticketId)
            .maybeSingle();

        return {
          'success': false,
          'error': checkTicket != null
              ? 'Permission denied: You can only delete tickets you created or if you are an admin'
              : 'Ticket not found or permission denied',
        };
      }

      return {'success': true};
    } catch (e) {
      debugPrint('Error deleting ticket: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> assignTicket({
    required String ticketId,
    required String userId,
  }) async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      await _client
          .from('tickets')
          .update({'assigned_to': userId}).eq('id', ticketId);

      await getTickets();
      return {'success': true};
    } catch (e) {
      debugPrint('Error assigning ticket: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── Meeting methods ──────────────────────────────────────────────────────────

  // FIX: Replaced N+1 _getUserInfo loop with a single joined query.
  Future<List<Map<String, dynamic>>> getMeetings() async {
    try {
      if (!_isInitialized) return [];
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final userProfile = await getCurrentUserProfile();
      if (userProfile == null || userProfile['team_id'] == null) return [];

      final teamId = userProfile['team_id'];
      debugPrint('Fetching meetings for team ID: $teamId');

      final response = await _client.from('meetings').select('''
        *,
        creator:created_by($_userEmbed)
      ''').eq('team_id', teamId).order('meeting_date', ascending: true);

      debugPrint('Meetings fetched: ${response.length}');

      final meetings = List<Map<String, dynamic>>.from(response);

      if (!_disposed && !_meetingsStreamController.isClosed) {
        _meetingsStreamController.add(meetings);
      }

      return meetings;
    } catch (e) {
      debugPrint('Error getting meetings: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createMeeting({
    required String title,
    String? description,
    required DateTime meetingDate,
    String? meetingUrl,
    int durationMinutes = 60,
  }) async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final userProfile = await getCurrentUserProfile();
      if (userProfile == null || userProfile['team_id'] == null) {
        return {'success': false, 'error': 'User not associated with a team'};
      }

      final response = await _client.from('meetings').insert({
        'title': title,
        'description': description,
        'meeting_date': meetingDate.toIso8601String(),
        'meeting_url': meetingUrl,
        'team_id': userProfile['team_id'],
        'created_by': user.id,
        'duration_minutes': durationMinutes,
      }).select();

      if (response.isEmpty) {
        return {'success': false, 'error': 'Failed to create meeting'};
      }

      await getMeetings();
      return {'success': true, 'meeting': response[0]};
    } catch (e) {
      debugPrint('Error creating meeting: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // FIX: Replaced separate _getUserInfo call with an inline join.
  Future<Map<String, dynamic>?> getMeetingDetails(String meetingId) async {
    try {
      if (!_isInitialized) return null;
      final user = _client.auth.currentUser;
      if (user == null) return null;

      return await _client.from('meetings').select('''
        *,
        creator:created_by($_userEmbed)
      ''').eq('id', meetingId).single();
    } catch (e) {
      debugPrint('Error getting meeting details: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> updateMeeting({
    required String meetingId,
    required String title,
    String? description,
    required DateTime meetingDate,
    String? meetingUrl,
    String? transcription,
    String? ai_summary,
    int? durationMinutes,
  }) async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final Map<String, dynamic> meetingData = {
        'title': title,
        'description': description,
        'meeting_date': meetingDate.toIso8601String(),
        'meeting_url': meetingUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (transcription != null) meetingData['transcription'] = transcription;
      if (ai_summary != null) meetingData['ai_summary'] = ai_summary;
      if (durationMinutes != null) meetingData['duration_minutes'] = durationMinutes;

      final response = await _client
          .from('meetings')
          .update(meetingData)
          .eq('id', meetingId)
          .select();

      if (response.isEmpty) {
        return {'success': false, 'error': 'Failed to update meeting'};
      }

      await getMeetings();
      return {'success': true, 'meeting': response[0]};
    } catch (e) {
      debugPrint('Error updating meeting: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteMeeting(String meetingId) async {
    try {
      if (!_isInitialized) {
        return {'success': false, 'error': 'Supabase is not initialized'};
      }

      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      await _client.from('meetings').delete().eq('id', meetingId);
      await getMeetings();
      return {'success': true};
    } catch (e) {
      debugPrint('Error deleting meeting: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  void dispose() {
    _disposed = true;
    _tasksStreamController.close();
    _ticketsStreamController.close();
    _meetingsStreamController.close();
  }
}