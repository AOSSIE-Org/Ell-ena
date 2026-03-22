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

  /// Centralized user embed projection.
  /// Update this single constant if the users table schema changes.
  static const String _userEmbed = 'id, full_name, role';

  factory SupabaseService() => _instance;

  SupabaseService._internal();

  bool get isInitialized => _isInitialized;
  List<Map<String, dynamic>> get teamMembersCache => _teamMembersCache;
  User? get currentUser => _isInitialized ? _client.auth.currentUser : null;
  SupabaseClient get client => _client;


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

      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
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
      debugPrint