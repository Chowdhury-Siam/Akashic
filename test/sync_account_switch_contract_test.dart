import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saved account switching replaces local state instead of merging accounts', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final storeSource = File('lib/persistence_stores.dart').readAsStringSync();
    final modelSource = File('lib/sync_models.dart').readAsStringSync();

    expect(modelSource, contains('class SavedSyncWorker'));
    expect(modelSource, contains('class SavedSyncAccount'));
    expect(storeSource, contains('yutaka_sync_profile_refresh_v1_'));

    expect(mainSource, contains('Future<void> switchToSavedSyncAccount(String profileId)'));
    expect(mainSource, contains('Future<void> loginAndSwitchSyncAccount({'));
    expect(mainSource, contains('Future<void> registerAndSwitchSyncAccount({'));
    expect(mainSource, contains('replaceFinanceDataWithRemoteChanges(snapshot.changes)'));
    expect(mainSource, contains("await requireSafetyBackup('Before switching sync account')"));
    expect(mainSource, contains("await database.writeSyncState('serverCursor', '\${snapshot.cursor}')"));
    expect(mainSource, contains("await _clearLocalProfileMedia(clearRemoteTracking: true)"));
    expect(mainSource, contains('await _replaceRemotePreferences('));

    final switchMethod = mainSource.substring(
      mainSource.indexOf('Future<void> switchToSavedSyncAccount'),
      mainSource.indexOf('Future<void> loginAndSwitchSyncAccount'),
    );
    expect(switchMethod, isNot(contains('performMultiDeviceSync')));
    expect(switchMethod, contains('refreshToken: tokens.refreshToken'));
    expect(switchMethod, contains('writeAccountTokens(selected.id'));

    final registerSwitchMethod = mainSource.substring(
      mainSource.indexOf('Future<void> registerAndSwitchSyncAccount'),
      mainSource.indexOf('Future<void> _authenticateAndSwitchSyncAccount'),
    );
    expect(registerSwitchMethod, isNot(contains('enqueueAllForAdoption')));
    expect(mainSource, contains("const Text('Create new account')"));
    expect(mainSource, contains("const Text('Validate Worker')"));
  });

  test('Worker deployment credentials are keyed per Worker', () {
    final workerSource = File('lib/worker_deployment.dart').readAsStringSync();
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(workerSource, contains('yutaka_worker_auto_deployment_profile_v2_'));
    expect(workerSource, contains('read({String workerUrl = \'\'}'));
    expect(workerSource, contains('clear({String workerUrl = \'\'}'));
    expect(workerSource, contains('read(workerUrl: activeWorkerUrl)'));
    expect(mainSource, contains('store.read(workerUrl: currentUrl)'));
    expect(mainSource, contains('clear(workerUrl: cloudSyncApiBaseUrl)'));
  });

  test('account switcher can remove saved users and account actions stay available during restore', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final syncSource = File('lib/sync_services.dart').readAsStringSync();

    expect(mainSource, contains('Future<void> removeSavedSyncAccount(String profileId)'));
    expect(mainSource, contains("tooltip: 'Delete saved account'"));
    expect(mainSource, contains('Icons.delete_outline_rounded'));
    expect(mainSource, contains('The account and its data in the cloud are not deleted'));
    expect(mainSource, contains('Cloud data remains safe.'));

    expect(mainSource, contains('final accountActionBusy = state.syncAuthBusy || _endpointBusy || state.workerAutoUpdateBusy;'));
    expect(mainSource, contains('onPressed: accountActionBusy ? null : _openAccountSwitcher'));
    expect(mainSource, contains('onPressed: accountActionBusy ? null : _confirmSignOut'));
    expect(mainSource, contains('Future<void> _cancelActiveCloudSyncForAccountTransition()'));
    expect(mainSource, contains('YutakaSyncApi.cancelPendingRequests();'));
    expect(mainSource, contains('_throwIfCloudSyncCancelled(cancellationSerial);'));
    expect(syncSource, contains('static void cancelPendingRequests() => _resetHttpClient();'));
  });
}
