import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

/// Centralized data caching service to prevent duplicate API requests
/// Implements 5-minute TTL caching for tasks, tickets, meetings, and user teams
class DataCacheService {
  static final DataCacheService _instance = DataCacheService._internal();
  factory DataCacheService() => _instance;
  DataCacheService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  
  // Cache duration: 5 minutes as per requirements
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  // Cache keys
  static const String _tasksKey = 'cache_tasks';
  static const String _ticketsKey = 'cache_tickets';
  static const String _meetingsKey = 'cache_meetings';
  static const String _userTeamsKey = 'cache_user_teams';
  static const String _tasksTimestampKey = 'cache_tasks_timestamp';
  static const String _ticketsTimestampKey = 'cache_tickets_timestamp';
  static const String _meetingsTimestampKey = 'cache_meetings_timestamp';
  static const String _userTeamsTimestampKey = 'cache_user_teams_timestamp';
  
  // Request locks to prevent simultaneous duplicate requests
  final Map<String, Completer<List<Map<String, dynamic>>>> _pendingRequests = {};
  // Separate map for user teams (returns Map, not List)
  final Map<String, Completer<Map<String, dynamic>>> _pendingUserTeamsRequests = {};
  
  /// Get tasks with optional caching
  /// 
  /// [forceRefresh] - If true, bypasses cache and fetches fresh data
  /// [filterByAssignment] - Filter by assigned tasks
  /// [filterByStatus] - Filter by task status
  /// [filterByDueDate] - Filter by due date
  Future<List<Map<String, dynamic>>> getTasks({
    bool forceRefresh = false,
    bool? filterByAssignment,
    String? filterByStatus,
    String? filterByDueDate,
  }) async {
    final cacheKey = 'tasks_${filterByAssignment}_${filterByStatus}_${filterByDueDate}';
    
    // Check if there's already a pending request for this data
    if (_pendingRequests.containsKey(cacheKey)) {
      debugPrint('Waiting for pending tasks request...');
      return await _pendingRequests[cacheKey]!.future;
    }
    
    // Check cache validity
    if (!forceRefresh && await _isCacheValid(_tasksTimestampKey)) {
      final cached = await _loadFromCache(_tasksKey);
      if (cached != null) {
        debugPrint('Returning cached tasks (${cached.length} items)');
        return _applyTaskFilters(cached, filterByAssignment, filterByStatus, filterByDueDate);
      }
    }
    
    // Create a new request
    final completer = Completer<List<Map<String, dynamic>>>();
    _pendingRequests[cacheKey] = completer;
    
    try {
      debugPrint('Fetching fresh tasks from Supabase...');
      // Always fetch unfiltered data to cache; apply filters client-side
      final tasks = await _supabaseService.getTasks();
      
      // Save to cache
      await _saveToCache(_tasksKey, tasks);
      await _saveTimestamp(_tasksTimestampKey);
      
      // Apply filters to the full dataset
      final filtered = _applyTaskFilters(tasks, filterByAssignment, filterByStatus, filterByDueDate);
      completer.complete(filtered);
      _pendingRequests.remove(cacheKey);
      
      return filtered;
    } catch (e) {
      debugPrint('Error fetching tasks: $e');
      completer.completeError(e);
      _pendingRequests.remove(cacheKey);
      rethrow;
    }
  }
  
  /// Get tickets with optional caching
  /// 
  /// [forceRefresh] - If true, bypasses cache and fetches fresh data
  /// [filterByAssignment] - Filter by assigned tickets
  /// [filterByStatus] - Filter by ticket status
  /// [filterByPriority] - Filter by priority
  Future<List<Map<String, dynamic>>> getTickets({
    bool forceRefresh = false,
    bool? filterByAssignment,
    String? filterByStatus,
    String? filterByPriority,
  }) async {
    final cacheKey = 'tickets_${filterByAssignment}_${filterByStatus}_${filterByPriority}';
    
    // Check if there's already a pending request for this data
    if (_pendingRequests.containsKey(cacheKey)) {
      debugPrint('Waiting for pending tickets request...');
      return await _pendingRequests[cacheKey]!.future;
    }
    
    // Check cache validity
    if (!forceRefresh && await _isCacheValid(_ticketsTimestampKey)) {
      final cached = await _loadFromCache(_ticketsKey);
      if (cached != null) {
        debugPrint('Returning cached tickets (${cached.length} items)');
        return _applyTicketFilters(cached, filterByAssignment, filterByStatus, filterByPriority);
      }
    }
    
    // Create a new request
    final completer = Completer<List<Map<String, dynamic>>>();
    _pendingRequests[cacheKey] = completer;
    
    try {
      debugPrint('Fetching fresh tickets from Supabase...');
      // Always fetch unfiltered data to cache; apply filters client-side
      final tickets = await _supabaseService.getTickets();
      
      // Save to cache
      await _saveToCache(_ticketsKey, tickets);
      await _saveTimestamp(_ticketsTimestampKey);
      
      // Apply filters to the full dataset
      final filtered = _applyTicketFilters(tickets, filterByAssignment, filterByStatus, filterByPriority);
      completer.complete(filtered);
      _pendingRequests.remove(cacheKey);
      
      return filtered;
    } catch (e) {
      debugPrint('Error fetching tickets: $e');
      completer.completeError(e);
      _pendingRequests.remove(cacheKey);
      rethrow;
    }
  }
  
