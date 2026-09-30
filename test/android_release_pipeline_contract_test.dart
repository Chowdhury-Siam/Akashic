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
}
