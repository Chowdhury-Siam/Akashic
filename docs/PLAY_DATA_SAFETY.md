# Google Play Data Safety checklist for Yutaka

**Release baseline:** Yutaka 1.0.1274+318
**Reviewed:** 1 October 2026

This file documents the current code paths so the Play Console Data safety form can be completed consistently with the shipped app. Re-check this document whenever dependencies, permissions, sync behavior, telemetry, or integrations change.

## Privacy defaults in this release

- Finance data is local-first.
- Self-hosted sync is optional.
- Telegram and Google Drive delivery are optional.
- Firebase Analytics and Crashlytics collection are **off by default** and require an explicit user opt-in under **Settings > Privacy & data**.
- The Android manifest explicitly removes `com.google.android.gms.permission.AD_ID`.
- Profile photo/video selection uses Android's scoped system file picker; the Play build does **not** request `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_VISUAL_USER_SELECTED`, `READ_EXTERNAL_STORAGE`, or `WRITE_EXTERNAL_STORAGE`.
- The merged Play build does **not** request `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`; its settings shortcut opens Android's general battery-optimization screen instead of requesting direct exemption.
- Android OS-managed Auto Backup is disabled; explicit backup rules exclude app-private data from cloud backup and device-to-device transfer. Yutaka backups occur only through the app's user-controlled backup/export features.
- Yutaka has no advertising SDK.
- Yutaka does not intentionally send finance contents to Firebase telemetry.

## Data inventory

| Google Play data category | Yutaka data / source | Leaves device? | When | Purpose | Optional? | Developer receives it? |
| --- | --- | --- | --- | --- | --- | --- |
| Personal info → User IDs | Self-hosted sync username | Yes | When the user enables and signs into self-hosted sync | Account authentication and sync | Yes | No central Yutaka server; sent to the user's configured Worker |
| Financial info | Accounts, balances, transactions, budgets, loans, repayments, plans, subscriptions and related finance records | Yes | Only when self-hosted sync or an explicit export/delivery feature is used | Multi-device sync, backup, reports | Yes | No central Yutaka finance server; sent to user-configured infrastructure/destination |
| Photos and videos | Selected profile photo/GIF/video | Yes | Only when profile media is selected and self-hosted sync is enabled | Profile display across devices | Yes | No central Yutaka server; sent to the user's configured Worker |
| Files and docs | Generated `.yutakabackup`, PDF, XLSX or TXT reports | Yes | Only when the user saves, shares, or enables Telegram/Google Drive delivery | Backup/export/reporting | Yes | Sent only to the selected destination or user-configured Worker |
| App activity → App interactions | Firebase Analytics events, currently including app-open behavior | Yes | Only after the user enables telemetry | Product usage measurement | Yes | Firebase processes it for the configured Yutaka Firebase project |
| App info and performance → Crash logs | Firebase Crashlytics crash reports | Yes | Only after the user enables telemetry | Stability/debugging | Yes | Firebase processes it for the configured Yutaka Firebase project |
| App info and performance → Diagnostics | Technical diagnostics attached by Firebase SDKs | Yes | Only after the user enables telemetry | Stability/debugging | Yes | Firebase processes it for the configured Yutaka Firebase project |
| Device or other IDs | Firebase app-instance / similar SDK identifier | Yes | Only after the user enables telemetry | Analytics/crash service operation | Yes | Firebase processes it for the configured Yutaka Firebase project |

## User-directed external services

The following transfers happen only when the user configures or invokes the feature:

- **Self-hosted Cloudflare Worker / Turso** — synchronization, account/session handling, profile media, schedules, and Worker configuration.
- **Telegram** — backup/report files sent using the user's configured bot and destination.
- **Google Drive** — backup/report files sent using the user's configured OAuth connection and optional folder.
- **GitHub Releases** — direct-distribution builds can check release metadata and download updates.
- **Google Play** — Play-distributed Android builds use Google Play update infrastructure.
- **Google Fonts** — the Inter font can be fetched when it is not already cached/available.

When answering the Play Console “shared” questions, apply Google's current user-initiated transfer/service-provider exceptions to the exact production behavior rather than treating this table as an automatic legal classification.

## Data not used by Yutaka

The current Android app does not intentionally collect or request:

- contacts;
- SMS or MMS;
- call logs;
- microphone/audio recordings;
- precise or approximate location;
- health or fitness data;
- browsing history;
- calendar data; or
- advertising ID.

## Security / handling answers to verify in Play Console

- Data is transmitted over HTTPS for supported remote services.
- Sync authentication tokens and supported deployment secrets use platform secure storage.
- Worker-stored Telegram and Google OAuth secrets are encrypted with Worker-side keys.
- Users can request deletion of their self-hosted sync account and Worker-side data.
- Google Play account-deletion URL: `https://chowdhury-siam.github.io/Yutaka/delete-account/` (public page; no app installation required).
- Local device copies and previously exported external files are separate from Worker-side deletion and must be removed independently.
- Telemetry is optional and off by default.

## Before every Play release

1. Inspect `pubspec.yaml` for newly added SDKs.
2. Inspect the merged Play manifest for newly added permissions.
3. Confirm telemetry defaults remain disabled in both the manifest and Flutter bootstrap.
4. Confirm no finance values, transaction titles, notes, passwords, tokens, or integration secrets are added to Firebase events or crash custom keys.
5. Re-check Google Play's current Data safety definitions and update the Console answers if behavior or SDKs changed.
6. Keep the public Privacy Policy URL and account-deletion URL working without requiring app installation.
