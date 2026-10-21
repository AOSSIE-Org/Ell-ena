import 'dart:math';

import 'package:ell_ena/utils/github_sync_ui.dart';
import 'package:ell_ena/utils/task_ticket_link.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/property.dart';

/// Short strings, sometimes wrapped in whitespace.
String padded(Random r) {
  final pad = Gens.oneOf(['', ' ', '  ', '\t', '\n'])(r);
  return '$pad${Gens.string(maxLength: 12)(r)}$pad';
}

void main() {
  group('TaskTicketLink.normalizeId', () {
    property<String?>(
      'trims, turns blanks into null, and is idempotent',
      (r) => Gens.nullable(padded)(r),
      (raw) {
        final id = TaskTicketLink.normalizeId(raw);

        expect(id == null, raw == null || raw.trim().isEmpty);
        if (id != null) {
          expect(id, id.trim());
          expect(raw!.contains(id), isTrue);
        }
        expect(TaskTicketLink.normalizeId(id), id);
      },
    );
  });

  group('TaskTicketLink.labelFor', () {
    property<Map<String, dynamic>?>(
      'is never empty and names the ticket when it can',
      (r) => Gens.nullable((r) => <String, dynamic>{
            'ticket_number':
                Gens.nullable(Gens.oneOf(['', 'TKT-1', 'TKT-99']))(r),
            'title': Gens.nullable(Gens.string(maxLength: 10))(r),
          })(r),
      (ticket) {
        final label = TaskTicketLink.labelFor(ticket);
        final number = ticket?['ticket_number'] as String?;
        final title = ticket?['title'] as String?;

        if (ticket == null) {
          expect(label, 'No linked ticket');
          return;
        }
        if (title != null && title.isNotEmpty) expect(label, contains(title));
        if (number != null &&
            number.isNotEmpty &&
            title != null &&
            title.isNotEmpty) {
          expect(label, '$number · $title');
        }
        if (title == null && number == null) expect(label, 'Linked ticket');
      },
    );
  });

  group('GithubSyncUi', () {
    const labels = {
      'GitHub sync in progress',
      'Synced to GitHub',
      'GitHub sync failed',
      'Not synced to GitHub',
    };
    final statuses = Gens.nullable(Gens.oneOf(
        ['pending', 'synced', 'failed', 'not_requested', 'weird', '']));

    property<String?>(
      'every status has one of the four labels',
      (r) => Gens.nullable(Gens.string(maxLength: 8))(r),
      (status) {
        final label = GithubSyncUi.statusLabel(status);

        expect(labels, contains(label));
        if (!const {'pending', 'synced', 'failed'}.contains(status)) {
          expect(label, 'Not synced to GitHub');
        }
      },
    );

    property<List<Object?>>(
      'the section shows whenever sync was asked for or left a trace',
      (r) => [
        r.nextBool(),
        statuses(r),
        Gens.nullable(Gens.oneOf(['', 'https://github.com/a/b/issues/1']))(r),
      ],
      (input) {
        final requested = input[0] as bool;
        final status = input[1] as String?;
        final url = input[2] as String?;
        final shown = GithubSyncUi.shouldShowSection(
            syncToGithub: requested, status: status, issueUrl: url);

        if (requested) expect(shown, isTrue);
        if (url != null && url.isNotEmpty) expect(shown, isTrue);
        if (!requested &&
            (url == null || url.isEmpty) &&
            !const {'pending', 'synced', 'failed'}.contains(status)) {
          expect(shown, isFalse);
        }
      },
    );

    property<String?>(
      'error messages drop the internal marker and are idempotent',
      (r) {
        if (r.nextInt(5) == 0) return null;
        final parts = Gens.listOf(
          Gens.oneOf(['[ambiguous_create]', 'Rate limited', ' ', 'retry']),
          maxLength: 5,
        )(r);
        return parts.join();
      },
      (raw) {
        final message = GithubSyncUi.userErrorMessage(raw);

        if (raw == null || raw.trim().isEmpty) {
          expect(message, isNull);
          return;
        }
        expect(message, isNot(contains('[ambiguous_create]')));
        expect(message, message!.trim());
        if (message.isNotEmpty) {
          expect(GithubSyncUi.userErrorMessage(message), message);
        }
      },
    );
  });
}
