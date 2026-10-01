import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('privacy policy and Play data safety artifacts are shipped', () {
    expect(File('PRIVACY_POLICY.md').readAsStringSync(), contains('Yutaka Privacy Policy'));
    expect(File('docs/PLAY_DATA_SAFETY.md').readAsStringSync(), contains('Google Play Data Safety checklist'));
    expect(File('docs/privacy-policy.html').readAsStringSync(), contains('<title>Yutaka Privacy Policy</title>'));
    expect(File('docs/delete-account/index.html').readAsStringSync(), contains('<title>Delete your Yutaka account</title>'));
  });

  test('Firebase telemetry is opt-in and advertising ID is removed', () {
    final source = File('lib/main.dart').readAsStringSync();
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final config = File('lib/app_config.dart').readAsStringSync();

    expect(config, contains("kPrivacyTelemetryPreferenceKey = 'privacyTelemetryEnabled'"));
    expect(source, contains('privacyTelemetryEnabled = await prefs.getBool(kPrivacyTelemetryPreferenceKey, false)'));
    expect(source, contains('setAnalyticsCollectionEnabled(telemetryEnabled)'));
    expect(source, contains('setCrashlyticsCollectionEnabled(telemetryEnabled)'));
    expect(source, contains('if (!_privacyTelemetryRuntimeEnabled) return false'));
    expect(manifest, contains('firebase_analytics_collection_enabled'));
    expect(manifest, contains('firebase_crashlytics_collection_enabled'));
    expect(manifest, contains('com.google.android.gms.permission.AD_ID'));
    expect(manifest, contains('tools:node="remove"'));
  });

  test('Settings exposes privacy and full in-app policy', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains("title: 'Privacy & data'"));
    expect(source, contains('class PrivacyAndDataScreen extends StatelessWidget'));
    expect(source, contains('class PrivacyPolicyScreen extends StatelessWidget'));
    expect(source, contains("title: 'Public Privacy Policy'"));
    expect(source, contains("title: 'Account deletion information'"));
    expect(File('lib/app_config.dart').readAsStringSync(), contains('https://chowdhury-siam.github.io/Yutaka/privacy-policy.html'));
    expect(File('lib/app_config.dart').readAsStringSync(), contains('https://chowdhury-siam.github.io/Yutaka/delete-account/'));
  });
}
