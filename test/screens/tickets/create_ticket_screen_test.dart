import 'package:ell_ena/screens/tickets/create_ticket_screen.dart';
import 'package:ell_ena/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  setUpAll(setUpFakeSupabase);
  setUp(resetFakeSupabase);

  Future<void> fillForm(WidgetTester tester) async {
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'), '  Broken export  ');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'), 'CSV is empty');
  }

  testWidgets('lists team members and defaults to medium Bug, unassigned',
      (tester) async {
    await pumpPushed(tester, const CreateTicketScreen());

    expect(find.text('Create Ticket'), findsWidgets);
    expect(find.text('Bug'), findsOneWidget);
    // The "Unassigned" entry matches the empty selection, so it shows
    // instead of the hint.
    expect(find.text('Unassigned'), findsOneWidget);

    await tester.tap(find.text('Unassigned'));
    await settle(tester);
    expect(find.text('Unassigned'), findsWidgets);
    expect(find.text('Ada'), findsWidgets);
    expect(find.text('Bob'), findsWidgets);
    // Only the admin carries the role badge.
    expect(find.text('Admin'), findsWidgets);
  });

  testWidgets('empty form shows both validation errors and sends nothing',
      (tester) async {
    final result = await pumpPushed(tester, const CreateTicketScreen());

    await tester.tap(find.byTooltip('Create Ticket'));
    await settle(tester);

    expect(find.text('Please enter a title'), findsOneWidget);
    expect(find.text('Please enter a description'), findsOneWidget);
    expect(backend.bodiesFor('POST', '/rest/v1/tickets'), isEmpty);
    expect(result.popped, isFalse);
  });

  testWidgets('submits the chosen fields, syncs to GitHub, and pops true',
      (tester) async {
    backend.functions['github-sync'] = (body) {
      final row = backend
          .table('tickets')
          .firstWhere((t) => t['id'] == body['ticket_id']);
      row['github_sync_status'] = 'synced';
      return {'ok': true};
    };
    final result = await pumpPushed(tester, const CreateTicketScreen());
    await fillForm(tester);

    await tester.tap(find.text('High'));
    await tester.pump();

    await tester.tap(find.text('Bug'));
    await settle(tester);
    await tester.tap(find.text('Security').last);
    await settle(tester);

    await tester.tap(find.text('Unassigned'));
    await settle(tester);
    await tester.tap(find.text('Bob').last);
    await settle(tester);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    await tester.ensureVisible(find.byType(ElevatedButton));
    await tester.tap(find.byType(ElevatedButton));
    await settle(tester);

    final body = backend.bodiesFor('POST', '/rest/v1/tickets').single as Map;
    expect(body['title'], 'Broken export');
    expect(body['description'], 'CSV is empty');
    expect(body['priority'], 'high');
    expect(body['category'], 'Security');
    expect(body['assigned_to'], 'user-2');
    expect(body['sync_to_github'], isTrue);
    expect(body['status'], 'open');
    expect(body['approval_status'], 'pending');
    expect(backend.functionBodies('github-sync').single,
        {'ticket_id': backend.table('tickets').single['id']});
    expect(result.popped, isTrue);
    expect(result.value, isTrue);
  });

  testWidgets('every category has a localised label', (tester) async {
    await pumpPushed(tester, const CreateTicketScreen());

    await tester.tap(find.text('Bug'));
    await settle(tester);
    for (final label in const [
      'Feature Request',
      'UI/UX',
      'Performance',
      'Documentation',
      'Security',
      'Other',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    await tester.tap(find.text('Feature Request').last);
    await settle(tester);
    expect(find.text('Feature Request'), findsOneWidget);
  });

  testWidgets('choosing low then unassigned sends no assignee', (tester) async {
    await pumpPushed(tester, const CreateTicketScreen());
    await fillForm(tester);

    await tester.tap(find.text('Low'));
    await tester.pump();
    await tester.tap(find.text('Unassigned'));
    await settle(tester);
    await tester.tap(find.text('Unassigned').last);
    await settle(tester);

    await tester.tap(find.byTooltip('Create Ticket'));
    await settle(tester);

    final body = backend.bodiesFor('POST', '/rest/v1/tickets').single as Map;
    expect(body['priority'], 'low');
    expect(body.containsKey('assigned_to'), isFalse);
    expect(body['sync_to_github'], isFalse);
    expect(backend.log.where((e) => e.endsWith('/functions/v1/github-sync')),
        isEmpty);
  });

  testWidgets('a failed insert keeps the form open and reports the error',
      (tester) async {
    final result = await pumpPushed(tester, const CreateTicketScreen());
    await fillForm(tester);
    backend.failures['tickets'] = 500;

    await tester.tap(find.byTooltip('Create Ticket'));
    await settle(tester);

    expect(find.textContaining('Failed to create ticket:'), findsOneWidget);
    expect(result.popped, isFalse);
    // The form is back and can be submitted again.
    expect(find.byTooltip('Create Ticket'), findsOneWidget);
  });

  testWidgets('a user without a team gets no assignee choices', (tester) async {
    backend.table('users').first['team_id'] = null;
    await SupabaseService().getCurrentUserProfile(forceRefresh: true);

    await pumpPushed(tester, const CreateTicketScreen());
    await tester.tap(find.text('Unassigned'));
    await settle(tester);

    expect(find.text('Unassigned'), findsWidgets);
    expect(find.text('Bob'), findsNothing);
  });

  testWidgets('a member without a stored name is listed as Unknown',
      (tester) async {
    backend.table('users')
      ..first['team_id'] = FakeBackend.secondTeamId
      ..add({
        'id': 'user-3',
        'full_name': null,
        'team_id': FakeBackend.secondTeamId,
      });
    await SupabaseService().getCurrentUserProfile(forceRefresh: true);

    await pumpPushed(tester, const CreateTicketScreen());
    await tester.tap(find.text('Unassigned'));
    await settle(tester);

    expect(find.text('Unknown'), findsWidgets);
    expect(find.text('?'), findsWidgets);
    // Bob stayed in the other team.
    expect(find.text('Bob'), findsNothing);
  });
}
