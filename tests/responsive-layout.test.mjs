import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
const file = path => readFile(new URL(path, root), 'utf8');

test('marketing page has tablet and narrow-mobile responsive fallbacks', async () => {
  const css = await file('public/assets/styles.css');
  for (const part of [
    '@media(max-width:900px)',
    '.feature-big{grid-template-columns:1fr}',
    '@media(max-width:700px)',
    '.sync-cards{grid-template-columns:1fr}',
    '@media(max-width:430px)',
    '.download-row{display:grid;grid-template-columns:50px minmax(0,1fr)',
    '.footer-grid{grid-template-columns:1fr}'
  ]) assert.ok(css.includes(part), `Missing responsive rule: ${part}`);
});

test('interactive demo switches to compact chrome on portrait tablets', async () => {
  const css = await file('public/assets/app-demo.css');
  for (const part of [
    '@media(max-width:760px)',
    '.app-layout{display:block;height:calc(100dvh - 30px)}',
    '.app-rail{display:none}',
    '.app-dock{position:absolute',
    '@media(max-width:420px)',
    '.range-dialog .period-options{grid-template-columns:1fr}'
  ]) assert.ok(css.includes(part), `Missing demo responsive rule: ${part}`);
});
