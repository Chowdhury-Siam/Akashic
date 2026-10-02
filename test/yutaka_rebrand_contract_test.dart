import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Yutaka branding and release identity stay synchronized', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final config = File('lib/app_config.dart').readAsStringSync();
    final updates = File('lib/update_service.dart').readAsStringSync();
    final gradle = File('android/app/build.gradle').readAsStringSync();
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final workflow = File('.github/workflows/build-android-apks.yml').readAsStringSync();
    final worker = File('cloud/worker/src/index.ts').readAsStringSync();
    final backup = File('lib/main.dart').readAsStringSync();

    expect(pubspec, contains('name: yutaka'));
    expect(pubspec, contains('version: 1.0.1259+303'));
    expect(config, contains("const appTitle = 'Yutaka';"));
    expect(updates, contains("const updateGithubOwner = 'Chowdhury-Siam';"));
    expect(updates, contains("const updateGithubRepo = 'Yutaka';"));
    expect(updates, contains("const updateGithubWebBase = 'https://github.com';"));
    expect(gradle, contains('namespace = "com.yutaka.siam"'));
    expect(gradle, contains('applicationId = "com.yutaka.siam"'));
    expect(manifest, contains('android:label="Yutaka"'));
    expect(workflow, contains("github.repository == 'Chowdhury-Siam/Yutaka'"));
    expect(workflow, contains(r'Yutaka-v${YUTAKA_APP_VERSION_NAME}-play.aab'));
    expect(worker, contains("service: 'yutaka-sync'"));
    expect(backup, contains("backupExtension = 'yutakabackup'"));
    expect(backup, contains("legacyBackupExtension = 'koinlybackup'"));
    expect(backup, contains('allowedExtensions: const [BackupService.backupExtension]'));

    expect(File('assets/icons/yutaka_logo.svg').existsSync(), isTrue);
    expect(File('assets/icons/app_icon.png').existsSync(), isTrue);
    expect(File('assets/icons/yutaka_mark.png').existsSync(), isTrue);
    expect(File('android/app/src/main/res/drawable-nodpi/yutaka_splash_icon.png').existsSync(), isTrue);
    expect(File('tools/linux/yutaka.desktop').existsSync(), isTrue);
    expect(File('docs/images/yutaka-readme-banner.png').existsSync(), isTrue);
  });
}
