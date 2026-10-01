import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('self-hosted account deletion is available in-app and on the Worker web route', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final syncService = File('lib/sync_services.dart').readAsStringSync();
    final worker = File('cloud/worker/src/index.ts').readAsStringSync();
    final deletePage = File('cloud/worker/src/delete_account.ts').readAsStringSync();

    expect(mainSource, contains('Delete account'));
    expect(mainSource, contains('deleteCurrentSyncAccount'));
    expect(mainSource, contains('Also delete local data from this device'));
    expect(mainSource, contains("confirmation: 'DELETE'"));
    expect(mainSource, contains("deletionResult['wasAdministrator'] == true"));
    expect(mainSource, contains('WorkerDeploymentCredentialStore().clear(workerUrl: deletedWorkerUrl)'));
    expect(syncService, contains("'/v1/auth/account'"));
    expect(worker, contains("'/delete-account'"));
    expect(worker, contains("accountDeletionAvailable: true"));
    expect(worker, contains('deleteOwnAccount'));
    expect(deletePage, contains('Type DELETE to confirm'));
    expect(deletePage, contains('Permanently delete account'));
  });

  test('public account deletion gateway works without app credentials', () {
    final publicPage = File('docs/delete-account/index.html').readAsStringSync();
    final config = File('lib/app_config.dart').readAsStringSync();
    final pagesWorkflow = File('.github/workflows/deploy-public-pages.yml').readAsStringSync();

    expect(publicPage, contains('Delete your Yutaka account'));
    expect(publicPage, contains('id="worker-url"'));
    expect(publicPage, contains("new URL('/delete-account', worker.origin)"));
    expect(publicPage, isNot(contains('name="username"')));
    expect(publicPage, isNot(contains('name="password"')));
    expect(config, contains("kAccountDeletionInfoUrl = 'https://chowdhury-siam.github.io/Yutaka/delete-account/'"));
    expect(pagesWorkflow, contains('actions/upload-pages-artifact@v4'));
    expect(pagesWorkflow, contains('path: docs'));
  });
}
