import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release pipeline uses the supported AGP 9 toolchain', () {
    final settings = File('android/settings.gradle').readAsStringSync();
    final wrapper = File(
      'android/gradle/wrapper/gradle-wrapper.properties',
    ).readAsStringSync();
    final properties = File('android/gradle.properties').readAsStringSync();

    expect(settings, contains('com.android.application" version "9.0.1"'));
    expect(settings, contains('org.jetbrains.kotlin.android" version "2.3.20"'));
    expect(wrapper, contains('gradle-9.1.0-bin.zip'));
    expect(properties, contains('android.newDsl=false'));
    expect(properties, contains('android.builtInKotlin=false'));
  });

  test('direct split APK packaging matches Flutter flavored output names', () {
    final workflow = File(
      '.github/workflows/build-android-apks.yml',
    ).readAsStringSync();

    expect(workflow, contains('app-direct-release.apk'));
    expect(workflow, contains('app-armeabi-v7a-direct-release.apk'));
    expect(workflow, contains('app-arm64-v8a-direct-release.apk'));
    expect(workflow, isNot(contains('app-direct-armeabi-v7a-release.apk')));
    expect(workflow, isNot(contains('app-direct-arm64-v8a-release.apk')));
    expect(workflow, contains('Available Flutter APK outputs:'));
  });

  test('Google Play AAB enforces 16 KB page-size compatibility', () {
    final gradle = File('android/app/build.gradle').readAsStringSync();
    final workflow = File(
      '.github/workflows/build-android-apks.yml',
    ).readAsStringSync();
    final validator = File(
      'tools/android/verify_16kb_page_size.py',
    ).readAsStringSync();

    expect(gradle, contains('ndkVersion = "28.2.13676358"'));
    expect(gradle, contains('packagingOptions {'));
    expect(gradle, contains('useLegacyPackaging false'));
    expect(workflow, contains('Verify Google Play 16 KB page-size compatibility'));
    expect(workflow, contains(r'bundletool-all-${BUNDLETOOL_VERSION}.jar'));
    expect(workflow, contains('verify_16kb_page_size.py'));
    expect(validator, contains('PAGE_ALIGNMENT_16K'));
    expect(validator, contains('PAGE_SIZE = 16 * 1024'));
    expect(validator, contains('GNU_RELRO'));
    expect(validator, contains('arm64-v8a'));
    expect(validator, contains('x86_64'));
  });

  test('Android release artifacts are blocked by analyze and tests', () {
    final workflow = File(
      '.github/workflows/build-android-apks.yml',
    ).readAsStringSync();

    expect(workflow, contains('android-release-quality-gate:'));
    expect(workflow, contains('name: Android release quality gate'));
    expect(workflow, contains('flutter analyze --no-pub'));
    expect(workflow, contains('flutter test --no-pub'));
    expect(
      workflow,
      contains('needs: [prepare-worker-bundle, android-release-quality-gate, android-upgrade-data-loss-gate]'),
    );
  });
  test('Android releases require a real in-place data-preservation upgrade', () {
    final workflow = File(
      '.github/workflows/build-android-apks.yml',
    ).readAsStringSync();
    final runner = File(
      'tools/android/run_upgrade_data_loss_test.sh',
    ).readAsStringSync();
    final fixture = File(
      'tools/android/upgrade_data_fixture.py',
    ).readAsStringSync();
    final productionGradle = File('android/app/build.gradle').readAsStringSync();
    final workerRegression = File(
      'cloud/worker/test/data-loss-regression.test.ts',
    ).readAsStringSync();
    final upgradeProbeBuilder = File(
      'tools/android/build_upgrade_probe_apk.sh',
    ).readAsStringSync();

    expect(workflow, contains('worker-data-integrity-gate:'));
    expect(workflow, contains('npm run typecheck'));
    expect(workflow, contains('npm test'));
    expect(workflow, contains('android-upgrade-data-loss-gate:'));
    expect(workflow, contains('Resolve previous published stable release'));
    expect(workflow, contains('reactivecircus/android-emulator-runner@v2'));
    expect(workflow, contains('api-level: 36'));
    expect(workflow, contains('build_upgrade_probe_apk.sh previous'));
    expect(workflow, contains('build_upgrade_probe_apk.sh current'));
    expect(workflow, contains('run_upgrade_data_loss_test.sh'));
    expect(upgradeProbeBuilder, contains('flutter pub get'));
    expect(upgradeProbeBuilder, isNot(contains('flutter pub get --offline')));
    expect(upgradeProbeBuilder, contains('--target-platform android-x64'));
    expect(upgradeProbeBuilder, contains('--split-per-abi'));
    expect(upgradeProbeBuilder, contains('android/app/build/outputs'));
    expect(upgradeProbeBuilder, contains('lib/x86_64/(libflutter|libapp)'));
    expect(upgradeProbeBuilder, contains('unzip -tq'));
    expect(
      workflow,
      contains('needs: [prepare-worker-bundle, android-release-quality-gate, android-upgrade-data-loss-gate]'),
    );
    expect(runner, contains(r'adb install -r "$CURRENT_APK"'));
    expect(RegExp(r'adb uninstall').allMatches(runner).length, 1);
    expect(runner, contains('current-offline'));
    expect(runner, contains('current-reconnected'));
    expect(fixture, contains('upgrade-tx-expense'));
    expect(fixture, contains('upgrade-budget'));
    expect(fixture, contains('upgrade-loan-payment'));
    expect(fixture, contains('upgrade-sync-operation'));
    expect(fixture, contains('PRAGMA integrity_check'));
    expect(productionGradle, isNot(contains('debuggable true')));
    expect(
      workerRegression,
      contains('all recovered finance entities must remain in cloud state'),
    );
    expect(workerRegression, contains("['transactions', 'tx-preserve'"));
    expect(workerRegression, contains("['loans', 'loan-preserve'"));
  });

}
