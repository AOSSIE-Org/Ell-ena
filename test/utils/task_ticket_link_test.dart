import 'package:ell_ena/utils/task_ticket_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty ticket id stays unlinked', () {
    expect(TaskTicketLink.normalizeId(null), isNull);
    expect(TaskTicketLink.normalizeId(''), isNull);
    expect(TaskTicketLink.normalizeId('   '), isNull);
  });

  test('a selected ticket id is preserved', () {
    expect(
      TaskTicketLink.normalizeId(' 6d2f1c4a-1b2c-4d3e-8f90-123456789abc '),
      '6d2f1c4a-1b2c-4d3e-8f90-123456789abc',
    );
  });

  test('linked ticket label uses number and title', () {
    expect(
      TaskTicketLink.labelFor({
        'ticket_number': 'ELL-004',
        'title': 'Login bug',
      }),
      'ELL-004 · Login bug',
    );
    expect(TaskTicketLink.labelFor(null), 'No linked ticket');
  });
}
