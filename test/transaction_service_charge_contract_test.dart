import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yutaka/models.dart';

void main() {
  test('service charge metadata survives transaction map round trips', () {
    final now = DateTime.utc(2026, 9, 30, 20, 0);
    final transaction = MoneyTransaction(
      id: 'tx-service-charge',
      type: MoneyTransactionType.expense,
      amount: 105,
      baseAmount: 100,
      serviceChargeEnabled: true,
      serviceChargeMode: ServiceChargeMode.percentage,
      serviceChargeValue: 5,
      serviceChargeAmount: 5,
      title: 'Dinner',
      notes: '',
      categoryId: 'food',
      fromAccountId: 'cash',
      createdOn: now,
      updatedOn: now,
    );

    final restored = MoneyTransaction.fromMap(transaction.toMap());
    expect(restored.amount, 105);
    expect(restored.baseAmount, 100);
    expect(restored.serviceChargeEnabled, isTrue);
    expect(restored.serviceChargeMode, ServiceChargeMode.percentage);
    expect(restored.serviceChargeValue, 5);
    expect(restored.serviceChargeAmount, 5);
  });

  test('legacy and default transactions keep service charge off', () {
    final now = DateTime.utc(2026, 9, 30, 20, 0);
    final map = MoneyTransaction(
      id: 'legacy',
      type: MoneyTransactionType.expense,
      amount: 100,
      title: 'Legacy',
      notes: '',
      categoryId: 'food',
      fromAccountId: 'cash',
      createdOn: now,
      updatedOn: now,
    ).toMap()
      ..remove('base_amount')
      ..remove('service_charge_enabled')
      ..remove('service_charge_mode')
      ..remove('service_charge_value')
      ..remove('service_charge_amount');

    final restored = MoneyTransaction.fromMap(map);
    expect(restored.baseAmount, 100);
    expect(restored.serviceChargeEnabled, isFalse);
    expect(restored.serviceChargeMode, ServiceChargeMode.number);
    expect(restored.serviceChargeValue, 0);
    expect(restored.serviceChargeAmount, 0);
  });

  test('transaction editor combines time/date and exposes service charge configuration', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains("title: 'Time • Date'"));
    expect(source, contains("title: 'Service charge'"));
    expect(source, contains("'Enable service charge'"));
    expect(source, contains("label: 'Number'"));
    expect(source, contains("label: 'Percentage'"));
    expect(source, contains('showTransactionDateTimeConfiguration('));
    expect(source, contains('showServiceChargeConfiguration('));
    expect(source, contains('serviceChargeEnabled = false'));
  });

  test('database schema persists service charge fields and transfer fees stay source-only', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('base_amount REAL NOT NULL DEFAULT 0'));
    expect(source, contains('service_charge_enabled INTEGER NOT NULL DEFAULT 0'));
    expect(source, contains("service_charge_mode TEXT NOT NULL DEFAULT 'number'"));
    expect(source, contains('service_charge_value REAL NOT NULL DEFAULT 0'));
    expect(source, contains('service_charge_amount REAL NOT NULL DEFAULT 0'));
    expect(source, contains("await updateAmount(tx.toAccountId ?? '', tx.baseAmount);"));
  });
}
