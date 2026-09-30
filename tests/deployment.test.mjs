import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const read = path => readFile(new URL(path, import.meta.url), 'utf8');

test('GitHub Actions validates PRs; only original repository deploys from main or manual dispatch', async () => {
  const workflow = await read('../.github/workflows/deploy-website.yml');
  for (const fragment of ['pull_request:', 'workflow_dispatch:', 'branches: [main]', 'github.event.repository.fork == false', "github.event_name == 'push' && github.ref == 'refs/heads/main'", 'needs: validate', 'npm test', 'npm run check:bundle']) assert.ok(workflow.includes(fragment), fragment);
  assert.equal((workflow.match(/command: deploy/g) || []).length, 1);
});

test('Cloudflare deployment uses its two credentials, required Worker-name secret and optional public store URL secrets', async () => {
  const workflow = await read('../.github/workflows/deploy-website.yml');
  for (const name of ['CLOUDFLARE_API_TOKEN', 'CLOUDFLARE_ACCOUNT_ID', 'CLOUDFLARE_WORKER_NAME', 'PLAY_STORE_URL', 'MICROSOFT_STORE_URL']) assert.match(workflow, new RegExp(`secrets\.${name}`));
  assert.ok(workflow.includes('CLOUDFLARE_WORKER_NAME: ${{ secrets.CLOUDFLARE_WORKER_NAME }}'));
  assert.ok(workflow.indexOf('node scripts/configure-store-links.mjs') < workflow.indexOf('command: deploy'));
  for (const old of ['TURSO_DATABASE_URL', 'TURSO_AUTH_TOKEN', 'RATE_LIMIT_KEY', 'db:migrate', 'has_turso', 'WEBSITE_']) assert.ok(!workflow.includes(old), old);
});

test('Wrangler deploys assets only, with no backend Worker or API routing', async () => {
  const config = JSON.parse(await read('../wrangler.jsonc'));
  assert.equal(config.name, 'yutaka-website');
  assert.equal(config.assets.directory, './public');
  assert.ok(!('main' in config));
  assert.ok(!('run_worker_first' in config.assets));
});
