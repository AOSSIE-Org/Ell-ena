/// Optional association between a task and a ticket.
/// An empty value means the task stays unlinked.
class TaskTicketLink {
  const TaskTicketLink._();

  static String? normalizeId(String? ticketId) {
    final value = ticketId?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String labelFor(Map<String, dynamic>? ticket) {
    if (ticket == null) return 'No linked ticket';
    final number = ticket['ticket_number']?.toString();
    final title = ticket['title']?.toString();
    if (number != null && number.isNotEmpty && title != null && title.isNotEmpty) {
      return '$number · $title';
    }
    return title ?? number ?? 'Linked ticket';
  }
}
