# Delete a Yutaka sync account

Yutaka can be used completely offline without an account. If you created an account on a self-hosted Yutaka Sync Worker, you can permanently delete that account and its Worker-side data in either of these ways.

## In the Yutaka app

1. Open **Settings > Account & sync**.
2. Select **Delete account**.
3. Enter the account's current password.
4. Type **DELETE** exactly.
5. Choose whether the local offline copy on this device should also be deleted. This option is off by default.
6. Confirm **Delete account**.

## Without the app

Open Yutaka's public account-deletion page:

```text
https://chowdhury-siam.github.io/Yutaka/delete-account/
```

Enter only your Yutaka Sync Worker URL. The page redirects your browser to that Worker's own `/delete-account` form. Your username and password are entered only on your self-hosted Worker and are not collected by the public Yutaka page. Type **DELETE** on the Worker form and submit it. Reinstalling Yutaka is not required.

You can also open the Worker form directly at `https://<your-worker-host>/delete-account`.

## Data deleted from the Worker

Deleting the account permanently removes data owned by that account from the self-hosted Worker database, including:

- the sync account and password verifier;
- synchronized finance entities and change history;
- registered devices, access/refresh sessions, and recovery credentials;
- profile media stored by the Worker;
- Telegram and Google Drive backup configuration stored for the account; and
- Analytics upload configuration and schedules stored for the account.

If the deleted account is the Worker administrator, its web-administration sessions and encrypted deployment-recovery vault are also revoked. The oldest remaining account becomes administrator. If no accounts remain, the Worker returns to first-user registration.

## Data not automatically deleted

The browser deletion page cannot erase data outside that Worker. In particular, it does not automatically delete:

- local/offline copies already stored on a phone or computer; or
- backup/report files that were previously exported to Telegram or Google Drive.

The in-app deletion flow has a separate **Also delete local data from this device** option for the current device. Previously exported files must be removed from their destination service separately.

Account deletion is permanent and cannot be undone.
