import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('financial health review uses a dedicated responsive scrollable surface', () {
    final source = File('lib/main.dart').readAsStringSync();
    final gateStart = source.indexOf('class _FinancialHealthReviewGateState');
    final dialogStart = source.indexOf('class _FinancialHealthReviewDialogState');
    final splashStart = source.indexOf('class SplashScreen', dialogStart);
    final popupStart = source.indexOf('Future<T?> showFinancialHealthReviewPopup<T>');
    final sharedFrameStart = source.indexOf('class _YutakaPopupFrame extends StatelessWidget', popupStart);

    expect(gateStart, greaterThanOrEqualTo(0));
    expect(dialogStart, greaterThan(gateStart));
    expect(splashStart, greaterThan(dialogStart));
    expect(popupStart, greaterThanOrEqualTo(0));
    expect(sharedFrameStart, greaterThan(popupStart));

    final gate = source.substring(gateStart, dialogStart);
    final dialog = source.substring(dialogStart, splashStart);
    final popup = source.substring(popupStart, sharedFrameStart);

    expect(gate, contains('showFinancialHealthReviewPopup<void>('));
    expect(gate, isNot(contains('showYutakaPopup<void>(')));

    expect(dialog, contains('SingleChildScrollView('));
    expect(dialog, contains('FinancialHealthSummarySection(summary: summary)'));
    expect(dialog, contains('height: 52'));
    expect(dialog, isNot(contains('YutakaPopupContent(')));
    expect(dialog, isNot(contains('height: 760')));

    expect(popup, contains('final useFullScreen = safeWidth < 720 || safeHeight < 760;'));
    expect(popup, contains('SizedBox.expand(child: child)'));
    expect(popup, contains('width = math.min(900.0'));
    expect(popup, contains('height = math.min(900.0'));
    expect(popup, isNot(contains('FittedBox(')));
    expect(popup, isNot(contains('BoxFit.scaleDown')));
  });
}
