import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'team_service.dart';

/// Handles all task CRUD and exposes a real-time tasks stream.
class TaskService {
  final SupabaseClient _client;
  final AuthService _authService;
  final TeamService _teamService;

  final _streamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  TaskService(this._client, this._authService, this._teamService);

  Stream<List<Map<String, dynamic>>> get tasksStream => _streamController.stream;

  void dispose() => _streamController.close();

  Future<List<Map<String, dynamic>>> getTasks({
    bool filterByAssignment = false,
    String? filterByStatus,
    String? filterByDueDate,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final profile = await _authService.getCurrentUserProfile();
      if (profile == null || profile['team_id'] == null) return [];

      final query = _client
          .from('tasks')
          .select('*')
          .eq('team_id', profile['team_id']);

      if (filterByAssignment) query.eq('assigned_to', user.id);
      if (filterByStatus != null) query.eq('status', filterByStatus);

      if (filterByDueDate != null) {
        try {
          final d = DateTime.parse(filterByDueDate);
          query
              .gte('due_date', DateTime(d.year, d.month, d.day).toIso8601String())
              .lte('due_date', DateTime(d.year, d.month, d.day, 23, 59, 59).toIso8601String());
        } catch (e) {
          debugPrint('Error parsing due date filter: $e');
        }
      }

      final response = await query.order('created_at', ascending: false);

      final processed = <Map<String, dynamic>>[];
      for (final task in response) {
        final t = Map<String, dynamic>.from(task);
        if (task['created_by'] != null) {
          t['creator'] = await _teamService.getUserInfo(task['created_by']);
        }
        if (task['assigned_to'] != null) {
          t['assignee'] = await _teamService.getUserInfo(task['assigned_to']);
        }
        processed.add(t);
      }
      return processed;
    } catch (e) {
      debugPrint('Error getting tasks: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getTaskDetails(String taskId) async {
    try {
      if (_client.auth.currentUser == null) return null;

      final task =
          await _client.from('tasks').select('*').eq('id', taskId).single();
      final comments = await _client
          .from('task_comments')
          .select('*')
          .eq('task_id', taskId)
          .order('created_at', ascending: true);

      final commentsWithUsers = <Map<String, dynamic>>[];
      for (final c in comments) {
        commentsWithUsers.add({
          ...c,
          'user': c['user_id'] != null
              ? await _teamService.getUserInfo(c['user_id'])
              : null,
        });
      }

      return {
        'task': {
          ...task,
          'creator': task['created_by'] != null
              ? await _teamService.getUserInfo(task['created_by'])
              : null,
          'assignee': task['assigned_to'] != null
              ? await _teamService.getUserInfo(task['assigned_to'])
              : null,
        },
        'comments': commentsWithUsers,
      };
    } catch (e) {
      debugPrint('Error getting task details: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> createTask({
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedToUserId,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final profile = await _authService.getCurrentUserProfile();
      if (profile == null || profile['team_id'] == null) {
        return {'success': false, 'error': 'User not associated with a team'};
      }

      final data = <String, dynamic>{
        'title': title,
        'description': description,
        'status': 'todo',
        'approval_status': 'pending',
        'team_id': profile['team_id'],
        'created_by': user.id,
      };
      if (assignedToUserId != null && assignedToUserId.isNotEmpty) {
        data['assigned_to'] = assignedToUserId;
      }
      if (dueDate != null) data['due_date'] = dueDate.toIso8601String();

      final res = await _client.from('tasks').insert(data).select();
      if (res.isEmpty) return {'success': false, 'error': 'Failed to create task'};
      return {'success': true, 'task': res[0]};
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
      if (_client.auth.currentUser == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }
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
      final profile = await _authService.getCurrentUserProfile();
      if (profile == null || profile['role'] != 'admin') {
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

  Future<Map<String, dynamic>> addTaskComment({
    required String taskId,
    required String content,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final res = await _client.from('task_comments').insert({
        'task_id': taskId,
        'user_id': user.id,
        'content': content,
      }).select();

      if (res.isEmpty) return {'success': false, 'error': 'Failed to add comment'};
      return {
        'success': true,
        'comment': {...res[0], 'user': await _teamService.getUserInfo(user.id)},
      };
    } catch (e) {
      debugPrint('Error adding task comment: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteTask(String taskId) async {
    try {
      if (_client.auth.currentUser == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      final res =
          await _client.from('tasks').delete().eq('id', taskId).select('id');
      if (res.isEmpty) {
        final check = await _client
            .from('tasks')
            .select('id')
            .eq('id', taskId)
            .maybeSingle();
        return {
          'success': false,
          'error': check != null
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
}
