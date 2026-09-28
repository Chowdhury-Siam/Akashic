import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Note list cards render titles without note body previews', () {
    final source = File('lib/main.dart').readAsStringSync();
    final tile = source
        .split('class NoteTile extends StatelessWidget')[1]
        .split('Future<void> showNoteEditor')[0];
    final screen = source
        .split('class _NoteScreenState extends State<NoteScreen>')[1]
        .split('class _NoteSectionTitle extends StatelessWidget')[0];

    expect(tile, contains("final title = note.title.trim().isEmpty ? 'Untitled note' : note.title.trim();"));
    expect(tile, isNot(contains('plainTextFromStored(note.body)')));
    expect(tile, isNot(contains('body.isNotEmpty')));

    // Search can still match note content even though cards do not display it.
    expect(screen, contains('NoteRichTextController.plainTextFromStored(note.body)'));
  });
}
