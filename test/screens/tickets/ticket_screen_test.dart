import 'package:ell_ena/screens/tickets/create_ticket_screen.dart';
import 'package:ell_ena/screens/tickets/ticket_detail_screen.dart';
import 'package:ell_ena/screens/tickets/ticket_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import 'ticket_fixtures.dart';

void main() {
  setUpAll(setUpFakeSupabase);
  setUp(resetFakeSupabase);

  Future<void> pumpTickets(
    WidgetTester tester, {
    Size size = phoneSize,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await pumpApp(tester, TicketScreen(key: TicketScreen.globalKey),
        size: size, themeMode: themeMode);
    await settle(tester);
  }

  void seed(List<Map<String, dynamic>> rows) =>
      backend.table('tickets').addAll(rows);

  Finder tab(String label) => find.descendant(
        of: find.byType(DragTarget<Map<String, dynamic>>),
        matching: find.text(label),
      );

  group('phone', () {
    testWidgets('header shares and open list reflect the team tickets',
        (tester) async {
      seed([
        ticketRow(id: 'a', title: 'Crash A'),
        ticketRow(id: 'b', title: 'Crash B', number: 'TKT-002'),
        ticketRow(id: 'c', title: 'Slow page', status: 'in_progress'),
        ticketRow(id: 'd', title: 'Typo', status: 'resolved'),
      ]);
      await pumpTickets(tester);

      // 2 of 4 open, 1 in progress, 1 resolved.
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('25%'), findsNWidgets(2));
      expect(find.text('Crash A'), findsOneWidget);
      expect(find.text('Crash B'), findsOneWidget);
      expect(find.text('Slow page'), findsNothing);
      expect(find.text('TKT-002'), findsOneWidget);
      expect(find.text('Created by Bob'), findsNWidgets(2));
      expect(find.text('Drag to change status'), findsNWidgets(2));
      expect(find.byTooltip('New Ticket'), findsOneWidget);

      await tester.tap(tab('In Progress'));
      await tester.pump();
      expect(find.text('Slow page'), findsOneWidget);
      expect(find.text('Crash A'), findsNothing);

      await tester.tap(tab('Resolved'));
      await tester.pump();
      expect(find.text('Typo'), findsOneWidget);
    });

    testWidgets('empty tabs explain themselves and link to the next status',
        (tester) async {
      await pumpTickets(tester);

      expect(find.text('0%'), findsNWidgets(3));
      expect(find.text('No tickets found'), findsOneWidget);
      expect(find.text('Create new tickets to get started'), findsOneWidget);

      await tester.tap(find.text('View In Progress Tickets'));
      await tester.pump();
      expect(find.text('Move tickets here when you start working on them'),
          findsOneWidget);

      await tester.tap(find.text('View Resolved Tickets'));
      await tester.pump();
      expect(find.text('Resolved tickets will appear here'), findsOneWidget);

      await tester.tap(find.text('View Open Tickets'));
      await tester.pump();
      expect(find.text('Create new tickets to get started'), findsOneWidget);
    });

    testWidgets('cards cover every priority, category, and missing field',
        (tester) async {
      final longText = List.filled(80, 'word').join(' ');
      seed([
        ticketRow(id: '1', title: 'P-high', priority: 'high', category: 'Bug'),
        ticketRow(
            id: '2',
            title: 'P-medium',
            priority: 'medium',
            category: 'Feature Request'),
        ticketRow(id: '3', title: 'P-low', priority: 'low', category: 'UI/UX'),
        ticketRow(
            id: '4',
            title: 'P-odd',
            priority: 'urgent',
            category: 'Performance',
            approval: 'approved'),
        ticketRow(
            id: '5',
            title: 'C-docs',
            category: 'Documentation',
            approval: 'rejected'),
        ticketRow(
            id: '6',
            title: 'C-sec',
            category: 'Security',
            createdBy: FakeBackend.userId),
        ticketRow(id: '7', title: 'C-misc', category: 'Misc'),
        ticketRow(
          id: '8',
          number: null,
          title: null,
          description: longText,
          createdBy: 'ghost',
          createdAt: 'not-a-date',
        ),
        ticketRow(
            id: '9',
            title: 'No creator',
            description: null,
            createdBy: null,
            createdAt: null),
      ]);
      await pumpTickets(tester, size: const Size(400, 6000));

      for (final label in const ['HIGH', 'MEDIUM', 'LOW', 'URGENT']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.byIcon(Icons.bug_report), findsWidgets);
      expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
      expect(find.byIcon(Icons.design_services), findsOneWidget);
      expect(find.byIcon(Icons.speed), findsOneWidget);
      expect(find.byIcon(Icons.description), findsOneWidget);
      expect(find.byIcon(Icons.security), findsOneWidget);
      expect(find.byIcon(Icons.category), findsOneWidget);
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
      expect(find.text('APPROVED'), findsOneWidget);
      expect(find.text('REJECTED'), findsOneWidget);
      expect(find.text('Created by You'), findsOneWidget);
      expect(find.text('Untitled Ticket'), findsOneWidget);
      expect(find.text('TKT-???'), findsOneWidget);
      // Unknown creators fall back to the team-member placeholder.
      expect(find.text('Created by Team Member'), findsOneWidget);
      expect(find.text('Created by Unknown'), findsOneWidget);
      expect(find.text('No description'), findsOneWidget);
      expect(
          find.text('${List.filled(75, 'word').join(' ')}...'), findsOneWidget);
      expect(find.text('1/10/2026'), findsWidgets);
    });

    testWidgets('admins approve and reject pending tickets', (tester) async {
      seed([
        ticketRow(id: 'a', title: 'Pending A'),
        ticketRow(id: 'b', title: 'Done B', approval: 'approved'),
      ]);
      await pumpTickets(tester);

      // Only the pending ticket offers approval.
      expect(find.byTooltip('Approve'), findsOneWidget);
      await tester.tap(find.byTooltip('Approve'));
      await settle(tester);
      expect(backend.bodiesFor('PATCH', '/rest/v1/tickets').single,
          {'approval_status': 'approved'});
      expect(backend.table('tickets').first['approval_status'], 'approved');
      expect(find.byTooltip('Approve'), findsNothing);

      backend.table('tickets').first['approval_status'] = 'pending';
      TicketScreen.refreshTickets();
      await settle(tester);
      await tester.tap(find.byTooltip('Reject'));
      await settle(tester);
      expect(backend.bodiesFor('PATCH', '/rest/v1/tickets').last,
          {'approval_status': 'rejected'});
      expect(find.text('REJECTED'), findsOneWidget);
    });

    testWidgets('a failed approval shows the error', (tester) async {
      seed([ticketRow(id: 'a', title: 'Pending A')]);
      await pumpTickets(tester);

      backend.failures['tickets'] = 500;
      await tester.tap(find.byTooltip('Approve'));
      await settle(tester);

      expect(find.textContaining('Error updating ticket approval'),
          findsOneWidget);
      expect(backend.table('tickets').single['approval_status'], 'pending');
    });

    testWidgets('members see no approval and delete only their own tickets',
        (tester) async {
      await resetInTest(tester, role: 'member');
      seed([
        ticketRow(id: 'a', title: 'Mine', createdBy: FakeBackend.userId),
        ticketRow(id: 'b', title: 'Theirs'),
      ]);
      await pumpTickets(tester);

      expect(find.text('Mine'), findsOneWidget);
      expect(find.text('Theirs'), findsOneWidget);
      expect(find.byTooltip('Approve'), findsNothing);
      expect(find.byTooltip('Delete'), findsOneWidget);
    });

    testWidgets('delete asks first and refreshes the list', (tester) async {
      seed([ticketRow(id: 'a', title: 'Doomed')]);
      await pumpTickets(tester);

      await tester.tap(find.byTooltip('Delete'));
      await settle(tester);
      expect(find.text('Delete Ticket'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(backend.table('tickets'), hasLength(1));

      await tester.tap(find.byTooltip('Delete'));
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await settle(tester);

      expect(backend.table('tickets'), isEmpty);
      expect(find.text('Ticket deleted successfully'), findsOneWidget);
      expect(find.text('Doomed'), findsNothing);
      expect(find.text('No tickets found'), findsOneWidget);
    });

    testWidgets('a failed delete keeps the ticket and shows the error',
        (tester) async {
      seed([ticketRow(id: 'a', title: 'Sticky')]);
      await pumpTickets(tester);

      backend.failures['tickets'] = 500;
      await tester.tap(find.byTooltip('Delete'));
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await settle(tester);

      expect(find.textContaining('forced failure'), findsOneWidget);
      expect(find.text('Sticky'), findsOneWidget);
    });

    testWidgets('dragging a card onto a status tab moves the ticket',
        (tester) async {
      seed([ticketRow(id: 'a', title: 'Movable')]);
      await pumpTickets(tester);

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Movable')));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(tab('In Progress')));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(tab('In Progress')));
      await tester.pump();
      await gesture.up();
      await settle(tester);

      expect(backend.bodiesFor('PATCH', '/rest/v1/tickets').single,
          {'status': 'in_progress'});
      expect(backend.table('tickets').single['status'], 'in_progress');
      expect(find.text('Movable'), findsNothing);
    });

    testWidgets('a status drag the database ignores reports a failure',
        (tester) async {
      seed([ticketRow(id: 'a', title: 'Movable')]);
      await pumpTickets(tester);

      // Someone else removed the row: the update matches nothing.
      backend.table('tickets').clear();
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Movable')));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(tab('In Progress')));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(tab('In Progress')));
      await tester.pump();
      await gesture.up();
      await settle(tester);

      expect(find.textContaining('Error updating ticket status'),
          findsOneWidget);
    });

    testWidgets('dropping a card on its own status changes nothing',
        (tester) async {
      seed([ticketRow(id: 'a', title: 'Stay')]);
      await pumpTickets(tester);

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Stay')));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(tab('Open')));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(tab('Open')));
      await tester.pump();
      await gesture.up();
      await settle(tester);

      expect(backend.bodiesFor('PATCH', '/rest/v1/tickets'), isEmpty);
      expect(find.text('Stay'), findsOneWidget);
    });

    testWidgets('a long-press reorder sends nothing and keeps the new order',
        (tester) async {
      seed([
        ticketRow(id: 'a', title: 'First'),
        ticketRow(id: 'b', title: 'Second', number: 'TKT-002'),
      ]);
      await pumpTickets(tester, size: const Size(400, 1400));
      expect(tester.getTopLeft(find.text('First')).dy,
          lessThan(tester.getTopLeft(find.text('Second')).dy));

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('First')));
      await tester.pump(const Duration(milliseconds: 700));
      final below =
          tester.getBottomLeft(find.text('Second')) + const Offset(0, 120);
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(
          Offset.lerp(
              tester.getCenter(find.text('First').first), below, i / 10)!,
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await settleRoute(tester);

      // The new order stays on screen; order isn't stored server-side.
      expect(tester.getTopLeft(find.text('First')).dy,
          greaterThan(tester.getTopLeft(find.text('Second')).dy));
      expect(backend.bodiesFor('PATCH', '/rest/v1/tickets'), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a card opens the detail page and refreshes on return',
        (tester) async {
      seed([ticketRow(id: 'a', title: 'Open me')]);
      await pumpTickets(tester);

      await tester.tap(find.text('Open me'));
      await settle(tester);
      expect(find.byType(TicketDetailScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert));
      await settle(tester);
      await tester.tap(find.text('Delete Ticket').last);
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await settleRoute(tester);

      expect(find.byType(TicketDetailScreen), findsNothing);
      expect(find.text('Open me'), findsNothing);
      expect(find.text('No tickets found'), findsOneWidget);
    });

    testWidgets('the add button creates a ticket and shows it', (tester) async {
      await pumpTickets(tester);

      await tester.tap(find.byTooltip('New Ticket'));
      await settle(tester);
      expect(find.byType(CreateTicketScreen), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Title'), 'Fresh ticket');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Description'), 'Details');
      await tester.tap(find.byTooltip('Create Ticket'));
      await settleRoute(tester);

      expect(find.byType(CreateTicketScreen), findsNothing);
      expect(find.text('Ticket created successfully'), findsOneWidget);
      expect(backend.table('tickets').single['title'], 'Fresh ticket');
    });

    testWidgets('leaving the create page without saving changes nothing',
        (tester) async {
      await pumpTickets(tester);

      await tester.tap(find.byTooltip('New Ticket'));
      await settle(tester);
      await tester.tap(find.byType(CloseButton));
      await settleRoute(tester);

      expect(find.byType(CreateTicketScreen), findsNothing);
      expect(find.text('Ticket created successfully'), findsNothing);
    });

    testWidgets('renders in dark mode', (tester) async {
      seed([ticketRow(id: 'a', title: 'Night ticket')]);
      await pumpTickets(tester, themeMode: ThemeMode.dark);

      expect(find.text('Night ticket'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('without the shared key it still loads', (tester) async {
      seed([ticketRow(id: 'a', title: 'Keyless')]);
      await pumpApp(tester, const TicketScreen());
      await settle(tester);

      expect(find.text('Keyless'), findsOneWidget);
    });
  });

  group('wide', () {
    testWidgets('lists tickets as table rows without the add button',
        (tester) async {
      seed([
        ticketRow(id: 'a', title: 'Row ticket', priority: 'low'),
        ticketRow(
            id: 'b',
            title: 'Mine',
            createdBy: FakeBackend.userId,
            approval: 'approved'),
      ]);
      await pumpTickets(tester, size: wideSize);

      for (final heading in const [
        'Priority',
        'Ticket',
        'Title',
        'Category',
        'Approval',
        'Created by',
        'Created',
      ]) {
        expect(find.text(heading), findsOneWidget, reason: heading);
      }
      expect(find.text('Row ticket'), findsOneWidget);
      expect(find.text('App crashes on login'), findsNWidgets(2));
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.byTooltip('New Ticket'), findsNothing);
      // Cards' drag hint text is replaced by a tooltip on the handle.
      expect(find.byTooltip('Drag to change status'), findsNWidgets(2));
      expect(find.byTooltip('Approve'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsNWidgets(2));
    });

    testWidgets('approving and rejecting from a row', (tester) async {
      seed([ticketRow(id: 'a', title: 'Needs review')]);
      await pumpTickets(tester, size: wideSize);

      await tester.tap(find.byTooltip('Reject'));
      await settle(tester);
      expect(backend.bodiesFor('PATCH', '/rest/v1/tickets').single,
          {'approval_status': 'rejected'});

      backend.table('tickets').single['approval_status'] = 'pending';
      TicketScreen.refreshTickets();
      await settle(tester);
      await tester.tap(find.byTooltip('Approve'));
      await settle(tester);
      expect(backend.bodiesFor('PATCH', '/rest/v1/tickets').last,
          {'approval_status': 'approved'});
    });

    testWidgets('deleting from a row', (tester) async {
      seed([ticketRow(id: 'a', title: 'Row to delete')]);
      await pumpTickets(tester, size: wideSize);

      await tester.tap(find.byTooltip('Delete'));
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await settle(tester);

      expect(backend.table('tickets'), isEmpty);
      expect(find.text('Row to delete'), findsNothing);
    });

    testWidgets('a row opens the side panel and closing it reloads quietly',
        (tester) async {
      // The progress bar is sized from the window, not the list, so it
      // overflows beside the panel when it is full. Archived tickets count
      // toward the total without filling the bar.
      seed([
        ticketRow(id: 'a', title: 'Panel ticket'),
        ticketRow(id: 'b', title: 'Other ticket', number: 'TKT-002'),
        ticketRow(id: 'c', status: 'archived'),
        ticketRow(id: 'd', status: 'archived'),
      ]);
      await pumpTickets(tester, size: wideSize);

      await tester.tap(find.text('Panel ticket'));
      await settle(tester);
      expect(find.byType(TicketDetailScreen), findsOneWidget);
      // The panel's app bar shows the ticket number.
      expect(find.text('TKT-001'), findsNWidgets(2));

      await tester.tap(find.text('Other ticket'));
      await settleRoute(tester);
      expect(find.text('TKT-002'), findsNWidgets(2));

      final ticketGets =
          backend.log.where((e) => e == 'GET /rest/v1/tickets').length;
      await tester.tap(find.byType(CloseButton));
      await settleRoute(tester);

      expect(find.byType(TicketDetailScreen), findsNothing);
      expect(backend.log.where((e) => e == 'GET /rest/v1/tickets').length,
          greaterThan(ticketGets));
      expect(find.text('Panel ticket'), findsOneWidget);
    });

    testWidgets('the top bar action opens the create dialog', (tester) async {
      await pumpTickets(tester, size: wideSize);

      TicketScreen.openCreateTicket();
      await settle(tester);

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(CreateTicketScreen), findsOneWidget);
    });

    testWidgets('dragging a row onto a tab resolves the ticket',
        (tester) async {
      seed([ticketRow(id: 'a', title: 'Row drag')]);
      await pumpTickets(tester, size: wideSize);

      final gesture = await tester.startGesture(
          tester.getCenter(find.byTooltip('Drag to change status')));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(tab('Resolved')));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(tab('Resolved')));
      await tester.pump();
      await gesture.up();
      await settle(tester);

      expect(backend.table('tickets').single['status'], 'resolved');
    });
  });
}
