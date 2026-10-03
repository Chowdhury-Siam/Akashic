import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app uses Inter and no active SF Pro font stack remains', () {
    final main = File('lib/main.dart').readAsStringSync();
    final worker = File('cloud/worker/src/profile.ts').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(main, contains("import 'package:google_fonts/google_fonts.dart';"));
    expect(main, contains('GoogleFonts.interTextTheme('));
    expect(main, contains("fontFamily: 'Inter'"));
    expect(main, isNot(contains('SF Pro Display')));
    expect(main, isNot(contains('SF Pro Text')));
    expect(worker, contains('font:15px/1.5 Inter,"Segoe UI",Roboto'));
    expect(worker, isNot(contains('SF Pro Display')));
    expect(pubspec, contains('google_fonts: ^8.2.1'));
    expect(pubspec, contains('version: 1.0.1266+310'));
  });
}
