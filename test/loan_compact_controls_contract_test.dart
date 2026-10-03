import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loan editor uses compact Time Date Interest and Due date configuration buttons', () {
    final sheet = File('lib/loans/loan_sheets.dart').readAsStringSync();
    final start = sheet.indexOf('class _LoanEditorSheetState');
    final end = sheet.indexOf('Future<void> showLoanPaymentSheet', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final editor = sheet.substring(start, end);

    expect(sheet, contains('showLoanStartDateTimeConfiguration('));
    expect(sheet, contains("'Time • Date'"));
    expect(sheet, contains('showLoanInterestConfiguration('));
    expect(sheet, contains("'Interest'"));
    expect(editor, contains('final selection = await showLoanStartDateTimeConfiguration('));
    expect(editor, contains('final selection = await showLoanInterestConfiguration('));
    expect(editor, isNot(contains("SectionHeader('Interest')")));
    expect(editor, isNot(contains("label: Text('Start ·")));
    expect(editor, isNot(contains("label: Text('Time ·")));
    expect(editor, contains('final selection = await showLoanDueDateTimeConfiguration('));
    expect(editor, contains("title: 'Due date'"));
    expect(editor, contains('setState(() => dueDate = selection.dueDate)'));
    expect(editor, isNot(contains("title: const Text('Set a due date'")));
  });
}
