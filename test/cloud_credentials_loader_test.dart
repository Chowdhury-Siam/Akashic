import 'package:flutter_test/flutter_test.dart';
import 'package:yutaka/cloud_credentials_loader.dart';
import 'package:yutaka/sync_models.dart';

void main() {
  final savedTelegram = TelegramBackupSettings.fromJson({
    'tokenConfigured': true, 'chatId': '-1001234567890', 'enabled': true,
  });
  final savedDrive = GoogleDriveAnalyticsSettings.fromJson({
    'clientSecretConfigured': true, 'connected': true, 'clientId': 'saved-client',
  });

  test('fresh device recovers both saved providers without supplying secret values', () async {
    final result = await loadCloudCredentials(
      telegram: () async => savedTelegram,
      googleDrive: () async => savedDrive,
    );
    expect(result.telegram.value?.tokenConfigured, isTrue);
    expect(result.telegram.value?.chatId, '-1001234567890');
    expect(result.googleDrive.value?.connected, isTrue);
    expect(result.googleDrive.value?.clientSecretConfigured, isTrue);
  });

  test('a failed Drive request does not discard a saved Telegram token', () async {
    final result = await loadCloudCredentials<TelegramBackupSettings, GoogleDriveAnalyticsSettings>(
      telegram: () async => savedTelegram,
      googleDrive: () async => throw StateError('Drive unavailable'),
    );
    expect(result.telegram.loaded, isTrue);
    expect(result.telegram.value?.tokenConfigured, isTrue);
    expect(result.googleDrive.loaded, isFalse);
    expect(result.googleDrive.value, isNull);
  });

  test('a failed Telegram request is unknown state and Drive still restores', () async {
    final result = await loadCloudCredentials<TelegramBackupSettings, GoogleDriveAnalyticsSettings>(
      telegram: () async => throw StateError('Network unavailable'),
      googleDrive: () async => savedDrive,
    );
    expect(result.telegram.loaded, isFalse);
    expect(result.telegram.value, isNull);
    expect(result.telegram.error, isNotNull);
    expect(result.googleDrive.value?.connected, isTrue);
  });

  test('an account with no saved token is distinguishable from a load failure', () async {
    final result = await loadCloudCredentials(
      telegram: () async => const TelegramBackupSettings.defaults(),
      googleDrive: () async => const GoogleDriveAnalyticsSettings.defaults(),
    );
    expect(result.telegram.loaded, isTrue);
    expect(result.telegram.value?.tokenConfigured, isFalse);
    expect(result.telegram.error, isNull);
  });
}
