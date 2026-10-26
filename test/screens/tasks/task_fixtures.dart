import 'package:flutter/material.dart';

import '../../support/test_harness.dart';

/// Phone width with room for a card's "Created by" and "Assigned to" row.
const taskPhoneSize = Size(440, 900);

/// A task row as stored in the `tasks` table. Tasks are assigned to the
/// signed-in user by default, because the task list only shows those.
Map<String, dynamic> taskRow(
  String id, {
  String? title = 'Task',
  String? description = 'Details',
  String status = 'todo',
  String approval = 'pending',
  String? createdBy = 'user-2',
  String? assignedTo = FakeBackend.userId,
  String? dueDate = '2026-11-05',
  String? ticketId,
  String createdAt = '2026-10-01T00:00:00Z',
}) =>
    {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'approval_status': approval,
      'team_id': FakeBackend.teamId,
      'created_by': createdBy,
      'assigned_to': assignedTo,
      'due_date': dueDate,
      'ticket_id': ticketId,
      'created_at': createdAt,
    };

/// A ticket row as read by the linked-ticket pickers.
Map<String, dynamic> ticketRow(String id, String number, String title) => {
      'id': id,
      'ticket_number': number,
      'title': title,
      'team_id': FakeBackend.teamId,
      'status': 'open',
      'priority': 'medium',
      'created_by': FakeBackend.userId,
      'created_at': '2026-10-01T00:00:00Z',
    };
