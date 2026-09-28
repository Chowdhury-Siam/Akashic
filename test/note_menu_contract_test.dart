import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Note overflow menu does not expose Select title', () {
    final source = File('lib/main.dart').readAsStringSync();
    final start = source.indexOf('class _NoteEditorScreenState');
    final end = source.indexOf('class _NoteMetaChip', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final editor = source.substring(start, end);

    expect(editor, isNot(contains("label: 'Select title'")));
    expect(editor, isNot(contains("value: 'title'")));
    expect(editor, isNot(contains("if (value == 'title')")));

    for (final action in ['Bookmark', 'Mark draft', 'Delete']) {
      expect(editor, contains(action));
    }
  });
}
