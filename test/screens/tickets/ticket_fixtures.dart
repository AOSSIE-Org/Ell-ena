import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

/// A ticket row as stored in the `tickets` table.
Map<String, dynamic> ticketRow({
  String id = 'tk-1',
  String? number = 'TKT-001',
  String? title = 'Login crash',
  String? description = 'App crashes on login',
  String priority = 'high',
  String category = 'Bug',
  String status = 'open',
  String approval = 'pending',
  String? createdBy = 'user-2',
  String? assignedTo = FakeBackend.userId,
  String? createdAt = '2026-10-01T10:05:00Z',
  Map<String, dynamic> extra = const {},
}) =>
    {
      'id': id,
      'ticket_number': number,
      'title': title,
      'description': description,
      'priority': priority,
      'category': category,
      'status': status,
      'approval_status': approval,
      'team_id': FakeBackend.teamId,
      'created_by': createdBy,
      'assigned_to': assignedTo,
      'created_at': createdAt,
      ...extra,
    };

/// [settle] plus time for a page transition to finish.
Future<void> settleRoute(WidgetTester tester) async {
  await settle(tester);
  await tester.pump(const Duration(seconds: 1));
  await settle(tester);
}
