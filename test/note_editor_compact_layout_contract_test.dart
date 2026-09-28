import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('note editor uses the compact reference layout on phones', () {
    final source = File('lib/main.dart').readAsStringSync();
    final start = source.indexOf('class _NoteEditorScreenState');
    final end = source.indexOf('class _NoteMetaChip', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final editor = source.substring(start, end);

    expect(editor, contains('final sidePadding = compact ? 16.0 : 24.0;'));
    expect(editor, contains('final circleSize = compact ? 40.0 : 44.0;'));
    expect(editor, contains('final metaControlSize = compact ? 34.0 : 38.0;'));
    expect(editor, contains('final titleFontSize = compact ? 28.0 : 30.0;'));
    expect(editor, contains('final bodyFontSize = compact ? 18.0 : 19.0;'));
    expect(editor, contains('height: 1.45'));
    expect(editor, contains('contentPadding: EdgeInsets.zero'));
    expect(editor, contains('icon: Icons.calendar_month_rounded'));
    expect(editor, contains('size: metaControlSize'));
    expect(editor, contains('child: SizedBox.square('));
    expect(editor, isNot(contains('icon: const Icon(Icons.more_vert_rounded)')));
  });
}
