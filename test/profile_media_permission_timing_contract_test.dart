import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile media uses a scoped system picker without broad media permission', () {
    final profileUi = File('lib/profile/profile_ui.dart').readAsStringSync();
    final activity = File('android/app/src/main/kotlin/com/yutaka/siam/MainActivity.kt').readAsStringSync();
    final mainManifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final playManifest = File('android/app/src/play/AndroidManifest.xml').readAsStringSync();
    final directManifest = File('android/app/src/direct/AndroidManifest.xml').readAsStringSync();

    expect(profileUi, contains('Future<void> pickAndSaveProfileMedia'));
    expect(profileUi, contains('FilePicker.platform.pickFiles'));
    expect(profileUi, isNot(contains('requestProfileMediaPermissionFlow')));
    expect(profileUi, isNot(contains('Photos and videos access')));
    expect(activity, isNot(contains('requestProfileMediaPermission')));
    expect(activity, isNot(contains('READ_MEDIA_IMAGES')));
    expect(activity, isNot(contains('READ_MEDIA_VIDEO')));

    for (final permission in [
      'android.permission.READ_MEDIA_IMAGES',
      'android.permission.READ_MEDIA_VIDEO',
      'android.permission.READ_MEDIA_VISUAL_USER_SELECTED',
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.WRITE_EXTERNAL_STORAGE',
    ]) {
      expect(mainManifest, isNot(contains(permission)));
      expect(playManifest, contains(permission));
      expect(directManifest, contains(permission));
    }
    expect(playManifest, contains('tools:node="remove"'));
    expect(directManifest, contains('tools:node="remove"'));
  });
}
