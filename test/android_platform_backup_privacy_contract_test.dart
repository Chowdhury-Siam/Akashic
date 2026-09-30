import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android platform backup is disabled and all backup domains are excluded', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final legacy = File('android/app/src/main/res/xml/backup_rules.xml').readAsStringSync();
    final modern = File('android/app/src/main/res/xml/data_extraction_rules.xml').readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(manifest, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));

    const domains = <String>[
      'root',
      'file',
      'database',
      'sharedpref',
      'external',
      'device_root',
      'device_file',
      'device_database',
      'device_sharedpref',
    ];
    for (final domain in domains) {
      expect(legacy, contains('<exclude domain="$domain" path="."'));
      expect(
        RegExp('<exclude domain="$domain" path="\\."').allMatches(modern).length,
        2,
        reason: '$domain must be excluded from both cloud backup and device transfer',
      );
    }

    expect(modern, contains('<cloud-backup>'));
    expect(modern, contains('<device-transfer>'));
  });
}
