import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release stays on Android 16 / API 36', () {
    final gradle = File('android/app/build.gradle').readAsStringSync();
    final workflow = File('.github/workflows/build-android-apks.yml').readAsStringSync();
    final readme = File('README.md').readAsStringSync();

    expect(gradle, contains('compileSdk = 36'));
    expect(gradle, contains('targetSdk = 36'));
    expect(workflow, contains('Verify Android 16 / API 36 app target'));
    expect(workflow, contains('platforms;android-36'));
    expect(workflow, contains('build-tools;36.0.0'));
    expect(readme, contains('Android 16 / API 36'));
  });
}
