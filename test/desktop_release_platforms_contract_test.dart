import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _workflow(String name) =>
    File('.github/workflows/$name').readAsStringSync();

String _jobBlock(String workflow, String job) {
  final start = workflow.indexOf('\n  $job:');
  expect(start, greaterThanOrEqualTo(0), reason: '$job is missing');
  final next = workflow.indexOf(
    RegExp(r'\n  [a-zA-Z0-9_-]+:'),
    start + job.length + 4,
  );
  return workflow.substring(start, next < 0 ? workflow.length : next);
}

void main() {
  test('desktop releases are split into independent Windows Linux and macOS workflows', () {
    final android = _workflow('build-android-apks.yml');
    final windows = _workflow('build-windows.yml');
    final linux = _workflow('build-linux.yml');
    final macos = _workflow('build-macos.yml');
    final publisher = _workflow('publish-stable-release.yml');

    expect(android, contains('name: Build Android Releases'));
    expect(android, isNot(contains('build-windows:')));
    expect(android, isNot(contains('build-linux:')));
    expect(android, isNot(contains('build-macos:')));

    expect(windows, contains('name: Build Windows Release'));
    expect(windows, contains('build-windows:'));
    expect(windows, isNot(contains('build-linux:')));
    expect(windows, isNot(contains('build-macos:')));

    expect(linux, contains('name: Build Linux Releases'));
    expect(linux, contains('build-linux:'));
    expect(linux, contains('ubuntu-22.04-arm'));
    expect(linux, contains("if: matrix.arch == 'arm64'"));
    expect(linux, contains('git clone --depth 1 --branch 3.47.4'));
    expect(linux, contains('flutter build linux --release'));
    expect(linux, contains('imagemagick'));
    expect(linux, contains('-resize 512x512!'));
    expect(
      linux,
      contains(r'linuxdeploy-${{ matrix.appimage_arch }}.AppImage'),
    );
    expect(linux, contains('Restore linuxdeploy tool cache'));
    expect(linux, contains('tools/linux/fetch_linuxdeploy.sh'));
    expect(linux, contains(r'GH_TOKEN: ${{ github.token }}'));
    final linuxdeployFetcher =
        File('tools/linux/fetch_linuxdeploy.sh').readAsStringSync();
    expect(linuxdeployFetcher, contains('gh release download'));
    expect(linuxdeployFetcher, contains('--retry-all-errors'));
    expect(linuxdeployFetcher, contains('validate_linuxdeploy'));
    expect(linuxdeployFetcher, contains("file -b"));
    expect(
      linux,
      contains(
        r'Yutaka-v${YUTAKA_APP_VERSION_NAME}-linux-${{ matrix.arch }}.tar.gz',
      ),
    );

    expect(macos, contains('name: Build macOS Release'));
    expect(macos, contains('build-macos:'));
    expect(macos, contains('runs-on: macos-15'));
    expect(macos, isNot(contains('runs-on: macos-15-intel')));
    expect(macos, contains('Restore pinned Flutter SDK cache'));
    expect(macos, contains('Set up pinned Flutter on Apple Silicon'));
    expect(macos, contains('--filter=blob:none --single-branch --depth 1'));
    expect(macos, contains('Restore macOS dependency cache'));
    expect(macos, contains('Restore macOS incremental build cache'));
    expect(macos, contains('build/macos'));
    expect(macos, contains('FLUTTER_MACOS_ARM64_ONLY: "false"'));
    expect(macos, contains('flutter build macos --release'));
    expect(macos, contains('lipo -archs'));
    expect(macos, contains('macos-universal.dmg'));
    expect(macos, contains('macos-universal.zip'));
    expect(macos, contains('xcrun notarytool submit'));

    expect(publisher, contains('name: Publish Stable Release'));
    expect(publisher, contains('workflow_run:'));
    expect(publisher, contains('Build Android Releases'));
    expect(publisher, contains('Build Windows Release'));
    expect(publisher, contains('Build Linux Releases'));
    expect(publisher, contains('Build macOS Release'));
    expect(publisher, contains('resolve_run build-android-apks.yml'));
    expect(publisher, contains('resolve_run build-windows.yml'));
    expect(publisher, contains('resolve_run build-linux.yml'));
    expect(publisher, contains('resolve_run build-macos.yml'));
    expect(publisher, contains('yutaka-linux-x64'));
    expect(publisher, contains('yutaka-linux-arm64'));
    expect(publisher, contains('yutaka-macos-universal'));
  });

  test('release package jobs never build in fork repositories', () {
    final workflows = <String, String>{
      'build-android-apks.yml': _workflow('build-android-apks.yml'),
      'build-windows.yml': _workflow('build-windows.yml'),
      'build-linux.yml': _workflow('build-linux.yml'),
      'build-macos.yml': _workflow('build-macos.yml'),
      'publish-stable-release.yml': _workflow('publish-stable-release.yml'),
    };

    for (final entry in workflows.entries) {
      expect(
        entry.value,
        isNot(
          contains(
            "github.event_name == 'workflow_dispatch' || github.repository == 'Chowdhury-Siam/Yutaka'",
          ),
        ),
        reason: entry.key,
      );
    }

    final guardedJobs = <String, List<String>>{
      'build-android-apks.yml': <String>[
        'prepare-worker-bundle',
        'android-release-quality-gate',
        'worker-data-integrity-gate',
        'android-upgrade-data-loss-gate',
        'build-apks',
      ],
      'build-windows.yml': <String>['prepare-worker-bundle', 'build-windows'],
      'build-linux.yml': <String>['prepare-worker-bundle', 'build-linux'],
      'build-macos.yml': <String>['prepare-worker-bundle', 'build-macos'],
      'publish-stable-release.yml': <String>['publish-stable-release'],
    };

    for (final entry in guardedJobs.entries) {
      final workflow = workflows[entry.key]!;
      for (final job in entry.value) {
        final block = _jobBlock(workflow, job);
        expect(
          block,
          contains("github.repository == 'Chowdhury-Siam/Yutaka'"),
          reason: '${entry.key}: $job must stay disabled in forks',
        );
      }
    }
  });

  test('desktop platform metadata stays versioned and documented', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final config = File('lib/app_config.dart').readAsStringSync();
    final androidGradle = File('android/app/build.gradle').readAsStringSync();
    final readme = File('README.md').readAsStringSync();

    expect(pubspec, contains('version: 1.0.1238+282'));
    expect(config, contains("defaultValue: '1.0.1238'"));
    expect(androidGradle, contains('versionCode = 282'));
    expect(androidGradle, contains('versionName = "1.0.1238"'));
    expect(readme, contains('Android, Windows, Linux, and macOS'));
    expect(readme, contains('universal macOS package'));
    expect(File('tools/linux/yutaka.desktop').existsSync(), isTrue);
  });
}