  /// Get meetings with optional caching
  /// 
  /// [forceRefresh] - If true, bypasses cache and fetches fresh data
  Future<List<Map<String, dynamic>>> getMeetings({
    bool forceRefresh = false,
  }) async {
    const cacheKey = 'meetings';
    
    // Check if there's already a pending request for this data
    if (_pendingRequests.containsKey(cacheKey)) {
      debugPrint('Waiting for pending meetings request...');
      return await _pendingRequests[cacheKey]!.future;
    }
    
    // Check cache validity
    if (!forceRefresh && await _isCacheValid(_meetingsTimestampKey)) {
      final cached = await _loadFromCache(_meetingsKey);
      if (cached != null) {
        debugPrint('Returning cached meetings (${cached.length} items)');
        return cached;
      }
    }
    
    // Create a new request
    final completer = Completer<List<Map<String, dynamic>>>();
    _pendingRequests[cacheKey] = completer;
    
    try {
      debugPrint('Fetching fresh meetings from Supabase...');
      final meetings = await _supabaseService.getMeetings();
      
      // Save to cache
      await _saveToCache(_meetingsKey, meetings);
      await _saveTimestamp(_meetingsTimestampKey);
      
      completer.complete(meetings);
      _pendingRequests.remove(cacheKey);
      
      return meetings;
    } catch (e) {
      debugPrint('Error fetching meetings: $e');
      completer.completeError(e);
      _pendingRequests.remove(cacheKey);
      rethrow;
    }
  }
  
