import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yutaka/main.dart';

void main() {
  testWidgets('Worker results use top feedback and app installation resumes after dismissal', (tester) async {
    final controller = AppController()
      ..updateInstallBusy = true
      ..updateInstallationMessage = 'Android is installing the update…';
    final navigatorKey = GlobalKey<NavigatorState>();
    try {
      await tester.pumpWidget(ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: ThemeData(brightness: Brightness.dark),
          home: const Scaffold(),
          builder: (context, child) => Stack(
            fit: StackFit.expand,
            children: [
              child!,
              YutakaUpdateActivityOverlay(navigatorKey: navigatorKey),
            ],
          ),
        ),
      ));
      expect(find.text('Installing Yutaka'), findsOneWidget);

      controller.updateActivityNotice = (
        id: 1,
        title: 'Worker deployed successfully',
        message: 'The latest Worker is healthy.',
        error: false,
      );
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Worker deployed successfully'), findsOneWidget);
      expect(find.text('The latest Worker is healthy.'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('Installing Yutaka'), findsNothing);

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Worker deployed successfully'), findsNothing);
      expect(find.text('Installing Yutaka'), findsOneWidget);

      controller.updateActivityNotice = (
        id: 2,
        title: 'Worker deployment failed',
        message: 'Check the saved deployment credentials and retry.',
        error: true,
      );
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Worker deployment failed'), findsOneWidget);
      expect(find.text('Check the saved deployment credentials and retry.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('Installing Yutaka'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      // Dismiss the global feedback entry and its timer before unmounting.
      if (find.byTooltip('Dismiss').evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('Dismiss'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });
}
