import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yutaka/update_activity_indicator.dart';

Widget _frame({
  bool workerUpdating = true,
  bool appUpdating = false,
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
            percent: 42,
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

  testWidgets('reduced motion shows a static icon with accessible update status', (tester) async {
    _setView(tester, const Size(390, 844));
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await tester.pumpWidget(_frame(reduceMotion: true));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('worker-update-active'))),
      matchesSemantics(
        label: 'Updating Worker. Installing the latest update.',
        isLiveRegion: true,
      ),
    );
    final switcher = tester.widget<AnimatedSwitcher>(find.descendant(
      of: find.byType(WorkerUpdateBanner),
      matching: find.byType(AnimatedSwitcher),
    ));
    expect(switcher.duration, Duration.zero);
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
