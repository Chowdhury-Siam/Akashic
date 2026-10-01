import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yutaka/main.dart';
import 'package:provider/provider.dart';

Future<void> pumpOnboardingFrame(WidgetTester tester) async {
  // The onboarding glyph intentionally repeats forever. Advancing a bounded
  // amount of time lets finite page/dialog transitions complete without
  // waiting for an ambient animation that is not supposed to settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<AppController> pumpOnboarding(WidgetTester tester) async {
  final controller = AppController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppController>.value(
      value: controller,
      child: const MaterialApp(home: OnboardingScreen()),
    ),
  );
  await pumpOnboardingFrame(tester);
  return controller;
}

void main() {
  testWidgets('Use offline asks whether to restore or start new', (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Use offline'));
    await pumpOnboardingFrame(tester);

    expect(find.text('Set up this device'), findsOneWidget);
    expect(find.text('Restore backup'), findsOneWidget);
    expect(find.text('Start new'), findsOneWidget);
  });

  testWidgets('signed-in unfinished onboarding exposes Continue setup', (tester) async {
    final controller = await pumpOnboarding(tester);
    controller.cloudSyncEnabled = true;
    controller.syncAccountUsername = 'owner';
    controller.notifyListeners();
    await pumpOnboardingFrame(tester);

    expect(find.text('Continue setup'), findsOneWidget);
    expect(find.text('Login'), findsNothing);
    expect(find.text('Create account'), findsNothing);

    await tester.tap(find.text('Continue setup'));
    await pumpOnboardingFrame(tester);

    expect(find.text('Set up this device'), findsOneWidget);
    expect(find.textContaining('Your sync account is ready.'), findsOneWidget);
  });
}
