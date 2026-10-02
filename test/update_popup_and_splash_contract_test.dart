import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('automatic update pop-up can be disabled without disabling manual checks', () {
    final app = File('lib/main.dart').readAsStringSync();

    expect(app, contains('bool automaticUpdatePopupEnabled = true;'));
    expect(app, contains("prefs.getBool('automaticUpdatePopupEnabled', true)"));
    expect(app, contains('setAutomaticUpdatePopupEnabled(bool enabled)'));
    expect(app, contains("title: const Text('Automatic update pop-ups'"));
    expect(app, contains('!state.automaticUpdatePopupEnabled'));
    expect(app, contains('checkForUpdates(manual: true)'));
  });

  test('Android release keeps the dedicated uncropped Yutaka splash resources', () {
    final baseStyles = File('android/app/src/main/res/values/styles.xml').readAsStringSync();
    final android12Styles = File('android/app/src/main/res/values-v31/styles.xml').readAsStringSync();
    final launchBackground = File('android/app/src/main/res/drawable/launch_background.xml').readAsStringSync();
    final workflow = File('.github/workflows/build-android-apks.yml').readAsStringSync();
    final app = File('lib/main.dart').readAsStringSync();
    final branding = File('lib/branding_widgets.dart').readAsStringSync();

    expect(File('android/app/src/main/res/drawable-nodpi/yutaka_splash_icon.png').existsSync(), isTrue);
    expect(File('assets/icons/yutaka_mark.png').existsSync(), isTrue);
    expect(branding, contains("'assets/icons/yutaka_mark.png'"));
    expect(app, contains("'assets/icons/yutaka_mark.png'"));
    expect(app, contains('width: 88'));
    expect(app, contains('height: 104'));
    expect(baseStyles, contains('@drawable/launch_background'));
    expect(android12Styles, contains('android:windowSplashScreenAnimatedIcon'));
    expect(android12Styles, contains('@drawable/yutaka_splash_icon'));
    expect(launchBackground, contains('@drawable/yutaka_splash_icon'));
    expect(workflow, contains(r'cp -a android "$ANDROID_SOURCE"'));
    expect(workflow, contains('rm -rf android'));
    expect(workflow, contains(r'cp -a "$ANDROID_SOURCE" android'));
    expect(workflow, contains("grep -q '@drawable/yutaka_splash_icon'"));
  });

  test('splash artwork fits Android circular masking without clipped pixels', () async {
    final bytes = File('android/app/src/main/res/drawable-nodpi/yutaka_splash_icon.png').readAsBytesSync();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      expect(image.width, image.height);
      final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final pixels = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final center = image.width / 2;
      final safeRadius = image.width / 3;
      var visiblePixels = 0;
      var outsideSafeCircle = 0;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          if (pixels[(y * image.width + x) * 4 + 3] == 0) continue;
          visiblePixels++;
          final dx = x + .5 - center;
          final dy = y + .5 - center;
          if (dx * dx + dy * dy > safeRadius * safeRadius) outsideSafeCircle++;
        }
      }
      expect(visiblePixels, greaterThan(image.width * image.height ~/ 20));
      expect(outsideSafeCircle, 0, reason: 'Android clips artwork outside the central two-thirds circle');
      expect(pixels[3], 0, reason: 'Splash corners must remain transparent');
    } finally {
      image.dispose();
      codec.dispose();
    }
  });

  test('Account and sync keeps restore and upload actions side by side', () {
    final app = File('lib/main.dart').readAsStringSync();
    final restoreIndex = app.indexOf("label: const Text('Restore cloud copy')");
    final uploadIndex = app.indexOf('label: Text(uploadButtonLabel)');
    final signOutIndex = app.indexOf("label: const Text('Sign out')");

    expect(restoreIndex, greaterThan(0));
    expect(uploadIndex, greaterThan(restoreIndex));
    expect(signOutIndex, greaterThan(uploadIndex));
    final actionBlock = app.substring(restoreIndex - 900, signOutIndex + 250);
    expect(actionBlock, contains('Row('));
    expect(actionBlock, contains('const SizedBox(width: 10)'));
    expect(actionBlock, isNot(contains("label: const Text('Recovery key')")));
  });
}
