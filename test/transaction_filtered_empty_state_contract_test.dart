import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transaction list distinguishes filtered-empty from truly empty data', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains("title: 'No transactions yet'"));
    expect(source, contains("title = 'No transactions for \${range.label}'"));
    expect(source, contains("title = 'No transactions match these filters'"));
    expect(source, contains("title = 'No transactions are visible'"));
    expect(source, contains("child: const Text('Show all transactions')"));
    expect(source, contains("secondaryActionLabel = 'Change date range'"));
    expect(source, contains("secondaryActionLabel = 'Clear filters'"));
  });

  test('transaction filter state exposes total count and active date controls', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains("'\${txs.length} shown • \$totalTransactionCount total • \${range.label}"));
    expect(source, contains("ValueKey('transaction-date-range-button')"));
    expect(source, contains("ValueKey('transaction-filter-button')"));
    expect(source, contains("ValueKey('transaction-active-date-chip')"));
    expect(source, contains('IconButton.filledTonal('));
  });

  test('show all resets view preferences without deleting transaction data', () {
    final source = File('lib/main.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _showAllTransactions(AppController state) async');
    final end = source.indexOf('class TransactionListEmptyState', start);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final helper = source.substring(start, end).replaceAll(RegExp(r'//[^\n]*'), '');
    expect(helper, contains('state.setDateRange(DateRangeType.allTime)'));
    expect(helper, contains('state.clearFilters()'));
    expect(helper, isNot(contains('deleteTransaction')));
    expect(helper, isNot(contains('repo.')));
    expect(helper, isNot(matches(RegExp(r'\b\w*[Ss]ync\w*\s*\('))));
  });
}
