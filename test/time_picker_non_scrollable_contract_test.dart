import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('time picker clock does not inherit app-wide always-scrollable physics', () {
    final source = File('lib/ui_foundation.dart').readAsStringSync();

    expect(
      source,
      contains('bool _insideTimePickerDialog(BuildContext context)'),
    );
    expect(
      source,
      contains('context.findAncestorWidgetOfExactType<TimePickerDialog>() != null'),
    );
    expect(
      source,
      contains('if (_insideTimePickerDialog(context)) return const NeverScrollableScrollPhysics();'),
    );
    expect(
      source,
      contains('if (_insideEditableText(context) || _insideTimePickerDialog(context)) return child;'),
    );
  });
}
