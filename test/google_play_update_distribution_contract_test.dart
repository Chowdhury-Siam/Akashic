import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Google Play build uses Play updates without APK install permission', () {
    final appConfig = File('lib/app_config.dart').readAsStringSync();
    final updateService = File('lib/update_service.dart').readAsStringSync();
    final mainApp = File('lib/main.dart').readAsStringSync();
    final mainManifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final directManifest = File('android/app/src/direct/AndroidManifest.xml').readAsStringSync();
    final androidGradle = File('android/app/build.gradle').readAsStringSync();
    final mainActivity = File('android/app/src/main/kotlin/com/yutaka/siam/MainActivity.kt').readAsStringSync();
    final directInstaller = File('android/app/src/direct/kotlin/com/yutaka/siam/DirectApkInstaller.kt').readAsStringSync();
    final playInstaller = File('android/app/src/play/kotlin/com/yutaka/siam/DirectApkInstaller.kt').readAsStringSync();
    final playWorkerStub = File('android/app/src/play/kotlin/com/yutaka/siam/UpdateCheckWorker.kt').readAsStringSync();
    final workflow = File('.github/workflows/build-android-apks.yml').readAsStringSync();

    expect(appConfig, contains("YUTAKA_ANDROID_DISTRIBUTION"));
    expect(appConfig, contains("kIsGooglePlayBuild"));

    expect(mainManifest, isNot(contains('android.permission.REQUEST_INSTALL_PACKAGES')));
    expect(mainManifest, isNot(contains('androidx.core.content.FileProvider')));
    expect(directManifest, contains('android.permission.REQUEST_INSTALL_PACKAGES'));
    expect(directManifest, contains('androidx.core.content.FileProvider'));

    expect(androidGradle, contains('flavorDimensions "distribution"'));
    expect(androidGradle, contains('direct {'));
    expect(androidGradle, contains('play {'));
    expect(androidGradle, contains('com.google.android.play:app-update:2.1.0'));
    expect(androidGradle, contains('com.google.android.play:app-update-ktx:2.1.0'));

    expect(mainActivity, contains('AppUpdateManagerFactory.create(this)'));
    expect(mainActivity, contains('startGooglePlayUpdate'));
    expect(mainActivity, contains('BuildConfig.DISTRIBUTION == "direct"'));
    expect(mainActivity, isNot(contains('application/vnd.android.package-archive')));
    expect(directInstaller, contains('application/vnd.android.package-archive'));
    expect(playInstaller, isNot(contains('application/vnd.android.package-archive')));
    expect(playWorkerStub, isNot(contains('api.github.com')));
    expect(playWorkerStub, contains('cancelUniqueWork(nativeUpdatePeriodicWork)'));
    expect(playWorkerStub, contains('override fun doWork(): Result = Result.success()'));
    expect(updateService, contains('checkGooglePlayUpdate'));
    expect(mainApp, contains('Update with Google Play'));
    expect(mainApp, contains('Google Play builds update through Google Play.'));
    expect(mainApp, contains('UpdateDownloadStore.purgeAndroidUpdateFiles()')); 

    expect(workflow, contains('flutter build appbundle'));
    expect(workflow, contains('--flavor play'));
    expect(workflow, contains('YUTAKA_ANDROID_DISTRIBUTION=play'));
    expect(workflow, contains('--flavor direct'));
    expect(workflow, contains('YUTAKA_ANDROID_DISTRIBUTION=direct'));
    expect(workflow, contains('REQUEST_INSTALL_PACKAGES'));
    expect(workflow, contains('Could not locate the merged Google Play manifest for policy verification.'));
  });
}