  /// Get user teams with optional caching
  /// 
  /// [forceRefresh] - If true, bypasses cache and fetches fresh data
  /// [email] - User email to get teams for
  Future<Map<String, dynamic>> getUserTeams({
    bool forceRefresh = false,
    required String email,
  }) async {
    final cacheKey = 'user_teams_$email';
    final storageKey = '${_userTeamsKey}_$email'; // Email-specific storage key
    
    // Check if there's already a pending request for this data
    if (_pendingUserTeamsRequests.containsKey(cacheKey)) {
      debugPrint('Waiting for pending user teams request...');
      return await _pendingUserTeamsRequests[cacheKey]!.future;
    }
    
    // Check cache validity
    if (!forceRefresh && await _isCacheValid(_userTeamsTimestampKey)) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedJson = prefs.getString(storageKey);
        if (cachedJson != null) {
          final cached = jsonDecode(cachedJson) as Map<String, dynamic>;
          debugPrint('Returning cached user teams');
          return cached;
        }
      } catch (e) {
        debugPrint('Error loading cached user teams: $e');
      }
    }
    
    // Create a completer for request deduplication
    final completer = Completer<Map<String, dynamic>>();
    _pendingUserTeamsRequests[cacheKey] = completer;
    
    try {
      debugPrint('Fetching fresh user teams from Supabase...');
      final result = await _supabaseService.getUserTeams(email);
      
      // Save to cache with email-specific key
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(result));
      await _saveTimestamp(_userTeamsTimestampKey);
      
      // Complete and remove from pending
      completer.complete(result);
      _pendingUserTeamsRequests.remove(cacheKey);
      
      return result;
    } catch (e) {
      debugPrint('Error fetching user teams: $e');
      completer.completeError(e);
      _pendingUserTeamsRequests.remove(cacheKey);
      rethrow;
    }
  }
  
  /// Invalidate cache for a specific data type
  /// 
  /// [type] - One of: 'tasks', 'tickets', 'meetings', 'user_teams', 'all'
  Future<void> invalidateCache(String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      switch (type.toLowerCase()) {
        case 'tasks':
          await prefs.remove(_tasksKey);
          await prefs.remove(_tasksTimestampKey);
          debugPrint('Tasks cache invalidated');
          break;
        case 'tickets':
          await prefs.remove(_ticketsKey);
          await prefs.remove(_ticketsTimestampKey);
          debugPrint('Tickets cache invalidated');
          break;
        case 'meetings':
          await prefs.remove(_meetingsKey);
          await prefs.remove(_meetingsTimestampKey);
          debugPrint('Meetings cache invalidated');
          break;
        case 'user_teams':
          await prefs.remove(_userTeamsKey);
          await prefs.remove(_userTeamsTimestampKey);
          debugPrint('User teams cache invalidated');
          break;
        case 'all':
          await prefs.remove(_tasksKey);
          await prefs.remove(_tasksTimestampKey);
          await prefs.remove(_ticketsKey);
          await prefs.remove(_ticketsTimestampKey);
          await prefs.remove(_meetingsKey);
          await prefs.remove(_meetingsTimestampKey);
          await prefs.remove(_userTeamsKey);
          await prefs.remove(_userTeamsTimestampKey);
          debugPrint('All caches invalidated');
          break;
        default:
          debugPrint('Unknown cache type: $type');
      }
    } catch (e) {
      debugPrint('Error invalidating cache: $e');
    }
  }
  
  // Private helper methods
  
  /// Check if cache is still valid (within TTL)
  Future<bool> _isCacheValid(String timestampKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampStr = prefs.getString(timestampKey);
      
      if (timestampStr == null) return false;
      
      final timestamp = DateTime.parse(timestampStr);
      final now = DateTime.now();
      final difference = now.difference(timestamp);
      
      return difference < _cacheDuration;
    } catch (e) {
      debugPrint('Error checking cache validity: $e');
      return false;
    }
  }
  
  /// Load data from SharedPreferences cache
  Future<List<Map<String, dynamic>>?> _loadFromCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(key);
      
      if (cachedJson == null) return null;
      
      final decoded = jsonDecode(cachedJson) as List;
      return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      debugPrint('Error loading from cache: $e');
      return null;
    }
  }
  
  /// Save data to SharedPreferences cache
  Future<void> _saveToCache(String key, List<Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving to cache: $e');
    }
  }
  
  /// Save timestamp for cache validation
  Future<void> _saveTimestamp(String timestampKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(timestampKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Error saving timestamp: $e');
    }
  }
  
  /// Apply filters to cached tasks
  List<Map<String, dynamic>> _applyTaskFilters(
    List<Map<String, dynamic>> tasks,
    bool? filterByAssignment,
    String? filterByStatus,
    String? filterByDueDate,
  ) {
    var filtered = tasks;
    
    // Note: Assignment filtering requires current user ID which we don't have in cache
    // This should be handled by the caller if needed
    
    if (filterByStatus != null && filterByStatus != 'all') {
      filtered = filtered.where((task) => task['status'] == filterByStatus).toList();
    }
    
    if (filterByDueDate != null) {
      try {
        final dueDate = DateTime.parse(filterByDueDate);
        filtered = filtered.where((task) {
          if (task['due_date'] == null) return false;
          final taskDueDate = DateTime.parse(task['due_date']);
          return taskDueDate.year == dueDate.year &&
                 taskDueDate.month == dueDate.month &&
                 taskDueDate.day == dueDate.day;
        }).toList();
      } catch (e) {
        debugPrint('Error parsing due date filter: $e');
      }
    }
    
    return filtered;
  }
  
  /// Apply filters to cached tickets
  List<Map<String, dynamic>> _applyTicketFilters(
    List<Map<String, dynamic>> tickets,
    bool? filterByAssignment,
    String? filterByStatus,
    String? filterByPriority,
  ) {
    var filtered = tickets;
    
    if (filterByStatus != null && filterByStatus != 'all') {
      filtered = filtered.where((ticket) => ticket['status'] == filterByStatus).toList();
    }
    
    if (filterByPriority != null && filterByPriority != 'all') {
      filtered = filtered.where((ticket) => ticket['priority'] == filterByPriority).toList();
    }
    
    return filtered;
  }
}
