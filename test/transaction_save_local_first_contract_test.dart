import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/main.dart').readAsStringSync();
  final controllerStart = source.indexOf('class AppController extends ChangeNotifier');

  String methodBody(String signature, String nextSignature) {
    final start = source.indexOf(signature, controllerStart);
    final end = source.indexOf(nextSignature, start + signature.length);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    return source.substring(start, end);
  }

  test('ordinary transaction save refreshes only transaction projection', () {
    final add = methodBody(
      'Future<void> addTransaction(MoneyTransaction tx) async {',
      'Future<void> updateTransaction(MoneyTransaction tx) async {',
    );

    expect(add, contains('await database.addTransaction(tx);'));
    expect(add, contains("await database.enqueueTableRow('transactions', tx.id);"));
    expect(add, contains('await _enqueueTouchedTransactionAccounts([tx.fromAccountId, tx.toAccountId]);'));
    expect(add, contains('await _refreshTransactionProjection(queueSync: true);'));
    expect(add, isNot(contains('await reload(')));
    expect(add, isNot(contains('syncToCloud(')));
  });

  test('transaction projection avoids unrelated full-app reload work', () {
    final refresh = methodBody(
      'Future<void> _refreshTransactionProjection({bool queueSync = false}) async {',
      'Future<void> _enqueueTouchedTransactionAccounts(Iterable<String?> accountIds) async {',
    );

    expect(refresh, contains('accounts = await database.accounts();'));
    expect(refresh, contains('transactions = await database.transactions();'));
    expect(refresh, contains('_rebuildLookupCaches();'));
    expect(refresh, contains('notifyListeners();'));
    expect(refresh, contains('if (queueSync) queueCloudSync();'));
    expect(refresh, isNot(contains('_repairDuplicateCategories')));
    expect(refresh, isNot(contains('loanRepository.')));
    expect(refresh, isNot(contains('database.notes()')));
  });

  test('transaction update and delete queue only touched accounts when known', () {
    final update = methodBody(
      'Future<void> updateTransaction(MoneyTransaction tx) async {',
      'Future<void> deleteTransaction(String id) async {',
    );
    final delete = methodBody(
      'Future<void> deleteTransaction(String id) async {',
      'Future<void> saveBudget(Budget budget) async {',
    );

    expect(update, contains('previous.fromAccountId'));
    expect(update, contains('previous.toAccountId'));
    expect(update, contains('tx.fromAccountId'));
    expect(update, contains('tx.toAccountId'));
    expect(update, contains('await _refreshTransactionProjection(queueSync: true);'));
    expect(update, isNot(contains('await reload(')));

    expect(delete, contains('previous.fromAccountId'));
    expect(delete, contains('previous.toAccountId'));
    expect(delete, contains('await _refreshTransactionProjection(queueSync: true);'));
    expect(delete, isNot(contains('await reload(')));
  });
}
