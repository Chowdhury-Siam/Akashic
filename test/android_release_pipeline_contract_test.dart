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

  test('Android release quality and build jobs use the pinned Flutter SDK', () {
    final workflow = File(
      '.github/workflows/build-android-apks.yml',
    ).readAsStringSync();

    expect(workflow, contains('channel: beta'));
    expect(workflow, contains('flutter-version: 3.49.0-0.2.pre'));
    expect(workflow, isNot(contains('flutter-version: 3.47.4')));
  });

  test('Google Play AAB enforces 16 KB page-size compatibility', () {
    final appGradle = File('android/app/build.gradle').readAsStringSync();
    final rootGradle = File('android/build.gradle').readAsStringSync();
    final workflow = File(
      '.github/workflows/build-android-apks.yml',
    ).readAsStringSync();
    final validator = File(
      'tools/android/verify_16kb_page_size.py',
    ).readAsStringSync();

    expect(appGradle, contains('ndkVersion = "28.2.13676358"'));
    expect(appGradle, contains('packagingOptions {'));
    expect(appGradle, contains('useLegacyPackaging false'));
    expect(rootGradle, contains('yutakaDataStoreVersion = "1.3.0-alpha11"'));
    expect(rootGradle, contains(r'androidx.datastore:datastore-core-android:${yutakaDataStoreVersion}'));
    expect(appGradle, contains('androidx.datastore:datastore-preferences:1.3.0-alpha11'));
    expect(appGradle, contains('strictly "1.3.0-alpha11"'));
    expect(workflow, contains('Verify 16 KB-safe AndroidX DataStore resolution'));
    expect(workflow, contains('datastore-core-android:1.3.0-alpha11'));
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
      contains('needs: [prepare-worker-bundle, android-release-quality-gate, worker-data-integrity-gate]'),
    );
  });
  test('Android release no longer runs the slow emulator upgrade gate', () {
    final workflow = File(
      '.github/workflows/build-android-apks.yml',
    ).readAsStringSync();

    expect(workflow, contains('worker-data-integrity-gate:'));
    expect(workflow, contains('npm run typecheck'));
    expect(workflow, contains('npm test'));
    expect(workflow, isNot(contains('android-upgrade-data-loss-gate:')));
    expect(workflow, isNot(contains('reactivecircus/android-emulator-runner@v2')));
    expect(File('tools/android/run_upgrade_data_loss_test.sh').existsSync(), isFalse);
    expect(File('tools/android/build_upgrade_probe_apk.sh').existsSync(), isFalse);
    expect(File('tools/android/upgrade_data_fixture.py').existsSync(), isFalse);
  });

}
