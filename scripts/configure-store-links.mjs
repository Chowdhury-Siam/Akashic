/** Generate public store links from GitHub Actions secrets before deployment. */
import { writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HOME = 'https://github.com/Chowdhury-Siam/Yutaka';

export function validateStoreUrl(value, store) {
  const raw = typeof value === 'string' ? value.trim() : '';
  if (!raw) return '';
  let url;
  try { url = new URL(raw); } catch { throw new Error(`Invalid ${store} store URL.`); }
  if (url.protocol !== 'https:' || url.username || url.password || url.port) {
    throw new Error(`${store} store URL must use HTTPS without embedded credentials.`);
  }
  if (store === 'Google Play') {
    if (url.hostname !== 'play.google.com' || url.pathname !== '/store/apps/details' || !url.searchParams.get('id')) {
      throw new Error('PLAY_STORE_URL must be a Google Play app listing URL.');
    }
  } else if (store === 'Microsoft') {
    if (!['apps.microsoft.com', 'www.microsoft.com', 'microsoft.com'].includes(url.hostname) ||
        !/(?:\/detail\/|\/store\/|\/p\/)/i.test(url.pathname)) {
      throw new Error('MICROSOFT_STORE_URL must be a Microsoft Store listing URL.');
    }
  } else throw new Error(`Unknown store: ${store}`);
  return url.toString();
}

export function renderSiteConfig(playStoreUrl = '', microsoftStoreUrl = '') {
  const config = {
    playStoreUrl: validateStoreUrl(playStoreUrl, 'Google Play'),
    microsoftStoreUrl: validateStoreUrl(microsoftStoreUrl, 'Microsoft'),
    githubUrl: HOME,
  };
  // Prevent unsafe script-token injection even if an URL contains HTML punctuation.
  const safe = JSON.stringify(config, null, 2)
    .replace(/</g, '\\u003c').replace(/>/g, '\\u003e')
    .replace(/\u2028/g, '\\u2028').replace(/\u2029/g, '\\u2029');
  return `// Generated at deployment from PLAY_STORE_URL and MICROSOFT_STORE_URL.\nwindow.YUTAKA_SITE = Object.freeze(${safe});\n`;
}

export async function configureStoreLinks({
  playStoreUrl = process.env.PLAY_STORE_URL,
  microsoftStoreUrl = process.env.MICROSOFT_STORE_URL,
  configPath = 'public/assets/config.js',
} = {}) {
  // Validation completes before any output file is changed.
  const generated = renderSiteConfig(playStoreUrl, microsoftStoreUrl);
  await writeFile(configPath, generated);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { await configureStoreLinks(); }
  catch (error) { console.error(`::error::${error.message}`); process.exitCode = 1; }
}
