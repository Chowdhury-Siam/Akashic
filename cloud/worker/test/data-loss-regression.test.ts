import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { createClient } from '@libsql/client';
import { handleRequest } from '../src/index.ts';
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
  const connect = () => new Proxy(db, {
    get(target, property, receiver) {
      if (property === 'close') return () => {};
      const value = Reflect.get(target, property, receiver);
      return typeof value === 'function' ? value.bind(target) : value;
    },
  });
  const call = (route: string, method = 'GET', body?: unknown, accessToken = '') => handleRequest(
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
    connect,
  );

  const registration = await call('/v1/auth/register', 'POST', {
    username: 'owner',
    password: 'password123',
    deviceId: 'device-a',
  });
  assert.equal(registration.status, 200);
  const session = await registration.json() as { accessToken: string };
  const userId = String((await db.execute('SELECT id FROM users LIMIT 1')).rows[0].id);

  const sentinels = [
    ['accounts', 'account-preserve', { id: 'account-preserve', name: 'Upgrade Cash', amount: 4321.25 }],
    ['categories', 'category-preserve', { id: 'category-preserve', name: 'Upgrade Expense', type: 'expense' }],
    ['transactions', 'tx-preserve', { id: 'tx-preserve', type: 'expense', amount: 42, title: 'Preserve me' }],
    ['budgets', 'budget-preserve', { id: 'budget-preserve', amount: 777, selected_month: '2026-10' }],
    ['planned_purchases', 'plan-preserve', { id: 'plan-preserve', name: 'Upgrade Laptop', amount: 1500 }],
    ['notes', 'note-preserve', { id: 'note-preserve', title: 'Upgrade sentinel note', body: 'keep me' }],
    ['subscriptions', 'subscription-preserve', { id: 'subscription-preserve', name: 'Upgrade Subscription', amount: 19.99 }],
    ['loan_contacts', 'contact-preserve', { id: 'contact-preserve', name: 'Upgrade Contact' }],
    ['loans', 'loan-preserve', { id: 'loan-preserve', principal: 1200, direction: 'lent' }],
    ['loan_payments', 'payment-preserve', { id: 'payment-preserve', loan_id: 'loan-preserve', amount: 200 }],
  ] as const;
  await db.batch([
    ...sentinels.map(([entityType, entityId, payload], index) => ({
      sql: `INSERT INTO sync_changes(user_id, entity_type, entity_id, operation, version, payload_json, device_id, operation_id, changed_at)
            VALUES (?, ?, ?, 'upsert', 3, ?, 'old-device', ?, ?)`,
      args: [userId, entityType, entityId, JSON.stringify({ ...payload, created_on: 100, updated_on: 100 }), `old-upsert-${index}`, 100 + index],
    })),
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
  for (const [entityType, entityId, payload] of sentinels) {
    const recovered = pulled.changes.find(change =>
      change.entityType === entityType &&
      change.entityId === entityId &&
      !String(change.operationId ?? '').startsWith('old-upsert-')
    );
    assert.ok(recovered, `pull should recover ${entityType}/${entityId} after the legacy reset`);

    const entity = (await db.execute({
      sql: `SELECT version, payload_json, deleted_at
            FROM sync_entities
            WHERE user_id = ? AND entity_type = ? AND entity_id = ?`,
      args: [userId, entityType, entityId],
    })).rows[0];
    assert.ok(entity, `recovered entity should exist for ${entityType}/${entityId}`);
    assert.equal(Number(entity.version), 4);
    assert.equal(entity.deleted_at, null);
    const restoredPayload = JSON.parse(String(entity.payload_json)) as Record<string, unknown>;
    for (const [key, expected] of Object.entries(payload)) {
      assert.equal(restoredPayload[key], expected, `${entityType}/${entityId}.${key} should survive recovery`);
    }
  }

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
          WHERE user_id = ? AND deleted_at IS NULL`,
    args: [userId],
  })).rows[0];
  assert.equal(Number(stillThere.count), sentinels.length, 'all recovered finance entities must remain in cloud state');
});
