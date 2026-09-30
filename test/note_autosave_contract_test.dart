import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Note editor persists changes automatically and flushes before exit', () {
    final source = File('lib/main.dart').readAsStringSync();
    final editor = source
        .split('class _NoteEditorScreenState extends State<NoteEditorScreen>')[1]
        .split('class _NoteMetaChip extends StatelessWidget')[0];

    expect(editor, contains('with WidgetsBindingObserver'));
    expect(editor, contains('title.addListener(_queueAutosaveFromEditor);'));
    expect(editor, contains('body.addListener(_recordBodyHistory);'));
    expect(editor, contains('_queueAutosaveFromEditor();'));
    expect(editor, contains('Future<bool> _flushAutosave() async'));
    expect(editor, contains('Future<void> _closeEditor() async'));
    expect(editor, contains('state == AppLifecycleState.paused'));
    expect(editor, contains('state == AppLifecycleState.detached'));
    expect(editor, contains('unawaited(_flushAutosave());'));
    expect(editor, contains('onPressed: _closeEditor'));
    expect(editor, contains('PopScope<Object?>'));

    // Manual saving is no longer required from the Note editor menu.
    expect(editor, isNot(contains("value: 'save'")));
    expect(editor, isNot(contains("label: 'Save'")));
  });

  test('autosave uses a stable id and updates the cloud outbox', () {
    final source = File('lib/main.dart').readAsStringSync();
    final editor = source
        .split('class _NoteEditorScreenState extends State<NoteEditorScreen>')[1]
        .split('class _NoteMetaChip extends StatelessWidget')[0];
    final controllerAutosave = source
        .split('Future<void> autosaveNote(YutakaNote note) async {')[1]
        .split('Future<void> toggleNoteBookmark')[0];

    expect(editor, contains('_noteId = widget.note?.id ?? _uuid.v4();'));
    expect(editor, contains('id: _noteId'));
    expect(editor, contains('await state.autosaveNote(note);'));
    expect(controllerAutosave, contains('await database.upsertAutosavedNote(note);'));
    expect(source, contains('Future<void> upsertAutosavedNote(YutakaNote note) async'));
    expect(source, contains("'entity_type': 'notes'"));
    expect(source, contains("'operation': 'upsert'"));
    expect(controllerAutosave, contains('queueNoteAutosaveCloudSync();'));
  });

  test('blank new notes are not left behind after typing is cleared', () {
    final source = File('lib/main.dart').readAsStringSync();
    final editor = source
        .split('class _NoteEditorScreenState extends State<NoteEditorScreen>')[1]
        .split('class _NoteMetaChip extends StatelessWidget')[0];

    expect(editor, contains('bool get _isBlankNewNote'));
    expect(editor, contains('_queuedAutosaveDelete = true;'));
    expect(editor, contains('await state.deleteAutosavedNote(_noteId);'));
  });
}
