/// A failed settings request is unknown state, not an empty credential record.
class CredentialLoadResult<T> {
  const CredentialLoadResult.success(this.value) : error = null;
  const CredentialLoadResult.failure(this.error) : value = null;

  final T? value;
  final Object? error;
  bool get loaded => error == null;
}

class CloudCredentialsResult<T, D> {
  const CloudCredentialsResult(this.telegram, this.googleDrive);

  final CredentialLoadResult<T> telegram;
  final CredentialLoadResult<D> googleDrive;
}

Future<CredentialLoadResult<T>> loadCredential<T>(Future<T> Function() load) async {
  try {
    return CredentialLoadResult.success(await load());
  } catch (error) {
    return CredentialLoadResult.failure(error);
  }
}

/// Restore each provider independently so one unavailable endpoint cannot
/// discard the other provider's saved account credentials. Sequential requests
/// also avoid racing shared access-token refreshes.
Future<CloudCredentialsResult<T, D>> loadCloudCredentials<T, D>({
  required Future<T> Function() telegram,
  required Future<D> Function() googleDrive,
}) async {
  final savedTelegram = await loadCredential(telegram);
  final savedDrive = await loadCredential(googleDrive);
  return CloudCredentialsResult(savedTelegram, savedDrive);
}
