import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'team_service.dart';

/// Handles all meeting CRUD and exposes a real-time meetings stream.
class MeetingService {
  final SupabaseClient _client;
  final AuthService _authService;
  final TeamService _teamService;

  final _streamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  MeetingService(this._client, this._authService, this._teamService);

  Stream<List<Map<String, dynamic>>> get meetingsStream =>
      _streamController.stream;

  void dispose() => _streamController.close();

  Future<List<Map<String, dynamic>>> getMeetings() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final profile = await _authService.getCurrentUserProfile();
      if (profile == null || profile['team_id'] == null) return [];

      debugPrint('Fetching meetings for team ID: ${profile['team_id']}');

      final response = await _client
          .from('meetings')
          .select('*')
          .eq('team_id', profile['team_id'])
          .order('meeting_date', ascending: true);

      debugPrint('Raw meetings response: ${response.length} meetings found');

      final processed = <Map<String, dynamic>>[];
      for (final meeting in response) {
        final m = Map<String, dynamic>.from(meeting);
        if (meeting['created_by'] != null) {
          m['creator'] = await _teamService.getUserInfo(meeting['created_by']);
        }
        processed.add(m);
      }

      debugPrint('Processed meetings: ${processed.length}');
      _streamController.add(processed);

      return processed;
    } catch (e) {
      debugPrint('Error getting meetings: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getMeetingDetails(String meetingId) async {
    try {
      if (_client.auth.currentUser == null) return null;

      final meeting = await _client
          .from('meetings')
          .select('*')
          .eq('id', meetingId)
          .single();

      return {
        ...meeting,
        'creator': meeting['created_by'] != null
            ? await _teamService.getUserInfo(meeting['created_by'])
            : null,
      };
    } catch (e) {
      debugPrint('Error getting meeting details: $e');
      return null;
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
      final user = _client.auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not authenticated'};

      final profile = await _authService.getCurrentUserProfile();
      if (profile == null || profile['team_id'] == null) {
        return {'success': false, 'error': 'User not associated with a team'};
      }

      final res = await _client.from('meetings').insert({
        'title': title,
        'description': description,
        'meeting_date': meetingDate.toIso8601String(),
        'meeting_url': meetingUrl,
        'team_id': profile['team_id'],
        'created_by': user.id,
        'duration_minutes': durationMinutes,
      }).select();

      if (res.isEmpty) return {'success': false, 'error': 'Failed to create meeting'};

      await getMeetings();
      return {'success': true, 'meeting': res[0]};
    } catch (e) {
      debugPrint('Error creating meeting: $e');
      return {'success': false, 'error': e.toString()};
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
      if (_client.auth.currentUser == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      final data = <String, dynamic>{
        'title': title,
        'description': description,
        'meeting_date': meetingDate.toIso8601String(),
        'meeting_url': meetingUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (transcription != null) data['transcription'] = transcription;
      if (ai_summary != null) data['ai_summary'] = ai_summary;
      if (durationMinutes != null) data['duration_minutes'] = durationMinutes;

      final res = await _client
          .from('meetings')
          .update(data)
          .eq('id', meetingId)
          .select();

      if (res.isEmpty) return {'success': false, 'error': 'Failed to update meeting'};

      await getMeetings();
      return {'success': true, 'meeting': res[0]};
    } catch (e) {
      debugPrint('Error updating meeting: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteMeeting(String meetingId) async {
    try {
      if (_client.auth.currentUser == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }
      await _client.from('meetings').delete().eq('id', meetingId);
      await getMeetings();
      return {'success': true};
    } catch (e) {
      debugPrint('Error deleting meeting: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
