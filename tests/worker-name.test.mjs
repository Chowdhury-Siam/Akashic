import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { selectWorkerName, configureWorkerName } from '../scripts/configure-worker-name.mjs';

test('only CLOUDFLARE_WORKER_NAME determines the deployment name', () => {
  assert.equal(selectWorkerName('siam-yutaka'), 'siam-yutaka');
  assert.equal(selectWorkerName('  siam-yutaka  '), 'siam-yutaka');
});

test('CLOUDFLARE_WORKER_NAME is required with no config-name fallback', () => {
  for (const value of [undefined, null, '', '  ']) {
    assert.throws(() => selectWorkerName(value), /CLOUDFLARE_WORKER_NAME is required/);
  }
});

test('unsafe, invalid and overlong Worker names are rejected', () => {
  for (const name of ['-bad', 'bad-', 'UPPER', 'hello world', 'hello;exit', 'bad/name', 'a'.repeat(64)]) {
    assert.throws(() => selectWorkerName(name), /Invalid CLOUDFLARE_WORKER_NAME/, name);
  }
  assert.equal(selectWorkerName('a'.repeat(63)), 'a'.repeat(63));
});

test('repository secret replaces only Wrangler name, preserving assets and config', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'yutaka-worker-name-'));
  try {
    const configPath = join(directory, 'wrangler.jsonc');
    const outputPath = join(directory, 'output');
    await writeFile(configPath, JSON.stringify({ name: 'old-site', main: './worker/index.js', assets: { directory: './public', run_worker_first: ['/api/*'] } }));
    const name = await configureWorkerName({ workerName: 'siam-yutaka', configPath, outputPath });
    const config = JSON.parse(await readFile(configPath, 'utf8'));
    assert.equal(name, 'siam-yutaka');
    assert.equal(config.name, 'siam-yutaka');
    assert.equal(config.main, './worker/index.js');
    assert.deepEqual(config.assets.run_worker_first, ['/api/*']);
    assert.equal(await readFile(outputPath, 'utf8'), 'name=siam-yutaka\n');
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test('invalid/missing secret fails before modifying Wrangler config', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'yutaka-worker-name-'));
  try {
    const configPath = join(directory, 'wrangler.jsonc');
    const original = '{"name":"old-site","main":"./worker/index.js"}';
    await writeFile(configPath, original);
    for (const value of ['', 'bad;rm -rf /']) {
      await assert.rejects(
        configureWorkerName({ workerName: value, configPath }),
        /CLOUDFLARE_WORKER_NAME/
      );
      assert.equal(await readFile(configPath, 'utf8'), original);
    }
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test('CLI rejects an unsafe repository secret before deployment', () => {
  const result = spawnSync(process.execPath, [fileURLToPath(new URL('../scripts/configure-worker-name.mjs', import.meta.url))], {
    cwd: fileURLToPath(new URL('../', import.meta.url)),
    env: { ...process.env, CLOUDFLARE_WORKER_NAME: 'bad;rm -rf /' },
    encoding: 'utf8',
  });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Invalid CLOUDFLARE_WORKER_NAME/);
});

test('GitHub Actions uses only the saved secret for the single deployment path', async () => {
  const workflow = await readFile(new URL('../.github/workflows/deploy-website.yml', import.meta.url), 'utf8');
  assert.match(workflow, /workflow_dispatch:\s*\n/);
  assert.doesNotMatch(workflow, /inputs\.worker_name|MANUAL_WORKER_NAME|REPOSITORY_WORKER_NAME|worker_name:\s/);
  assert.match(workflow, /CLOUDFLARE_WORKER_NAME: \$\{\{ secrets\.CLOUDFLARE_WORKER_NAME \}\}/);
  assert.doesNotMatch(workflow, /vars\.CLOUDFLARE_WORKER_NAME/);
  assert.match(workflow, /WORKER_NAME: \$\{\{ steps\.worker\.outputs\.name \}\}/);
  const configAt = workflow.indexOf('node scripts/configure-worker-name.mjs');
  assert.ok(configAt > workflow.indexOf('jobs:'));
  assert.ok(configAt < workflow.indexOf('Configure app-store links from GitHub secrets'));
  assert.ok(configAt < workflow.indexOf('command: deploy'));
  assert.equal((workflow.match(/command: deploy/g) || []).length, 1);
});
