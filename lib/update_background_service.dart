import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'app_config.dart';
import 'reminder_service.dart';
import 'subscription_background_service.dart';
import 'update_service.dart';

// Kept only so upgrades can cancel the older headless-Flutter periodic task.
const _legacyBackgroundUpdateUniqueName = 'yutaka-periodic-update-check';
const _backgroundUpdateTaskName = 'yutakaUpdateCheck';
const _backgroundSubscriptionUniqueName = 'yutaka-periodic-subscription-check';
const _backgroundSubscriptionTaskName = 'yutakaSubscriptionCheck';
const _automaticUpdatePreferenceKey = 'automaticUpdatePopupEnabled';
const _lastNotifiedUpdateVersionKey = 'lastNotifiedUpdateVersion';
const _nativeUpdateChannel = MethodChannel('com.yutaka.siam/update_background');

@pragma('vm:entry-point')
void yutakaBackgroundUpdateDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    // Compatibility for an already-enqueued task from older Yutaka builds.
    if (taskName == _backgroundUpdateTaskName) {
      return UpdateBackgroundService.runBackgroundCheck();
    }
    if (taskName == _backgroundSubscriptionTaskName) {
      await SubscriptionBackgroundService.processDueNow();
      return true;
    }
    return true;
  });
}

class UpdateBackgroundService {
  const UpdateBackgroundService._();

  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    // Workmanager remains used for subscription processing. App-update checks
    // are scheduled natively so they do not depend on a headless Flutter
    // isolate while Yutaka is closed.
    await Workmanager().initialize(yutakaBackgroundUpdateDispatcher);
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_automaticUpdatePreferenceKey) ?? true;
    await setEnabled(enabled);
    await Workmanager().registerPeriodicTask(
      _backgroundSubscriptionUniqueName,
      _backgroundSubscriptionTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      tag: 'yutaka-subscriptions',
    );
  }

  static Future<void> setEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    // Remove the pre-1.0.1167 Dart updater if it is still present. Google Play
    // builds intentionally disable the GitHub background checker because Play
    // is the authoritative update channel for those installs.
    await Workmanager().cancelByUniqueName(_legacyBackgroundUpdateUniqueName);
    final nativeEnabled = enabled && !kIsGooglePlayBuild;
    try {
      await _nativeUpdateChannel.invokeMethod<void>('sync', {'enabled': nativeEnabled});
    } on PlatformException {
      // Foreground update checks remain available even if a vendor-specific
      // Android build cannot install the native schedule.
    } on MissingPluginException {
      // Allows tests/non-Android hosts to exercise preference code safely.
    }
    if (!nativeEnabled) {
      await ReminderService.cancelUpdateAvailableNotification();
    }
  }

  // Retained for old queued work and for deterministic foreground fallback.
  static Future<bool> runBackgroundCheck() async {
    if (!Platform.isAndroid || kIsGooglePlayBuild) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_automaticUpdatePreferenceKey) ?? true)) return true;
      final result = await GithubUpdateService().check(installedVersion: appVersion);
      if (result.hasUpdate && result.release != null) {
        await notifyReleaseIfNeeded(result.release!);
      }
      return result.outcome != UpdateCheckOutcome.networkError &&
          result.outcome != UpdateCheckOutcome.httpError;
    } catch (_) {
      return false;
    }
  }

  static Future<void> notifyReleaseIfNeeded(GithubRelease release) async {
    if (!Platform.isAndroid || kIsGooglePlayBuild) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_automaticUpdatePreferenceKey) ?? true)) return;
    if (prefs.getString(_lastNotifiedUpdateVersionKey) == release.displayVersion) return;

    await ReminderService.showUpdateAvailableNotification(
      version: release.displayVersion,
      releaseName: release.name,
    );
    await prefs.setString(_lastNotifiedUpdateVersionKey, release.displayVersion);
  }
}
