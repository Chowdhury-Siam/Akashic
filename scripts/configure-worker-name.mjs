/** Apply the required GitHub Actions CLOUDFLARE_WORKER_NAME to Wrangler. */
import { appendFile, readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export function selectWorkerName(repositoryName) {
  const chosen = typeof repositoryName === 'string' ? repositoryName.trim() : '';
  if (!chosen) {
    throw new Error('CLOUDFLARE_WORKER_NAME is required. Set it in GitHub Actions repository secrets.');
  }
  // Use a workers.dev-compatible name even when deploying to a custom domain.
  if (chosen.length > 63 || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(chosen)) {
    throw new Error('Invalid CLOUDFLARE_WORKER_NAME: use 1–63 lowercase letters, digits or hyphens; no leading or trailing hyphen.');
  }
  return chosen;
}

export async function configureWorkerName({
  workerName = process.env.CLOUDFLARE_WORKER_NAME,
  configPath = 'wrangler.jsonc',
  outputPath = process.env.GITHUB_OUTPUT || '',
} = {}) {
  // Validate before touching the config: a missing/invalid secret must fail.
  const name = selectWorkerName(workerName);
  const config = JSON.parse(await readFile(configPath, 'utf8'));
  config.name = name;
  await writeFile(configPath, `${JSON.stringify(config, null, 2)}\n`);
  if (outputPath) await appendFile(outputPath, `name=${name}\n`);
  return name;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const name = await configureWorkerName();
    console.log(`Cloudflare Worker name: ${name}`);
  } catch (error) {
    console.error(`::error::${error.message}`);
    process.exitCode = 1;
  }
}
