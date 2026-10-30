import '../l10n/app_localizations.dart';

/// User-facing labels for ticket GitHub sync fields (no secrets).
class GithubSyncUi {
  const GithubSyncUi._();

  static String statusLabel(AppLocalizations l10n, String? status) {
    switch (status) {
      case 'pending':
        return l10n.ticketGithubSyncPending;
      case 'synced':
        return l10n.ticketGithubSynced;
      case 'failed':
        return l10n.ticketGithubSyncStatusFailed;
      case 'not_requested':
      default:
        return l10n.ticketGithubNotSynced;
    }
  }

  static bool shouldShowSection({
    required bool syncToGithub,
    required String? status,
    String? issueUrl,
  }) {
    if (syncToGithub) return true;
    if (issueUrl != null && issueUrl.isNotEmpty) return true;
    return status == 'pending' || status == 'synced' || status == 'failed';
  }

  /// Safe message for UI — never include raw backend internals beyond stored error.
  static String? userErrorMessage(String? githubSyncError) {
    if (githubSyncError == null || githubSyncError.trim().isEmpty) {
      return null;
    }
    // Strip internal ambiguous marker for display.
    return githubSyncError
        .replaceAll('[ambiguous_create]', '')
        .trim();
  }
}
