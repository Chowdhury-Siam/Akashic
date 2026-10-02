import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yutaka/keyboard_aware_popup.dart';

Widget form(double keyboardInset, FocusNode title, FocusNode notes) {
  return MaterialApp(
    home: Builder(builder: (context) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.only(bottom: keyboardInset)),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Align(
            alignment: Alignment.topCenter,
            child: KeyboardAwarePopup(
              child: SizedBox(
                key: const Key('form'),
                width: 350,
                height: 700,
                child: Material(
                  child: Column(children: [
                    TextField(key: const Key('title'), focusNode: title),
                    const Spacer(),
                    TextField(key: const Key('notes'), focusNode: notes),
                    const SizedBox(height: 18),
                    FilledButton(onPressed: () {}, child: const Text('Save')),
                    const SizedBox(height: 14),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
    }),
  );
}

void main() {
  testWidgets('notes and Save clear the keyboard without shrinking or scrolling the form', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final title = FocusNode();
    final notes = FocusNode();
    await tester.pumpWidget(form(0, title, notes));
    final originalSize = tester.getSize(find.byKey(const Key('form')));
    final originalPosition = tester.getTopLeft(find.byKey(const Key('form')));
    notes.requestFocus();
    await tester.pumpWidget(form(320, title, notes));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(tester.getRect(find.byKey(const Key('notes'))).bottom, lessThan(524));
    expect(tester.getRect(find.widgetWithText(FilledButton, 'Save')).bottom, lessThan(524));
    expect(tester.getSize(find.byKey(const Key('form'))), originalSize);
    expect(find.byType(SingleChildScrollView), findsNothing);

    // Switching back to an upper input must undo the previous notes offset.
    title.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(tester.getRect(find.byKey(const Key('title'))).top, greaterThanOrEqualTo(0));
    expect(tester.getSize(find.byKey(const Key('form'))), originalSize);

    notes.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpWidget(form(0, title, notes));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const Key('form'))), originalPosition);
    await tester.pumpWidget(const SizedBox.shrink());
    title.dispose();
    notes.dispose();
  });

  testWidgets('tall keyboard still leaves the focused notes input below the safe top', (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final title = FocusNode();
    final notes = FocusNode();
    await tester.pumpWidget(form(340, title, notes));
    notes.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    final rect = tester.getRect(find.byKey(const Key('notes')));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThan(300));
    await tester.pumpWidget(const SizedBox.shrink());
    title.dispose();
    notes.dispose();
  });
}
