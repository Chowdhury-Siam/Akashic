import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account sync never calls destructive replace-all from the Flutter client', () {
    final source = File('lib/main.dart').readAsStringSync();
    final syncApiSource = File('lib/sync_services.dart').readAsStringSync();
    expect(source, isNot(contains('api.replaceAll(')));
    expect(syncApiSource, isNot(contains('/v1/sync/replace')));
    expect(source, contains('performMultiDeviceSync(pushLocalChanges: true, pullFullCloudCopy: true)'));
    expect(source, contains('Backup merged with local data'));
  });

  test('Android automatic backup uses persisted Storage Access Framework access', () {
    final dartSource = File('lib/android_saf_backup_store.dart').readAsStringSync();
    final androidSource = File('android/app/src/main/kotlin/com/yutaka/siam/MainActivity.kt').readAsStringSync();

    expect(dartSource, contains('com.yutaka.siam/backup_storage'));
    expect(androidSource, contains('Intent.ACTION_OPEN_DOCUMENT_TREE'));
    expect(androidSource, contains('takePersistableUriPermission'));
    expect(androidSource, contains('DocumentsContract.createDocument'));
    expect(androidSource, contains('ensureYutakaBackupDirectory'));
    expect(androidSource, contains('"Yutaka"'));
    expect(androidSource, contains('"Backup"'));
  });

  test('automatic backup uses a boolean delete-older policy and no retention slider', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('autoBackupDeleteOlder'));
    expect(source, contains('Delete older automatic backups'));
    expect(source, isNot(contains('How many to keep')));
    expect(source, isNot(contains('Automatic backups to keep')));
    expect(source, isNot(contains("child: const Text('App storage')")));
  });

  test('starter account placeholders are created only for Start New setup', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('ensureStarterAccountsForNewSetup'));
    expect(source, contains('prepareStartNewSetup'));
    expect(source, contains('discardPreloadedStarterAccountsForImport'));
    expect(source, contains('hasRedundantPreloadedStarterAccountEvidence'));
    expect(source, contains('Starter accounts are intentionally NOT inserted'));
  });

  test('settled merge conflicts are closed after convergence instead of staying open forever', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('resolveSettledSyncConflicts'));
    expect(source, contains('resolved_at = ?'));
    expect(source, contains('NOT EXISTS ('));
    expect(source, contains('sync_outbox.entity_type = sync_conflicts.entity_type'));
  });

  test('legacy cloud reset history is recovered without destructive replace', () {
    final source = File('lib/main.dart').readAsStringSync();
    final worker = File('cloud/worker/src/index.ts').readAsStringSync();
    expect(source, contains('legacyCloudResetHistoryRecoveryV1'));
    expect(source, isNot(contains('remoteChanges.removeRange(0, lastResetIndex + 1)')));
    expect(worker, contains('Destructive cloud replace is disabled'));
    expect(worker, isNot(contains("DELETE FROM sync_entities WHERE user_id = ?")));
  });

  test('rebrand preserves legacy Android identity and database', () {
    final gradle = File('android/app/build.gradle').readAsStringSync();
    final source = File('lib/main.dart').readAsStringSync();
    expect(gradle, contains('applicationId = "com.siamapps.koinly"'));
    expect(source, contains("_canonicalDatabaseFileName = 'koinly_flutter.db'"));
    expect(source, contains("_transitionalDatabaseFileName = 'yutaka_flutter.db'"));
  });
}
