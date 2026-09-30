import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, access } from 'node:fs/promises';

const read = relative => readFile(new URL(relative, import.meta.url), 'utf8');
const socialImage = '../public/assets/yutaka-app-social-v1.3.0.png';

test('homepage and demo both advertise the real app icon for social previews', async () => {
  const [home, demo] = await Promise.all([
    read('../public/index.html'),
    read('../public/demo/index.html'),
  ]);
  for (const page of [home, demo]) {
    assert.match(page, /<meta property="og:image" content="\/assets\/yutaka-app-social-v1\.3\.0\.png">/);
    assert.match(page, /<meta property="og:image:type" content="image\/png">/);
    assert.match(page, /<meta property="og:image:width" content="1024">/);
    assert.match(page, /<meta property="og:image:height" content="1024">/);
    assert.match(page, /<meta name="twitter:card" content="summary">/);
    assert.match(page, /<meta name="twitter:image" content="\/assets\/yutaka-app-social-v1\.3\.0\.png">/);
    assert.match(page, /<link rel="apple-touch-icon" href="\/assets\/yutaka-app-icon\.png">/);
    assert.doesNotMatch(page, /og-yutaka\.png/);
  }
});

test('social thumbnail matches the actual Yutaka launcher icon, not the old wordmark', async () => {
  const [launcherIcon, previewIcon] = await Promise.all([
    readFile(new URL('../public/assets/yutaka-app-icon.png', import.meta.url)),
    readFile(new URL(socialImage, import.meta.url)),
  ]);
  assert.ok(launcherIcon.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex')));
  assert.deepEqual(previewIcon, launcherIcon);
  await assert.rejects(access(new URL('../public/assets/og-legacy.png', import.meta.url)));
});
