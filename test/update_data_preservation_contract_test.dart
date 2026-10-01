import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('database upgrades do not clear or replace finance data', () {
    final source = File('lib/main.dart').readAsStringSync();
    final upgradeStart = source.indexOf('onUpgrade: (database, oldVersion, newVersion) async {');
    expect(upgradeStart, greaterThanOrEqualTo(0));
    final upgradeEnd = source.indexOf('onOpen:', upgradeStart);
    expect(upgradeEnd, greaterThan(upgradeStart));
    final upgradeBody = source.substring(upgradeStart, upgradeEnd);

    expect(upgradeBody, contains('await _createSchema(database);'));
    expect(upgradeBody, contains('await _ensureTransactionMetadataColumns(database);'));
    expect(upgradeBody, isNot(contains('DELETE FROM')));
    expect(upgradeBody, isNot(contains('DROP TABLE')));
    expect(upgradeBody, isNot(contains('clearFinanceDataForRemoteLogin')));
    expect(upgradeBody, isNot(contains('replaceFinanceDataWithRemoteChanges')));
  });

  test('legacy cloud reset is recovered as merge data instead of implicit deletion', () {
    final appSource = File('lib/main.dart').readAsStringSync();
    final mergeSource = File('lib/data_merge.dart').readAsStringSync();
    final workerSource = File('cloud/worker/src/index.ts').readAsStringSync();

    expect(mergeSource, contains('mergeRemoteSyncHistoryNonDestructively'));
    expect(mergeSource, contains("change['operation']?.toString() != 'upsert'"));
    expect(appSource, contains('mergedHistory.recoveredLegacyData'));
    expect(workerSource, contains('recoverLegacyResetData(db, auth.userId)'));
    expect(workerSource, contains("AND before_ranked.operation = 'upsert'"));
    expect(workerSource, contains('AND after_ranked.entity_type IS NULL'));
  });
}
