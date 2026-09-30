import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bookmarked notes stay pinned above newer unbookmarked notes', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(
      source,
      contains("orderBy: 'bookmarked DESC, updated_on DESC, created_on DESC'"),
    );

    final comparator = source
        .split('int _compareNotesForList(YutakaNote a, YutakaNote b) {')[1]
        .split('class NoteScreen')[0];
    expect(
      comparator,
      contains('if (a.bookmarked != b.bookmarked) return a.bookmarked ? -1 : 1;'),
    );
    expect(comparator, contains('b.updatedOn.compareTo(a.updatedOn)'));

    final autosave = source
        .split('Future<void> autosaveNote(YutakaNote note) async {')[1]
        .split('Future<void> deleteAutosavedNote')[0];
    expect(autosave, contains('notes.sort(_compareNotesForList);'));

    final noteScreen = source
        .split('class _NoteScreenState extends State<NoteScreen>')[1]
        .split('class _NoteSectionTitle')[0];
    expect(noteScreen, contains('..sort(_compareNotesForList);'));
  });
}
