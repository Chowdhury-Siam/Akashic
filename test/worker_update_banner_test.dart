import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yutaka/update_activity_indicator.dart';

Widget _frame({
  bool workerUpdating = true,
  bool appUpdating = false,
  bool appInstalling = false,
  int? percent = 42,
  String installationMessage = 'Preparing the installer…',
  VoidCallback? onDismissInstallation,
  bool feedbackVisible = false,
  bool reduceMotion = false,
  double textScale = 1,
  Size size = const Size(390, 844),
  TargetPlatform platform = TargetPlatform.android,
  VoidCallback? onTap,
}) {
  return MaterialApp(
    theme: ThemeData(
      brightness: Brightness.dark,
      platform: platform,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00BD91),
        brightness: Brightness.dark,
      ),
    ),
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        padding: const EdgeInsets.only(top: 24),
        disableAnimations: reduceMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: const ColoredBox(color: Color(0xFF0F1216)),
          ),
          UpdateActivityOverlay(
            workerUpdating: workerUpdating,
            appUpdating: appUpdating,
            appInstalling: appInstalling,
            percent: percent,
            installationMessage: installationMessage,
            onDismissInstallation: onDismissInstallation,
            feedbackVisible: feedbackVisible,
          ),
        ],
      ),
    ),
  );
}

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('Worker progress uses the top popup slot and allows taps through', (tester) async {
    _setView(tester, const Size(390, 844));
    var taps = 0;
    await tester.pumpWidget(_frame(onTap: () => taps++));

    final card = tester.getRect(find.byKey(const ValueKey('worker-update-card')));
    expect(card.left, 12);
    expect(card.width, 366);
    expect(card.top, 34, reason: 'Banner stays below the status bar.');
    expect(find.text('Updating Worker'), findsOneWidget);
    expect(find.text('Installing the latest update…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tapAt(card.center);
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('feedback gets priority and ongoing Worker progress resumes afterward', (tester) async {
    _setView(tester, const Size(390, 844));
    await tester.pumpWidget(_frame(appUpdating: true));
    expect(find.text('Updating Worker'), findsOneWidget);
    expect(find.textContaining('Updating Yutaka'), findsNothing);

    await tester.pumpWidget(_frame(appUpdating: true, feedbackVisible: true));
    expect(find.text('Updating Worker'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpWidget(_frame(appUpdating: true));
    expect(find.text('Updating Worker'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('progress disappears after work finishes and app downloads retain their percentage', (tester) async {
    _setView(tester, const Size(390, 844));
    await tester.pumpWidget(_frame());
    await tester.pumpWidget(_frame(workerUpdating: false));
    // Advance a bounded duration; a live progress spinner never settles.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Updating Worker'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpWidget(_frame(workerUpdating: false, appUpdating: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Updating Yutaka… 42%'), findsOneWidget);
  });

  testWidgets('app downloads share the popup layout and transition to installation without stale percentage', (tester) async {
    _setView(tester, const Size(320, 844));
    await tester.pumpWidget(_frame(
      workerUpdating: false,
      appUpdating: true,
      percent: 94,
      textScale: 2,
      size: const Size(320, 844),
    ));
    final download = tester.getRect(find.byKey(const ValueKey('app-download-update-card')));
    expect(download.left, 12);
    expect(download.width, 296);
    expect(download.top, 34);
    expect(download.height, greaterThan(68));
    expect(find.text('Updating Yutaka… 94%'), findsOneWidget);
    expect(find.text('Downloading the latest update…'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_frame(workerUpdating: false, appInstalling: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Installing Yutaka'), findsOneWidget);
    expect(find.text('Preparing the installer…'), findsOneWidget);
    expect(find.textContaining('94%'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.getRect(find.byKey(const ValueKey('app-install-update-card'))).top, 34);

    await tester.pumpWidget(_frame(workerUpdating: false));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Installing Yutaka'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('installer feedback respects reduced motion and offers a dismiss action', (tester) async {
    _setView(tester, const Size(390, 844));
    final semantics = tester.ensureSemantics();
    var dismissed = 0;
    try {
      await tester.pumpWidget(_frame(
        workerUpdating: false,
        appInstalling: true,
        reduceMotion: true,
        installationMessage: 'Finish the update in the installer.',
        onDismissInstallation: () => dismissed++,
      ));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('app-install-update-active'))),
        isSemantics(
          label: 'Installing Yutaka. Finish the update in the installer.',
          hint: 'Dismiss update progress. Installation continues.',
          isLiveRegion: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byTooltip('Dismiss update progress'));
      expect(dismissed, 1);
      expect(find.text('Installing Yutaka'), findsOneWidget, reason: 'Dismissal is feedback only; the callback owns the state.');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('reduced motion shows a static icon with accessible update status', (tester) async {
    _setView(tester, const Size(390, 844));
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_frame(reduceMotion: true));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('worker-update-active'))),
        // Check the banner's contract, allowing framework-owned semantics flags.
        isSemantics(
          label: 'Updating Worker. Installing the latest update.',
          isLiveRegion: true,
          isHidden: false,
          hasTapAction: false,
          hasLongPressAction: false,
        ),
      );
      final switcher = tester.widget<AnimatedSwitcher>(find.descendant(
        of: find.byType(WorkerUpdateBanner),
        matching: find.byType(AnimatedSwitcher),
      ));
      expect(switcher.duration, Duration.zero);
    } finally {
      // Flutter checks handles before addTearDown callbacks run.
      semantics.dispose();
    }
  });

  testWidgets('large text wraps on phones and desktop banners stay centered', (tester) async {
    _setView(tester, const Size(320, 844));
    await tester.pumpWidget(_frame(size: const Size(320, 844), textScale: 2));
    final phoneCard = tester.getRect(find.byKey(const ValueKey('worker-update-card')));
    expect(phoneCard.width, 296);
    expect(phoneCard.height, greaterThan(68));
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(_frame(
      size: const Size(1440, 900),
      platform: TargetPlatform.windows,
      textScale: 2,
    ));
    // MaterialApp animates the platform/theme change; the spinner never settles.
    await tester.pump(const Duration(milliseconds: 300));
    final desktopCard = tester.getRect(find.byKey(const ValueKey('worker-update-card')));
    expect(desktopCard.width, 500);
    expect(desktopCard.center.dx, 720);
    expect(desktopCard.top, 38);
    expect(tester.takeException(), isNull);
  });
}
