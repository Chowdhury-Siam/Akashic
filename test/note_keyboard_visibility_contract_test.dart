import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

int _count(String source, String needle) => source.split(needle).length - 1;

void main() {
  test('transaction notes stay above the keyboard after the IME settles', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('Future<void>.delayed(AppMotion.fast, _scrollNotesIntoView);'));
    expect(source, contains('Future<void>.delayed(AppMotion.medium, _scrollNotesIntoView);'));
    expect(source, contains('Future<void>.delayed(AppMotion.slow, _scrollNotesIntoView);'));
    expect(source, contains('alignment: .08,'));
    expect(source, contains('alignmentPolicy: ScrollPositionAlignmentPolicy.explicit'));
    expect(source, contains('padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom)'));
  });

  test('loan and loan-payment notes become keyboard-aware only while focused', () {
    final source = File('lib/loans/loan_sheets.dart').readAsStringSync();

    expect(_count(source, 'final noteFocus = FocusNode();'), greaterThanOrEqualTo(2));
    expect(_count(source, 'final noteKey = GlobalKey();'), greaterThanOrEqualTo(2));
    expect(_count(source, 'final keyboardAwareNoteEditing = _noteHasFocus && keyboardInset > 0;'), 2);
    expect(_count(source, 'if (keyboardAwareNoteEditing)'), 2);
    expect(_count(source, 'padding: EdgeInsets.only(bottom: keyboardInset)'), 2);
    expect(_count(source, 'key: noteKey,'), greaterThanOrEqualTo(2));
    expect(_count(source, 'focusNode: noteFocus,'), greaterThanOrEqualTo(2));
    expect(_count(source, 'Future<void>.delayed(AppMotion.slow, _scrollNoteIntoView);'), 2);
    expect(_count(source, 'alignment: .08,'), greaterThanOrEqualTo(2));
  });
}
