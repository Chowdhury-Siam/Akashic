# Yutaka Privacy Policy

**Effective date:** 30 September 2026  
**Last updated:** 30 September 2026

Yutaka is a local-first personal finance application developed by **Siam Chowdhury**. This policy explains what information Yutaka handles, when information leaves your device, which third-party services may receive information, and the controls available to you.

## 1. Local-first operation

Yutaka stores finance data locally on your device first. You can use Yutaka without creating a Yutaka sync account or connecting a cloud service.

Local data can include:

- accounts and balances;
- transactions and transfer records;
- categories and budgets;
- loans, repayments, due dates, and interest settings;
- plans and subscriptions;
- notes and app preferences;
- locally selected profile media; and
- locally generated backup and report files.

Yutaka does not operate a central server that automatically receives your finance database merely because you install or open the app.

## 2. Self-hosted multi-device sync

If you enable multi-device sync, Yutaka sends the information required for synchronization to the **Cloudflare Worker URL that you configure** and the database attached to that Worker.

Depending on the data you choose to synchronize, this can include finance records, notes, profile information, profile media, preferences required for synchronized behavior, sync metadata, and device/session information.

The Worker can also process:

- your sync username;
- a password-derived verifier used for authentication;
- access and refresh tokens;
- device/session records; and
- timestamps and version information needed for synchronization and conflict handling.

The self-hosted Worker and its connected database are controlled by you or the administrator of that Worker. They are not a Yutaka-operated central finance-data service.

## 3. Profile media and user-selected files

Yutaka only processes profile photos, GIFs, or short videos after you choose them. A local copy is stored in Yutaka app storage. If self-hosted synchronization is enabled, the selected media can also be uploaded to your configured Worker so it can appear on your other devices.

Files that you import, export, save, or share are handled according to the location or service that you select.

## 4. Telegram and Google Drive

Telegram backup/report delivery and Google Drive backup/report delivery are optional.

When you configure these features, Yutaka or your self-hosted Worker sends the information necessary to perform the requested operation to Telegram or Google. This can include generated finance backup/report files and the credentials required to authenticate the configured integration.

The self-hosted Worker encrypts stored Telegram bot tokens, Google OAuth client secrets, and Google OAuth refresh tokens with Worker-side keys before storing those credentials in its database.

Files already delivered to Telegram or Google Drive remain subject to the policies and retention controls of those services. Deleting a Yutaka sync account does not automatically delete files that were previously exported to an external service.

## 5. Optional usage analytics and crash reports

Usage analytics and crash reporting are **off by default**.

If you explicitly enable **Settings > Privacy & data > Usage analytics & crash reports**, Firebase may receive information such as:

- app-interaction events;
- crash logs;
- diagnostics and performance-related information;
- app/device information; and
- an app-instance or similar technical identifier used by the Firebase service.

Yutaka does not intentionally attach transaction titles, note contents, balances, account names, passwords, Worker access/refresh tokens, Telegram bot tokens, Google OAuth secrets, or backup contents to telemetry events.

You can disable this option at any time. The telemetry preference is device-specific and is not synchronized to your other devices.

## 6. Updates, fonts, and ordinary network metadata

Google Play builds use Google Play for Android updates. Direct-distribution builds can contact GitHub Releases to check for updates.

Yutaka uses the Inter typeface through the Google Fonts Flutter integration. When the font is not already available or cached, font resources can be requested from Google Fonts.

As with normal internet connections, the network provider serving a request can receive ordinary connection metadata such as an IP address, request time, and client/network information.

## 7. Android permissions

Yutaka can use Android permissions for the following purposes:

- internet/network state for explicitly used online features;
- notification and alarm capabilities for reminders and scheduled work;
- boot/background capabilities for restoring scheduled work after restart;
- battery-optimization access when you choose that flow; and
- media/storage access for files that you choose to import, export, or use as profile media.

Yutaka does not request contacts, SMS, call logs, microphone, or precise-location access. Yutaka does not contain an advertising SDK, and the Android manifest explicitly removes the Google advertising-ID permission.

## 8. Retention and deletion

Local data remains on a device until you delete it, clear app storage, or uninstall Yutaka, subject to any platform-level backup/restore behavior enabled on that device.

Self-hosted data remains in the configured Worker/database until it is deleted there or removed under the administrator's infrastructure retention rules.

Yutaka provides authenticated self-deletion for sync accounts inside the app. A public deletion gateway is also available without installing Yutaka at:

`https://chowdhury-siam.github.io/Yutaka/delete-account/`

The gateway asks only for the user's self-hosted Worker URL and redirects to that Worker's authenticated `/delete-account` form. Usernames and passwords are entered only on the user's Worker. The Worker form can also be opened directly at `https://<your-worker-host>/delete-account`.

Account deletion removes the account and its Worker-side synchronized finance data, profile media, device/session records, schedules, and stored integration credentials for that account. Local copies already present on devices and files already exported to Telegram or Google Drive must be removed separately.

See [`docs/ACCOUNT_DELETION.md`](docs/ACCOUNT_DELETION.md) for the full deletion behavior.

## 9. Security

Yutaka uses HTTPS for supported remote services and platform secure storage for supported authentication and deployment secrets. Worker-side integration credentials are encrypted as described above.

Local finance data is stored in app-private storage. You are responsible for protecting your device, your self-hosted Worker/database, your external-service accounts, and any exported backup or report files.

No application, device, network, or storage system can guarantee absolute security.

## 10. Data sale and advertising

Yutaka does **not** sell your personal or financial data.

Yutaka does not include an advertising SDK and does not request the Google advertising identifier in its Android manifest.

Third-party services are used only for the optional functions described in this policy, including self-hosted infrastructure, Telegram, Google Drive, Firebase telemetry when enabled, Google Fonts, Google Play, and GitHub Releases for direct-distribution updates.

## 11. Changes to this policy

This policy may be updated when Yutaka changes how information is handled. The latest public copy should always be linked from **Settings > Privacy & data** and from the Google Play listing.

## 12. Contact

For privacy questions or requests concerning Yutaka, contact:

**Siam Chowdhury**  
**Email:** ssiam4235@gmail.com
