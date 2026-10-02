import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

int _count(String source, String needle) => source.split(needle).length - 1;

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
    expect(frame, contains('alignment: keyboardVisible ? Alignment.topCenter : Alignment.center'));
    expect(frame, contains('media.size.height - media.padding.top - media.padding.bottom - (verticalInset * 2)'));
    expect(frame, isNot(contains('- media.viewInsets.bottom')));
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
