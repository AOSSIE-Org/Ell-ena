import 'package:flutter_test/flutter_test.dart';
import 'package:ell_ena/utils/github_sync_ui.dart';

void main() {
  group('GithubSyncUi', () {
    test('statusLabel maps known statuses', () {
      expect(GithubSyncUi.statusLabel('synced'), 'Synced to GitHub');
      expect(GithubSyncUi.statusLabel('pending'), 'GitHub sync in progress');
      expect(GithubSyncUi.statusLabel('failed'), 'GitHub sync failed');
      expect(GithubSyncUi.statusLabel('not_requested'), 'Not synced to GitHub');
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
