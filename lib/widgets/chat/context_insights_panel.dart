import 'package:ell_ena/models/rag_result.dart';
import 'package:ell_ena/providers/chat/chat_controller.dart';
import 'package:ell_ena/widgets/chat/rag_result_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Groups [results] by entity type while preserving hybrid-ranking order
/// within each section.
Map<RagEntityType, List<RagResult>> groupRagResultsByType(
  List<RagResult> results,
) {
  final grouped = <RagEntityType, List<RagResult>>{
    RagEntityType.task: [],
    RagEntityType.ticket: [],
    RagEntityType.meeting: [],
  };

  for (final result in results) {
    switch (result.entityType) {
      case RagEntityType.task:
        grouped[RagEntityType.task]!.add(result);
        break;
      case RagEntityType.ticket:
        grouped[RagEntityType.ticket]!.add(result);
        break;
      case RagEntityType.meeting:
        grouped[RagEntityType.meeting]!.add(result);
        break;
      case RagEntityType.unknown:
        break;
    }
  }

  return grouped;
}

/// Conversation-scoped RAG insights shown beside chat on wide layouts.
class ContextInsightsPanel extends ConsumerWidget {
  final void Function(RagResult result)? onResultTap;

  const ContextInsightsPanel({
    super.key,
    this.onResultTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatControllerProvider);
    return _ContextInsightsBody(
      retrievalStatus: chatState.retrievalStatus,
      results: chatState.retrievalResults,
      errorMessage: chatState.retrievalError,
      onResultTap: onResultTap,
    );
  }
}

/// Pure presentation layer for tests without Riverpod.
class ContextInsightsBody extends StatelessWidget {
  final RagRetrievalStatus retrievalStatus;
  final List<RagResult> results;
  final String? errorMessage;
  final void Function(RagResult result)? onResultTap;

  const ContextInsightsBody({
    super.key,
    required this.retrievalStatus,
    required this.results,
    this.errorMessage,
    this.onResultTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ContextInsightsBody(
      retrievalStatus: retrievalStatus,
      results: results,
      errorMessage: errorMessage,
      onResultTap: onResultTap,
    );
  }
}

class _ContextInsightsBody extends StatelessWidget {
  final RagRetrievalStatus retrievalStatus;
  final List<RagResult> results;
  final String? errorMessage;
  final void Function(RagResult result)? onResultTap;

  const _ContextInsightsBody({
    required this.retrievalStatus,
    required this.results,
    this.errorMessage,
    this.onResultTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.insights, size: 20, color: Colors.green.shade400),
                const SizedBox(width: 8),
                Text(
                  'Context',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (retrievalStatus == RagRetrievalStatus.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );
    }

    if (retrievalStatus == RagRetrievalStatus.error) {
      return _StatusMessage(
        icon: Icons.error_outline,
        iconColor: Colors.red.shade400,
        title: 'Could not load context',
        message: errorMessage ?? 'Try sending your message again.',
      );
    }

    if (retrievalStatus == RagRetrievalStatus.idle) {
      return const _StatusMessage(
        icon: Icons.search,
        title: 'No context yet',
        message: 'Send a message to find related tasks, tickets, and meetings.',
      );
    }

    if (results.isEmpty || retrievalStatus == RagRetrievalStatus.empty) {
      return const _StatusMessage(
        icon: Icons.inbox_outlined,
        title: 'No matches found',
        message:
            'Nothing in your workspace matched this message closely enough.',
      );
    }

    final grouped = groupRagResultsByType(results);
    final sections = <_InsightsSection>[
      _InsightsSection(
        title: 'Tasks',
        icon: Icons.task_alt,
        results: grouped[RagEntityType.task]!,
      ),
      _InsightsSection(
        title: 'Tickets',
        icon: Icons.confirmation_number_outlined,
        results: grouped[RagEntityType.ticket]!,
      ),
      _InsightsSection(
        title: 'Meetings',
        icon: Icons.event,
        results: grouped[RagEntityType.meeting]!,
      ),
    ].where((section) => section.results.isNotEmpty).toList();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: sections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final section = sections[index];
        return _InsightsSectionView(
          section: section,
          onResultTap: onResultTap,
        );
      },
    );
  }
}

class _InsightsSection {
  final String title;
  final IconData icon;
  final List<RagResult> results;

  const _InsightsSection({
    required this.title,
    required this.icon,
    required this.results,
  });
}

class _InsightsSectionView extends StatelessWidget {
  final _InsightsSection section;
  final void Function(RagResult result)? onResultTap;

  const _InsightsSectionView({
    required this.section,
    this.onResultTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(section.icon, size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                section.title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${section.results.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ...section.results.map(
          (result) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RagResultTile(
              result: result,
              onTap: onResultTap != null && result.entityId.isNotEmpty
                  ? () => onResultTap!(result)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String message;

  const _StatusMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: iconColor ?? colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
