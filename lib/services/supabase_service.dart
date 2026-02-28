import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'meeting_service.dart';
import 'task_service.dart';
import 'team_service.dart';
import 'ticket_service.dart';

/// Thin initialisation facade.
/// All business logic lives in the domain-specific service classes.
/// This class is kept for backward-compatibility so existing screens
/// that call `SupabaseService().someMethod()` continue to work unchanged.
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late SupabaseClient _client;
  bool _isInitialized = false;

  // ── Domain services ───────────────────────────────────────────────────────
  late final AuthService _auth;
  late final TeamService _team;
  late final TaskService _tasks;
  late final TicketService _tickets;
  late final MeetingService _meetings;

  // ── Initialization guard ─────────────────────────────────────────────────
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'SupabaseService must be initialized before use. Call initialize() first.',
      );
    }
  }

  // Public accessors so callers can use the services directly if they wish.
  AuthService    get auth     { _ensureInitialized(); return _auth; }
  TeamService    get team     { _ensureInitialized(); return _team; }
  TaskService    get tasks    { _ensureInitialized(); return _tasks; }
  TicketService  get tickets  { _ensureInitialized(); return _tickets; }
  MeetingService get meetings { _ensureInitialized(); return _meetings; }

  // ── Basic state getters ───────────────────────────────────────────────────
  bool                         get isInitialized    => _isInitialized;
  SupabaseClient               get client           { _ensureInitialized(); return _client; }
  User?                        get currentUser      => _isInitialized ? _client.auth.currentUser : null;
  List<Map<String, dynamic>>   get teamMembersCache => _isInitialized ? _team.membersCache : [];

  // Stream pass-throughs
  Stream<List<Map<String, dynamic>>> get tasksStream    { _ensureInitialized(); return _tasks.tasksStream; }
  Stream<List<Map<String, dynamic>>> get ticketsStream  { _ensureInitialized(); return _tickets.ticketsStream; }
  Stream<List<Map<String, dynamic>>> get meetingsStream { _ensureInitialized(); return _meetings.meetingsStream; }

  // ── Initialisation ────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await dotenv.load().catchError((e) {
        debugPrint('Error loading .env file: $e');
      });

      final url    = dotenv.env['SUPABASE_URL']      ?? '';
      final anonKey= dotenv.env['SUPABASE_ANON_KEY'] ?? '';

      if (url.isEmpty || anonKey.isEmpty) {
        throw Exception('Missing Supabase config. Check your .env file.');
      }

      await Supabase.initialize(url: url, anonKey: anonKey);
      _client = Supabase.instance.client;

      _auth     = AuthService(_client);
      _team     = TeamService(_client, _auth);
      _tasks    = TaskService(_client, _auth, _team);
      _tickets  = TicketService(_client, _auth, _team);
      _meetings = MeetingService(_client, _auth, _team);

      _isInitialized = true;

      await _auth.loadCachedProfile();
      await _team.loadTeamMembersIfLoggedIn();
    } catch (e) {
      debugPrint('Error initialising Supabase: $e');
      rethrow;
    }
  }

  // ── Auth / Profile delegates ──────────────────────────────────────────────
  Future<Map<String, dynamic>?> getCurrentUserProfile({bool forceRefresh = false}) =>
      _auth.getCurrentUserProfile(forceRefresh: forceRefresh);

  Future<bool> updateUserProfile(Map<String, dynamic> data) =>
      _auth.updateUserProfile(data);

  Future<void> signOut() async {
    await _auth.signOut();
    _team.clearCache();
  }

  Future<Map<String, dynamic>> signInWithGoogle() =>
      _auth.signInWithGoogle();

  Future<Map<String, dynamic>> joinTeamWithGoogle({
    required String email,
    required String teamCode,
    required String fullName,
    String? googleRefreshToken,
  }) => _auth.joinTeamWithGoogle(
        email: email,
        teamCode: teamCode,
        fullName: fullName,
        googleRefreshToken: googleRefreshToken,
      );

  Future<Map<String, dynamic>> createTeamWithGoogle({
    required String email,
    required String teamName,
    required String adminName,
    String? googleRefreshToken,
  }) => _auth.createTeamWithGoogle(
        email: email,
        teamName: teamName,
        adminName: adminName,
        googleRefreshToken: googleRefreshToken,
      );

  Future<Map<String, dynamic>> verifyOTP({
    required String email,
    required String token,
    required String type,
    Map<String, dynamic> userData = const {},
  }) => _auth.verifyOTP(email: email, token: token, type: type, userData: userData);

  Future<Map<String, dynamic>> resendVerificationEmail(String email, {String type = 'signup'}) =>
      _auth.resendVerificationEmail(email, type: type);

  // ── Team delegates ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getUserTeams(String email)  => _team.getUserTeams(email);
  Future<Map<String, dynamic>> switchTeam(String teamId)   => _team.switchTeam(teamId);
  Future<void> loadTeamMembers(String teamIdOrCode)        => _team.loadTeamMembers(teamIdOrCode);
  String getUserNameById(String userId)                     => _team.getUserNameById(userId);
  bool   isCurrentUser(String userId)                       => _team.isCurrentUser(userId);
  String generateTeamId()                                   => _team.generateTeamId();
  Future<bool> teamExists(String teamId)                   => _team.teamExists(teamId);

  Future<List<Map<String, dynamic>>> getTeamMembers(String teamIdOrCode) =>
      _team.getTeamMembers(teamIdOrCode);

  Future<Map<String, dynamic>> createTeam({
    required String teamName,
    required String adminName,
    required String adminEmail,
    required String password,
  }) => _team.createTeam(
        teamName: teamName,
        adminName: adminName,
        adminEmail: adminEmail,
        password: password,
      );

  Future<Map<String, dynamic>> joinTeam({
    required String teamId,
    required String fullName,
    required String email,
    required String password,
  }) => _team.joinTeam(teamId: teamId, fullName: fullName, email: email, password: password);

  // ── Task delegates ────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getTasks({
    bool filterByAssignment = false,
    String? filterByStatus,
    String? filterByDueDate,
  }) => _tasks.getTasks(
        filterByAssignment: filterByAssignment,
        filterByStatus: filterByStatus,
        filterByDueDate: filterByDueDate,
      );

  Future<Map<String, dynamic>?> getTaskDetails(String taskId) =>
      _tasks.getTaskDetails(taskId);

  Future<Map<String, dynamic>> createTask({
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedToUserId,
  }) => _tasks.createTask(
        title: title,
        description: description,
        dueDate: dueDate,
        assignedToUserId: assignedToUserId,
      );

  Future<Map<String, dynamic>> updateTaskStatus({
    required String taskId,
    required String status,
  }) => _tasks.updateTaskStatus(taskId: taskId, status: status);

  Future<Map<String, dynamic>> updateTaskApproval({
    required String taskId,
    required String approvalStatus,
  }) => _tasks.updateTaskApproval(taskId: taskId, approvalStatus: approvalStatus);

  Future<Map<String, dynamic>> addTaskComment({
    required String taskId,
    required String content,
  }) => _tasks.addTaskComment(taskId: taskId, content: content);

  Future<Map<String, dynamic>> deleteTask(String taskId) =>
      _tasks.deleteTask(taskId);

  // ── Ticket delegates ──────────────────────────────────────────────────────
  List<String> getTicketCategories() => _tickets.getTicketCategories();

  Future<List<Map<String, dynamic>>> getTickets({
    bool filterByAssignment = false,
    String? filterByStatus,
    String? filterByPriority,
  }) => _tickets.getTickets(
        filterByAssignment: filterByAssignment,
        filterByStatus: filterByStatus,
        filterByPriority: filterByPriority,
      );

  Future<Map<String, dynamic>?> getTicketDetails(String ticketId) =>
      _tickets.getTicketDetails(ticketId);

  Future<Map<String, dynamic>> createTicket({
    required String title,
    String? description,
    required String priority,
    required String category,
    String? assignedToUserId,
  }) => _tickets.createTicket(
        title: title,
        description: description,
        priority: priority,
        category: category,
        assignedToUserId: assignedToUserId,
      );

  Future<Map<String, dynamic>> updateTicketStatus({
    required String ticketId,
    required String status,
  }) => _tickets.updateTicketStatus(ticketId: ticketId, status: status);

  Future<Map<String, dynamic>> updateTicketPriority({
    required String ticketId,
    required String priority,
  }) => _tickets.updateTicketPriority(ticketId: ticketId, priority: priority);

  Future<Map<String, dynamic>> updateTicketApproval({
    required String ticketId,
    required String approvalStatus,
  }) => _tickets.updateTicketApproval(ticketId: ticketId, approvalStatus: approvalStatus);

  Future<Map<String, dynamic>> addTicketComment({
    required String ticketId,
    required String content,
  }) => _tickets.addTicketComment(ticketId: ticketId, content: content);

  Future<Map<String, dynamic>> deleteTicket(String ticketId) =>
      _tickets.deleteTicket(ticketId);

  Future<Map<String, dynamic>> assignTicket({
    required String ticketId,
    required String userId,
  }) => _tickets.assignTicket(ticketId: ticketId, userId: userId);

  // ── Meeting delegates ─────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMeetings() => _meetings.getMeetings();

  Future<Map<String, dynamic>?> getMeetingDetails(String meetingId) =>
      _meetings.getMeetingDetails(meetingId);

  Future<Map<String, dynamic>> createMeeting({
    required String title,
    String? description,
    required DateTime meetingDate,
    String? meetingUrl,
    int durationMinutes = 60,
  }) => _meetings.createMeeting(
        title: title,
        description: description,
        meetingDate: meetingDate,
        meetingUrl: meetingUrl,
        durationMinutes: durationMinutes,
      );

  Future<Map<String, dynamic>> updateMeeting({
    required String meetingId,
    required String title,
    String? description,
    required DateTime meetingDate,
    String? meetingUrl,
    String? transcription,
    String? ai_summary,
    int? durationMinutes,
  }) => _meetings.updateMeeting(
        meetingId: meetingId,
        title: title,
        description: description,
        meetingDate: meetingDate,
        meetingUrl: meetingUrl,
        transcription: transcription,
        ai_summary: ai_summary,
        durationMinutes: durationMinutes,
      );

  Future<Map<String, dynamic>> deleteMeeting(String meetingId) =>
      _meetings.deleteMeeting(meetingId);

  // ── Cleanup ───────────────────────────────────────────────────────────────
  void dispose() {
    if (_isInitialized) {
      _tasks.dispose();
      _tickets.dispose();
      _meetings.dispose();
    }
  }
}
