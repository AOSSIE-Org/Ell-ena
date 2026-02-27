import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'team_service.dart';

/// Handles all ticket CRUD and exposes a real-time tickets stream.
class TicketService {
  final SupabaseClient _client;
  final AuthService _authService;
  final TeamService _teamService;

  final _streamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  TicketService(this._client, this._authService, this._teamService);

  Stream<List<Map<String, dynamic>>> get ticketsStream =>
      _streamController.stream;

  void dispose() => _streamController.close();

  List<String> getTicketCategories() => [
        'Bug',
        'Feature Request',
        'UI/UX',
        'Performance',
        'Documentation',
        'Security',
        'Other',
      ];

  Future<List<Map<String, dynamic>>> getTickets({
    bool filterByAssignment = false,
    String? filterByStatus,
    String? filterByPriority,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final profile = await _authService.getCurrentUserProfile();
      if (profile == null || profile['team_id'] == null) return [];

      final query = _client
          .from('tickets')
          .select('*')
          .eq('team_id', profile['team_id']);

      if (filterByAssignment) query.eq('assigned_to', user.id);
      if (filterByStatus != null) query.eq('status', filterByStatus);
      if (filterByPriority != null) query.eq('priority', filterByPriority);

      final response = await query.order('created_at', ascending: false);

      final processed = <Map<String, dynamic>>[];
      for (final ticket in response) {
        final t = Map<String, dynamic>.from(ticket);
        if (ticket['created_by'] != null) {
          t['creator'] = await _teamService.getUserInfo(ticket['created_by']);
        }
        if (ticket['assigned_to'] != null) {
          t['assignee'] = await _teamService.getUserInfo(ticket['assigned_to']);
        }
        processed.add(t);
      }
      return processed;
    } catch (e) {
      debugPrint('Error getting tickets: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getTicketDetails(String ticketId) async {
    try {
      if (_client.auth.currentUser == null) return null;

      final ticket = await _client
          .from('tickets')
          .select('*')
          .eq('id', ticketId)
          .single();
      final comments = await _client
          .from('ticket_comments')
          .select('*')
          .eq('ticket_id', ticketId)
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
        'ticket': {
          ...ticket,
          'creator': ticket['created_by'] != null
              ? await _teamService.getUserInfo(ticket['created_by'])
              : null,
          'assignee': ticket['assigned_to'] != null
              ? await _teamService.getUserInfo(ticket['assigned_to'])
              : null,
        },
        'comments': commentsWithUsers,
      };
    } catch (e) {
      debugPrint('Error getting ticket details: $e');
      return null;
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
      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final profile = await _authService.getCurrentUserProfile();
      if (profile == null || profile['team_id'] == null) {
        return {'success': false, 'error': 'User not associated with a team'};
      }

      final data = <String, dynamic>{
        'title': title,
        'description': description,
        'priority': priority,
        'category': category,
        'status': 'open',
        'approval_status': 'pending',
        'team_id': profile['team_id'],
        'created_by': user.id,
      };
      if (assignedToUserId != null && assignedToUserId.isNotEmpty) {
        data['assigned_to'] = assignedToUserId;
      }

      final res = await _client.from('tickets').insert(data).select();
      if (res.isEmpty) return {'success': false, 'error': 'Failed to create ticket'};

      await getTickets();
      return {'success': true, 'ticket': res[0]};
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
      if (_client.auth.currentUser == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }
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
      if (_client.auth.currentUser == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }
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
      final profile = await _authService.getCurrentUserProfile();
      if (profile == null || profile['role'] != 'admin') {
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

  Future<Map<String, dynamic>> addTicketComment({
    required String ticketId,
    required String content,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final res = await _client.from('ticket_comments').insert({
        'ticket_id': ticketId,
        'user_id': user.id,
        'content': content,
      }).select();

      if (res.isEmpty) return {'success': false, 'error': 'Failed to add comment'};
      return {
        'success': true,
        'comment': {...res[0], 'user': await _teamService.getUserInfo(user.id)},
      };
    } catch (e) {
      debugPrint('Error adding ticket comment: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> assignTicket({
    required String ticketId,
    required String userId,
  }) async {
    try {
      if (_client.auth.currentUser == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }
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

  Future<Map<String, dynamic>> deleteTicket(String ticketId) async {
    try {
      if (_client.auth.currentUser == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      final res = await _client
          .from('tickets')
          .delete()
          .eq('id', ticketId)
          .select('id');
      if (res.isEmpty) {
        final check = await _client
            .from('tickets')
            .select('id')
            .eq('id', ticketId)
            .maybeSingle();
        return {
          'success': false,
          'error': check != null
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
}
