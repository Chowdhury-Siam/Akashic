import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Analysis app bar does not show a date-range action', () {
    final source = File('lib/main.dart').readAsStringSync();
    final screenStart = source.indexOf('class _AnalysisScreenState');
    final chartStart = source.indexOf('class AnalysisTrendChart');
    expect(screenStart, greaterThanOrEqualTo(0));
    expect(chartStart, greaterThan(screenStart));

    final screen = source.substring(screenStart, chartStart);
    expect(screen, isNot(contains("tooltip: 'Change date range'")));
    expect(screen, isNot(contains('showDateRangeSheet(context)')));
    expect(screen, contains("tooltip: 'Filter analysis'"));

    final chartBuildStart = source.indexOf('Widget build(BuildContext context)', chartStart);
    final chartEnd = source.indexOf('class _TrendMetricPill', chartBuildStart);
    expect(chartBuildStart, greaterThanOrEqualTo(chartStart));
    expect(chartEnd, greaterThan(chartBuildStart));
    final chartBuild = source.substring(chartBuildStart, chartEnd);
    expect(chartBuild, isNot(contains("tooltip: 'Change date range'")));
  });
}
