import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { createClient } from '@libsql/client';
import worker from '../src/index.ts';
import { deploymentSecrets } from '../scripts/prepare-secrets.mjs';

const schema = fs.readFileSync(new URL('../schema.sql', import.meta.url), 'utf8');
const origin = 'https://worker.example';
const context = {
  waitUntil() {},
  passThroughOnException() {},
  props: {},
} as unknown as ExecutionContext;

test('legacy destructive replace is blocked and pre-reset finance history is recovered', async t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'yutaka-data-loss-'));
  const databaseUrl = 'file:' + path.join(directory, 'test.db').replaceAll('\\', '/');
  const db = createClient({ url: databaseUrl });
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
  const call = (route: string, method = 'GET', body?: unknown, accessToken = '') => worker.fetch(
    new Request(origin + route, {
      method,
      headers: {
        'content-type': 'application/json',
        ...(accessToken ? { authorization: `Bearer ${accessToken}` } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    }),
    env,
    context,
  );

  const registration = await call('/v1/auth/register', 'POST', {
    username: 'owner',
    password: 'password123',
    deviceId: 'device-a',
  });
  assert.equal(registration.status, 200);
  const session = await registration.json() as { accessToken: string };
  const userId = String((await db.execute('SELECT id FROM users LIMIT 1')).rows[0].id);

  const transactionPayload = JSON.stringify({
    id: 'tx-preserve',
    type: 'expense',
    amount: 42,
    title: 'Preserve me',
    created_on: 100,
    updated_on: 100,
  });
  await db.batch([
    {
      sql: `INSERT INTO sync_changes(user_id, entity_type, entity_id, operation, version, payload_json, device_id, operation_id, changed_at)
            VALUES (?, 'transactions', 'tx-preserve', 'upsert', 3, ?, 'old-device', 'old-upsert', 100)`,
      args: [userId, transactionPayload],
    },
    {
      sql: `INSERT INTO sync_changes(user_id, entity_type, entity_id, operation, version, payload_json, device_id, operation_id, changed_at)
            VALUES (?, '__reset__', 'finance', 'delete', 0, NULL, 'old-device', 'legacy-reset', 200)`,
      args: [userId],
    },
  ], 'write');

  const replaceAttempt = await call('/v1/sync/replace', 'POST', { operations: [] }, session.accessToken);
  assert.equal(replaceAttempt.status, 410);

  const pull = await call('/v1/sync/pull?cursor=0&limit=100', 'GET', undefined, session.accessToken);
  assert.equal(pull.status, 200);
  const pulled = await pull.json() as { changes: Array<Record<string, unknown>> };
  const recovered = pulled.changes.find(change =>
    change.entityType === 'transactions' &&
    change.entityId === 'tx-preserve' &&
    change.operationId !== 'old-upsert'
  );
  assert.ok(recovered, 'pull should append a recovery upsert after the legacy reset');

  const entity = (await db.execute({
    sql: `SELECT version, payload_json, deleted_at
          FROM sync_entities
          WHERE user_id = ? AND entity_type = 'transactions' AND entity_id = 'tx-preserve'`,
    args: [userId],
  })).rows[0];
  assert.ok(entity);
  assert.equal(Number(entity.version), 4);
  assert.equal(entity.deleted_at, null);
  assert.equal(JSON.parse(String(entity.payload_json)).title, 'Preserve me');

  const resetPush = await call('/v1/sync/push', 'POST', {
    operations: [{
      operationId: 'bad-reset-op',
      entityType: '__reset__',
      entityId: 'finance',
      operation: 'delete',
      baseVersion: 0,
    }],
  }, session.accessToken);
  assert.equal(resetPush.status, 400);

  const stillThere = (await db.execute({
    sql: `SELECT COUNT(*) AS count FROM sync_entities
          WHERE user_id = ? AND entity_type = 'transactions' AND entity_id = 'tx-preserve' AND deleted_at IS NULL`,
    args: [userId],
  })).rows[0];
  assert.equal(Number(stillThere.count), 1);
});
