import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { createClient } from '@libsql/client';
import { deleteAccountPortal, deleteOwnAccount, register, requireAuth } from '../src/index.ts';
import { deploymentSecrets } from '../scripts/prepare-secrets.mjs';

const origin = 'https://worker.example';
const schema = fs.readFileSync(new URL('../schema.sql', import.meta.url), 'utf8');

test('account holders can permanently delete themselves and a final deletion resets first-user registration', async t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'yutaka-delete-account-'));
  const databaseUrl = 'file:' + path.join(directory, 'test.db').replaceAll('\\', '/');
  const connect = () => createClient({ url: databaseUrl });
  const db = connect();
  t.after(async () => {
    db.close();
    await fs.promises.rm(directory, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
  });
  await db.executeMultiple(schema);
  const env = await deploymentSecrets({
    TURSO_DATABASE_URL: databaseUrl,
    TURSO_AUTH_TOKEN: 'local-test',
    JWT_SECRET: 'x'.repeat(40),
  });

  const registerResponse = await register(
    new Request(origin + '/v1/auth/register', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ username: 'delete-me', password: 'password123', deviceId: 'delete-device' }),
    }),
    env,
    db,
  );
  const session = await registerResponse.json() as any;
  const authRequest = new Request(origin + '/v1/sync/status', {
    headers: { authorization: `Bearer ${session.accessToken}` },
  });
  const auth = await requireAuth(authRequest, env, db);

  await db.execute({
    sql: `INSERT INTO telegram_backup_settings(user_id, enabled, chat_id, updated_at) VALUES (?, 0, '', ?)`,
    args: [auth.userId, Date.now()],
  });
  await db.execute({
    sql: `INSERT INTO analytics_upload_settings(user_id, google_client_id, google_account_email, google_folder_id, updated_at) VALUES (?, 'client', 'me@example.com', '', ?)`,
    args: [auth.userId, Date.now()],
  });
  await db.execute(`INSERT OR REPLACE INTO worker_state(key, value) VALUES ('deployment_recovery_ciphertext', 'secret')`);
  await db.execute(`INSERT OR REPLACE INTO worker_state(key, value) VALUES ('deployment_recovery_iv', 'iv')`);

  const deleted = await deleteOwnAccount(
    new Request(origin + '/v1/auth/account', {
      method: 'DELETE',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ password: 'password123', confirmation: 'DELETE' }),
    }),
    env,
    db,
    auth,
  );
  assert.equal(deleted.status, 200);
  const deletion = await deleted.json() as any;
  assert.equal(deletion.registrationReset, true);
  assert.equal(Number((await db.execute('SELECT COUNT(*) AS count FROM users')).rows[0].count), 0);
  assert.equal(Number((await db.execute('SELECT COUNT(*) AS count FROM refresh_tokens')).rows[0].count), 0);
  assert.equal(Number((await db.execute('SELECT COUNT(*) AS count FROM devices')).rows[0].count), 0);
  assert.equal(Number((await db.execute('SELECT COUNT(*) AS count FROM telegram_backup_settings')).rows[0].count), 0);
  assert.equal(Number((await db.execute('SELECT COUNT(*) AS count FROM analytics_upload_settings')).rows[0].count), 0);
  assert.equal(Number((await db.execute("SELECT COUNT(*) AS count FROM worker_state WHERE key IN ('deployment_owner_user_id','registration_closed','deployment_recovery_ciphertext','deployment_recovery_iv')")).rows[0].count), 0);

  const replacement = await register(
    new Request(origin + '/v1/auth/register', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ username: 'replacement-owner', password: 'password123', deviceId: 'replacement-device' }),
    }),
    env,
    db,
  );
  assert.equal(replacement.status, 200);
});

test('browser deletion page is self-service and requires password plus DELETE confirmation', async t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'yutaka-delete-web-'));
  const databaseUrl = 'file:' + path.join(directory, 'test.db').replaceAll('\\', '/');
  const connect = () => createClient({ url: databaseUrl });
  const db = connect();
  t.after(async () => {
    db.close();
    await fs.promises.rm(directory, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
  });
  await db.executeMultiple(schema);
  const env = await deploymentSecrets({ TURSO_DATABASE_URL: databaseUrl, TURSO_AUTH_TOKEN: 'local-test', JWT_SECRET: 'y'.repeat(40) });
  await register(
    new Request(origin + '/v1/auth/register', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ username: 'web-owner', password: 'password123', deviceId: 'web-device' }),
    }), env, db,
  );

  const page = await deleteAccountPortal(new Request(origin + '/delete-account'), env, connect);
  assert.equal(page.status, 200);
  assert.equal(page.headers.get('referrer-policy'), 'same-origin');
  const html = await page.text();
  assert.match(html, /Delete your Yutaka account/);
  assert.match(html, /Type DELETE to confirm/);
  assert.match(html, /Permanently delete account/);

  for (const rejectedOrigin of ['https://other.example', 'null']) {
    const rejected = await deleteAccountPortal(new Request(origin + '/delete-account', {
      method: 'POST',
      headers: { origin: rejectedOrigin, 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ username: 'web-owner', password: 'password123', confirmation: 'DELETE' }),
    }), env, connect);
    assert.equal(rejected.status, 403);
    assert.equal(rejected.headers.get('referrer-policy'), 'same-origin');
    assert.equal(Number((await db.execute('SELECT COUNT(*) AS count FROM users')).rows[0].count), 1);
  }

  const bad = await deleteAccountPortal(new Request(origin + '/delete-account', {
    method: 'POST',
    headers: { origin, 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ username: 'web-owner', password: 'password123', confirmation: 'delete' }),
  }), env, connect);
  assert.equal(bad.status, 400);

  const success = await deleteAccountPortal(new Request(origin + '/delete-account', {
    method: 'POST',
    headers: { origin, 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ username: 'web-owner', password: 'password123', confirmation: 'DELETE' }),
  }), env, connect);
  assert.equal(success.status, 200);
  assert.match(await success.text(), /Account deleted/);
  assert.equal(Number((await db.execute('SELECT COUNT(*) AS count FROM users')).rows[0].count), 0);
});
