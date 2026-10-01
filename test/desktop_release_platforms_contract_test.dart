import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release workflow builds Linux and universal macOS desktop packages', () {
    final workflow =
        File('.github/workflows/build-android-apks.yml').readAsStringSync();

    expect(workflow, contains('build-linux:'));
    expect(workflow, contains('ubuntu-22.04-arm'));
    expect(workflow, contains("if: matrix.arch == 'arm64'"));
    expect(workflow, contains('git clone --depth 1 --branch 3.47.4'));
    expect(workflow, contains('flutter build linux --release'));
    expect(workflow, contains('imagemagick'));
    expect(workflow, contains('-resize 512x512!'));
    expect(
      workflow,
      contains(r'linuxdeploy-${{ matrix.appimage_arch }}.AppImage'),
    );
    expect(workflow, contains('Restore linuxdeploy tool cache'));
    expect(workflow, contains('tools/linux/fetch_linuxdeploy.sh'));
    expect(workflow, contains(r'GH_TOKEN: ${{ github.token }}'));
    final linuxdeployFetcher =
        File('tools/linux/fetch_linuxdeploy.sh').readAsStringSync();
    expect(linuxdeployFetcher, contains('gh release download'));
    expect(linuxdeployFetcher, contains('--retry-all-errors'));
    expect(linuxdeployFetcher, contains('validate_linuxdeploy'));
    expect(linuxdeployFetcher, contains("file -b"));
    expect(
      workflow,
      contains(
        r'Yutaka-v${YUTAKA_APP_VERSION_NAME}-linux-${{ matrix.arch }}.tar.gz',
      ),
    );

    expect(workflow, contains('build-macos:'));
    expect(workflow, contains('runs-on: macos-15'));
    expect(workflow, isNot(contains('runs-on: macos-15-intel')));
    expect(workflow, contains('Restore pinned Flutter SDK cache'));
    expect(workflow, contains('Set up pinned Flutter on Apple Silicon'));
    expect(workflow, contains('--filter=blob:none --single-branch --depth 1'));
    expect(workflow, contains('Restore macOS dependency cache'));
    expect(workflow, contains('Restore macOS incremental build cache'));
    expect(workflow, contains('build/macos'));
    expect(workflow, contains('FLUTTER_MACOS_ARM64_ONLY: "false"'));
    expect(workflow, contains('flutter build macos --release'));
    expect(workflow, contains('lipo -archs'));
    expect(workflow, contains('macos-universal.dmg'));
    expect(workflow, contains('macos-universal.zip'));
    expect(workflow, contains('xcrun notarytool submit'));

    expect(workflow, contains('pattern: yutaka-linux-*'));
    expect(workflow, contains('pattern: yutaka-macos-*'));
  });


  test('release package jobs never build in fork repositories', () {
    final workflow =
        File('.github/workflows/build-android-apks.yml').readAsStringSync();

    expect(
      workflow,
      isNot(
        contains(
          "github.event_name == 'workflow_dispatch' || github.repository == 'Chowdhury-Siam/Yutaka'",
        ),
      ),
    );
    const guardedJobs = <String>[
      'prepare-worker-bundle',
      'android-release-quality-gate',
      'worker-data-integrity-gate',
      'android-upgrade-data-loss-gate',
      'build-apks',
      'build-windows',
      'build-linux',
      'build-macos',
      'publish-stable-release',
    ];
    for (final job in guardedJobs) {
      final start = workflow.indexOf('\n  $job:');
      expect(start, greaterThanOrEqualTo(0), reason: '$job is missing');
      final next = workflow.indexOf(
        RegExp(r'\n  [a-zA-Z0-9_-]+:'),
        start + job.length + 4,
      );
      final block = workflow.substring(start, next < 0 ? workflow.length : next);
      expect(
        block,
        contains("github.repository == 'Chowdhury-Siam/Yutaka'"),
        reason: '$job must stay disabled in forks',
      );
    }
  });

  test('desktop platform metadata stays versioned and documented', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final config = File('lib/app_config.dart').readAsStringSync();
    final androidGradle = File('android/app/build.gradle').readAsStringSync();
    final readme = File('README.md').readAsStringSync();

    expect(pubspec, contains('version: 1.0.1236+280'));
    expect(config, contains("defaultValue: '1.0.1236'"));
    expect(androidGradle, contains('versionCode = 280'));
    expect(androidGradle, contains('versionName = "1.0.1236"'));
    expect(readme, contains('Android, Windows, Linux, and macOS'));
    expect(readme, contains('universal macOS package'));
    expect(File('tools/linux/yutaka.desktop').existsSync(), isTrue);
  });
}
