import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Play build avoids direct battery-optimization exemption while direct build keeps it', () {
    final app = File('lib/main.dart').readAsStringSync();
    final service = File('lib/android_background_permission_service.dart').readAsStringSync();
    final activity = File('android/app/src/main/kotlin/com/yutaka/siam/MainActivity.kt').readAsStringSync();
    final playPolicy = File('android/app/src/play/kotlin/com/yutaka/siam/BatteryOptimizationFlavorPolicy.kt').readAsStringSync();
    final directPolicy = File('android/app/src/direct/kotlin/com/yutaka/siam/BatteryOptimizationFlavorPolicy.kt').readAsStringSync();
    final mainManifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final playManifest = File('android/app/src/play/AndroidManifest.xml').readAsStringSync();
    final directManifest = File('android/app/src/direct/AndroidManifest.xml').readAsStringSync();

    expect(app, contains("const SectionHeader('Permissions')"));
    expect(app, contains("playBuild ? 'Battery optimization' : 'Ignore Battery Optimization'"));
    expect(app, contains("playBuild ? 'Optimized • tap to review' : 'Permission not granted'"));
    expect(app, contains('AndroidBackgroundPermissionService.openBatteryOptimizationSettings()'));
    expect(service, contains("MethodChannel('com.yutaka.siam/background_permissions')"));

    expect(activity, contains('BatteryOptimizationFlavorPolicy.openSettings(this)'));
    expect(activity, isNot(contains('Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS')));
    expect(playPolicy, isNot(contains('ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS')));
    expect(playPolicy, contains('Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS'));
    expect(directPolicy, contains('Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'));
    expect(directPolicy, contains('Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS'));
    expect(activity, contains('isIgnoringBatteryOptimizations()'));
    expect(activity, contains('PowerManager'));

    expect(mainManifest, isNot(contains('android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS')));
    expect(playManifest, contains('android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'));
    expect(playManifest, contains('tools:node="remove"'));
    expect(directManifest, contains('android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'));
    expect(mainManifest, contains('android.permission.SCHEDULE_EXACT_ALARM'));
  });

  test('notification feature toggles request notification permission on Android', () {
    final app = File('lib/main.dart').readAsStringSync();
    final reminders = File('lib/reminder_service.dart').readAsStringSync();

    expect(reminders, contains('static Future<void> requestNotificationPermission()'));
    expect(app, contains('await ReminderService.requestNotificationPermission();'));
  });
}
