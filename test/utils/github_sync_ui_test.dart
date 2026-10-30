import 'package:flutter_test/flutter_test.dart';
import 'package:ell_ena/l10n/app_localizations_en.dart';
import 'package:ell_ena/l10n/app_localizations_hi.dart';
import 'package:ell_ena/utils/github_sync_ui.dart';

void main() {
  group('GithubSyncUi', () {
    test('statusLabel maps known statuses', () {
      final l10n = AppLocalizationsEn();
      expect(GithubSyncUi.statusLabel(l10n, 'synced'), 'Synced to GitHub');
      expect(
          GithubSyncUi.statusLabel(l10n, 'pending'), 'GitHub sync in progress');
      expect(GithubSyncUi.statusLabel(l10n, 'failed'), 'GitHub sync failed');
      expect(GithubSyncUi.statusLabel(l10n, 'not_requested'),
          'Not synced to GitHub');
    });

    test('statusLabel follows the app language', () {
      final l10n = AppLocalizationsHi();
      expect(GithubSyncUi.statusLabel(l10n, 'synced'), l10n.ticketGithubSynced);
      expect(GithubSyncUi.statusLabel(l10n, 'synced'),
          isNot(AppLocalizationsEn().ticketGithubSynced));
    });

    test('shouldShowSection for sync intent and statuses', () {
      expect(
        GithubSyncUi.shouldShowSection(
          syncToGithub: true,
          status: 'not_requested',
        ),
        isTrue,
      );
      expect(
        GithubSyncUi.shouldShowSection(
          syncToGithub: false,
          status: 'synced',
          issueUrl: 'https://github.com/acme/app/issues/1',
        ),
        isTrue,
      );
      expect(
        GithubSyncUi.shouldShowSection(
          syncToGithub: false,
          status: 'not_requested',
        ),
        isFalse,
      );
    });

    test('userErrorMessage strips ambiguous marker', () {
      expect(
        GithubSyncUi.userErrorMessage(
          '[ambiguous_create] timeout. A GitHub issue may already have been created',
        ),
        'timeout. A GitHub issue may already have been created',
      );
      expect(GithubSyncUi.userErrorMessage(null), isNull);
    });
  });
}
