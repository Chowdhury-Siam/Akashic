import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('centered date range picker draws the selected span inline', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('class _InlineRangeCalendar'));
    expect(source, contains('class _InlineRangeCalendarDay'));
    expect(source, contains('final roundRangeLeft = inRange && (start || rowColumn == 0)'));
    expect(source, contains('final roundRangeRight = inRange && (end || rowColumn == 6)'));
    expect(source, contains('if (inRange)'));
    expect(source, contains('color: kSleekAccent.withOpacity(.14)'));
    expect(source, contains('BorderRadius.horizontal('));
    expect(source, isNot(contains('height: 4,')));
    expect(source, contains('border: endpoint && !active ? Border.all(color: kSleekAccent, width: 2) : null'));
    expect(source, contains('_InlineRangeCalendar('));
    expect(source, isNot(contains('child: CalendarDatePicker(')));
  });

  test('transaction date and time pickers support opt-in ranges in fixed popup content', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('class TransactionDateSelection'));
    expect(source, contains("label: 'Single date'"));
    expect(source, contains("label: 'Use range'"));
    expect(source, contains("'Select transaction date'"));
    expect(source, contains('child: YutakaPopupContent('));
    expect(source, contains('pickTransactionTimeSelection'));
    expect(source, contains("label: 'Single time'"));
    expect(source, contains("'Select transaction time range'"));
    expect(source, contains('timeRangeEnabled'));
    expect(source, contains('dateRangeEnabled'));
    expect(source, contains("title: 'Time • Date'"));
    expect(source, contains('showTransactionDateTimeConfiguration('));
    expect(source, contains('endOn: hasEffectiveRange ? selectedEndDate : null'));
    expect(source, contains('Future<DateTimeRange?> pickCustomDateRange('));
    expect(source, contains('rangeOnly: true'));
    expect(source, contains("title = 'Select custom range'"));
    expect(source, contains("title: 'Custom range'"));
    expect(source, contains("'Start: \${DateFormat('MMM d, yyyy').format(start)} - End: \${DateFormat('MMM d, yyyy').format(end)}'"));
  });

  test('new transaction amount uses a focus-aware placeholder instead of a real zero', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('final amount = TextEditingController();'));
    expect(source, isNot(contains("final amount = TextEditingController(text: '0');")));
    expect(source, contains('final amountFocus = FocusNode();'));
    expect(source, contains("hintText: _amountHasFocus ? null : '0'"));
    expect(source, contains('_dismissAmountFocus();'));
  });

  test('transaction editor uses fixed popup content without page scrolling', () {
    final source = File('lib/main.dart').readAsStringSync();
    final start = source.indexOf('class _TransactionEditorState');
    final end = source.indexOf('Future<void> showDateRangeSheet', start);
    final editor = source.substring(start, end);

    expect(editor, contains('child: YutakaPopupContent('));
    expect(editor, isNot(contains('SingleChildScrollView(')));
    expect(editor, isNot(contains('Scrollable.ensureVisible(')));
    expect(editor, isNot(contains('MediaQuery.viewInsetsOf(context).bottom')));
    expect(editor, contains('controller: notes'));
  });
}
