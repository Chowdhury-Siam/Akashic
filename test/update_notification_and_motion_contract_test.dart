import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('automatic updates use native Android WorkManager when Yutaka is closed', () {
    final app = File('lib/main.dart').readAsStringSync();
    final background = File('lib/update_background_service.dart').readAsStringSync();
    final nativeWorker = File('android/app/src/direct/kotlin/com/yutaka/siam/UpdateCheckWorker.kt').readAsStringSync();
    final activity = File('android/app/src/main/kotlin/com/yutaka/siam/MainActivity.kt').readAsStringSync();
    final reminders = File('lib/reminder_service.dart').readAsStringSync();

    expect(app, contains('await UpdateBackgroundService.initialize();'));
    expect(app, contains('await UpdateBackgroundService.setEnabled(enabled);'));
    expect(background, contains("MethodChannel('com.yutaka.siam/update_background')"));
    expect(background, contains("cancelByUniqueName(_legacyBackgroundUpdateUniqueName)"));
    expect(background, contains("invokeMethod<void>('sync', {'enabled': nativeEnabled})"));
    expect(nativeWorker, contains('PeriodicWorkRequestBuilder<UpdateCheckWorker>(15, TimeUnit.MINUTES)'));
    expect(nativeWorker, contains('.setRequiredNetworkType(NetworkType.CONNECTED)'));
    expect(nativeWorker, contains('ExistingPeriodicWorkPolicy.UPDATE'));
    expect(nativeWorker, contains('.getPackageInfo(applicationContext.packageName, 0)'));
    expect(nativeWorker, contains('https://api.github.com/repos/Chowdhury-Siam/Yutaka/releases/latest'));
    expect(nativeWorker, contains(r'Yutaka ${release.version} is available'));
    expect(nativeWorker, contains('lastNotifiedUpdateVersion'));
    expect(activity, contains('NativeUpdateCheckScheduler.sync(this, BuildConfig.DISTRIBUTION == "direct")'));
    expect(background, contains('enabled && !kIsGooglePlayBuild'));
    expect(background, contains('if (!Platform.isAndroid || kIsGooglePlayBuild) return true;')); 
    expect(activity, contains('updateBackgroundChannel'));
    expect(reminders, contains("'yutaka_app_updates'"));
    expect(reminders, contains("'Yutaka updates'"));
  });

  test('home wave and empty-state icon motion are contextual and reduce-motion aware', () {
    final app = File('lib/main.dart').readAsStringSync();
    final lottie = File('assets/lottie/empty_state.json').readAsStringSync();

    expect(app, contains('class _DecorativeSparkline extends StatefulWidget'));
    expect(app, contains('_controller.repeat();'));
    expect(app, contains('MediaQuery.of(context).disableAnimations'));
    expect(app, contains('class _AnimatedEmptyStateIcon extends StatefulWidget'));
    expect(app, contains('_AnimatedEmptyStateIcon(icon: icon, color: color)'));
    expect(app, contains("Lottie.asset('assets/lottie/empty_state.json'"));
    expect(lottie, isNot(contains('Wallet')));
  });

  test('semantic feedback wraps full messages in a safe-area top overlay', () {
    final app = File('lib/main.dart').readAsStringSync();
    expect(app, contains('class _YutakaTopFeedbackBanner extends StatefulWidget'));

    // Scope layout checks to this banner rather than unrelated app widgets.
    final start = app.indexOf('class _YutakaTopFeedbackBannerState');
    final end = app.indexOf('\nvoid showSnack(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final banner = app.substring(start, end);

    expect(banner, contains('media.padding.top +'));
    expect(banner, contains('media.size.width - 24'));
    expect(banner, contains('constraints: const BoxConstraints(minHeight: 68)'));
    expect(banner, isNot(contains('maxHeight:')));
    expect(banner, isNot(contains('maxLines:')));
    expect(banner, isNot(contains('TextOverflow.ellipsis')));
    expect(RegExp(r'softWrap: true').allMatches(banner), hasLength(2));
    expect(banner, contains('liveRegion: true'));
    expect(banner, contains("tooltip: 'Dismiss'"));
    expect(app, contains('ContentType.success'));
    expect(app, isNot(contains('final materialBanner = MaterialBanner(')));
    expect(app, isNot(contains('inMaterialBanner: true')));
  });
}
