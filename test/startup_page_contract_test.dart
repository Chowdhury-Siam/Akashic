import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup page setting defaults to Home and supports every primary tab', () async {
    final models = await File('lib/models.dart').readAsString();
    final main = await File('lib/main.dart').readAsString();

    expect(models, contains('enum StartupPage { home, analysis, loans, transaction, categories }'));
    expect(main, contains('StartupPage startupPage = StartupPage.home;'));
    expect(main, contains("prefs.getEnum('startupPage', StartupPage.values, StartupPage.home)"));
    expect(main, contains('tabIndex = _tabIndexForStartupPage(startupPage);'));
    expect(main, contains("title: 'Startup page'"));
    expect(main, contains("title: 'Choose Startup Page'"));
    expect(main, contains('DateRangeType dateRangeType = DateRangeType.allTime;'));
    expect(main, contains("prefs.getEnum('dateRangeType', DateRangeType.values, DateRangeType.allTime)"));
    expect(main, contains("sp.setString('dateRangeType', enumName(DateRangeType.allTime))"));

    for (final value in ['home', 'analysis', 'loans', 'transaction', 'categories']) {
      expect(main, contains('StartupPage.$value'));
    }
  });
}
