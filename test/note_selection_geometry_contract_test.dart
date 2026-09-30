import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('note editor keeps Android text selection bound to the selected glyphs', () {
    final source = File('lib/main.dart').readAsStringSync();
    final start = source.indexOf('class _NoteEditorScreenState');
    final end = source.indexOf('class _NoteMetaChip', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final editor = source.substring(start, end);

    // Both the title and body explicitly use tight selection boxes so a
    // selection that reaches a line boundary cannot paint across blank space.
    expect(
      'selectionWidthStyle: ui.BoxWidthStyle.tight'.allMatches(editor).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      'selectionHeightStyle: ui.BoxHeightStyle.tight'.allMatches(editor).length,
      greaterThanOrEqualTo(2),
    );

    // The body still uses the compact type size, but restores enough line
    // leading for Android drag handles to sit between lines cleanly.
    expect(editor, contains('final bodyFontSize = compact ? 18.0 : 19.0;'));
    expect(editor, contains('height: 1.45'));
    expect(editor, contains('textAlignVertical: TextAlignVertical.top'));
  });
}
