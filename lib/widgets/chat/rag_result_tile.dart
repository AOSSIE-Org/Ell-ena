import 'package:ell_ena/models/rag_result.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One ranked RAG row for the chat insights sidebar.
class RagResultTile extends StatelessWidget {
  final RagResult result;
  final VoidCallback? onTap;

  const RagResultTile({
    super.key,
    required this.result,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EntityIcon(type: result.entityType),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (_subtitle().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _subtitle(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[];
    switch (result.entityType) {
      case RagEntityType.task:
        if (result.status != null && result.status!.isNotEmpty) {
          parts.add(result.status!);
        }
        if (result.dueDate != null) {
          parts.add('Due ${_formatDate(result.dueDate!)}');
        }
        break;
      case RagEntityType.ticket:
        if (result.priority != null && result.priority!.isNotEmpty) {
          parts.add(result.priority!);
        }
        if (result.status != null && result.status!.isNotEmpty) {
          parts.add(result.status!);
        }
        break;
      case RagEntityType.meeting:
        if (result.meetingDate != null) {
          parts.add(_formatDateTime(result.meetingDate!));
        }
        break;
      case RagEntityType.unknown:
        break;
    }

    if (parts.isEmpty) {
      final preview = _contentPreview();
      if (preview.isNotEmpty) return preview;
    }

    return parts.join(' · ');
  }

  String _contentPreview() {
    final text = result.content?.trim();
    if (text == null || text.isEmpty) return '';
    if (text.length <= 80) return text;
    return '${text.substring(0, 80)}…';
  }

  static String _formatDate(DateTime date) =>
      DateFormat.yMMMd().format(date.toLocal());

  static String _formatDateTime(DateTime date) =>
      DateFormat('MMM d, y · h:mm a').format(date.toLocal());
}

class _EntityIcon extends StatelessWidget {
  final RagEntityType type;

  const _EntityIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    late final IconData icon;
    late final Color color;

    switch (type) {
      case RagEntityType.task:
        icon = Icons.task_alt;
        color = Colors.blue.shade400;
        break;
      case RagEntityType.ticket:
        icon = Icons.confirmation_number_outlined;
        color = Colors.orange.shade400;
        break;
      case RagEntityType.meeting:
        icon = Icons.event;
        color = Colors.purple.shade400;
        break;
      case RagEntityType.unknown:
        icon = Icons.article_outlined;
        color = colorScheme.onSurfaceVariant;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
