import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transaction notes retain fixed popup sizing while the keyboard is open', () {
    final source = File('lib/main.dart').readAsStringSync();
    final editorStart = source.indexOf('class _TransactionEditorState');
    final editorEnd = source.indexOf('Future<void> showDateRangeSheet', editorStart);
    final editor = source.substring(editorStart, editorEnd);
    final frameStart = source.indexOf('class _YutakaPopupFrame');
    final frameEnd = source.indexOf('class YutakaPopupContent', frameStart);
    final frame = source.substring(frameStart, frameEnd);

    expect(editor, contains('controller: notes'));
    expect(editor, contains('minLines: 1'));
    expect(editor, contains('maxLines: 3'));
    expect(editor, isNot(contains('_scrollNotesIntoView')));
    expect(editor, isNot(contains('SingleChildScrollView(')));
    expect(editor, contains('child: YutakaPopupContent('));
    expect(frame, contains('return _KeyboardDismissOnBack('));
    expect(frame, contains('child: KeyboardAwarePopup('));
    expect(frame, contains('alignment: keyboardVisible ? Alignment.topCenter : Alignment.center'));
    expect(frame, contains('media.size.height - media.padding.top - media.padding.bottom - (verticalInset * 2)'));
    expect(frame, isNot(contains('- media.viewInsets.bottom')));
  });

  test('loan and loan-payment notes use fixed content with shared keyboard positioning', () {
    final source = File('lib/loans/loan_sheets.dart').readAsStringSync();
    final app = File('lib/main.dart').readAsStringSync();
    expect(source, contains('return YutakaPopupContent('));
    expect(source, isNot(contains('SingleChildScrollView(')));
    expect(source, isNot(contains('Scrollable.ensureVisible(')));
    expect(source, contains('controller: note'));
    expect(source, contains('child: _LoanEditorSheet('));
    expect(source, contains('child: _LoanPaymentSheet('));
    expect(app, contains('child: KeyboardAwarePopup('));
  });
}
