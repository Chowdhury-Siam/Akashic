import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, stat } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
const file = path => readFile(new URL(path, root), 'utf8');

function luminance(hex) {
  const channels = hex.replace('#','').match(/../g).map(channel => {
    const value = parseInt(channel,16) / 255;
    return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  });
  return channels[0]*0.2126 + channels[1]*0.7152 + channels[2]*0.0722;
}
const contrast = (a,b) => {
  const [light,dark] = [luminance(a),luminance(b)].sort((x,y) => y-x);
  return (light + 0.05)/(dark + 0.05);
};

test('closing call to action has readable primary and secondary button colors', async () => {
  const css = await file('public/assets/styles.css');
  assert.match(css, /\.button-dark\{color:#fff;background:#0d2921/);
  assert.ok(contrast('#ffffff','#0d2921') >= 4.5, 'Primary CTA text must meet WCAG AA');
  assert.ok(contrast('#072d22','#77dfb5') >= 4.5, 'Secondary CTA text must be readable');
  assert.match(css, /\.closing-cta a:focus-visible/);
});

test('closing CTA replaces empty giant circle with meaningful, clickable product preview', async () => {
  const home = await file('public/index.html');
  const section = home.slice(home.indexOf('<section class="closing-cta"'), home.indexOf('</section>', home.indexOf('<section class="closing-cta"')));
  assert.match(section,/aria-labelledby="closing-title"/);
  assert.match(section,/class="closing-preview" href="\/demo\/"/);
  assert.match(section,/app-demo-analysis\.png/);
  assert.doesNotMatch(section,/closing-glow/);
  assert.ok((await stat(new URL('public/assets/app-demo-analysis.png',root))).size > 10_000);
});

test('closing CTA lays out correctly on mobile and respects reduced motion', async () => {
  const css = await file('public/assets/styles.css');
  assert.match(css, /@media\(max-width:620px\)\{\.closing-inner\{grid-template-columns:minmax\(0,1fr\)/);
  assert.match(css, /@media\(prefers-reduced-motion:reduce\)\{\.closing-preview\{transition:none/);
});
