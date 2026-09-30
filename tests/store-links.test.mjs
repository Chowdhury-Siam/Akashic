import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import vm from 'node:vm';
import { validateStoreUrl, renderSiteConfig, configureStoreLinks } from '../scripts/configure-store-links.mjs';
const play = 'https://play.google.com/store/apps/details?id=com.yutaka.siam';
const microsoft = 'https://apps.microsoft.com/detail/9N123EXAMPLE';

test('independent optional store listing URLs retain coming-soon defaults', () => {
  assert.equal(validateStoreUrl('', 'Google Play'),''); assert.equal(validateStoreUrl('', 'Microsoft'),'');
  const context = {window:{}}; vm.runInNewContext(renderSiteConfig('',microsoft),context);
  assert.equal(context.window.YUTAKA_SITE.playStoreUrl,'');
  assert.equal(context.window.YUTAKA_SITE.microsoftStoreUrl,microsoft);
  assert.ok(Object.isFrozen(context.window.YUTAKA_SITE));
});
test('genuine HTTPS store listing URLs are accepted; unsafe, incorrect and malformed URLs fail', () => {
  assert.equal(validateStoreUrl(play,'Google Play'),play);
  assert.equal(validateStoreUrl(microsoft,'Microsoft'),microsoft);
  for(const bad of ['javascript:alert(1)','http://play.google.com/store/apps/details?id=x','https://evil.example/', 'https://play.google.com/store/apps/details','https://evil.example@play.google.com/path','https://play.google.com.evil.example/store/apps/details?id=x']) {
    assert.throws(()=>validateStoreUrl(bad,'Google Play'),bad);
  }
  assert.throws(()=>validateStoreUrl(play,'Microsoft'));
  assert.throws(()=>validateStoreUrl(microsoft,'Google Play'));
});
test('configuration is generated only after validation; no partial writes on error', async () => {
  const dir=await mkdtemp(join(tmpdir(),'yutaka-stores-'));
  try {
    const path=join(dir,'config.js'); await writeFile(path,'unchanged');
    await assert.rejects(configureStoreLinks({playStoreUrl:play,microsoftStoreUrl:'http://evil.invalid',configPath:path}));
    assert.equal(await readFile(path,'utf8'),'unchanged');
    await configureStoreLinks({playStoreUrl:play,microsoftStoreUrl:microsoft,configPath:path});
    const context={window:{}}; vm.runInNewContext(await readFile(path,'utf8'),context);
    assert.equal(context.window.YUTAKA_SITE.playStoreUrl,play);
    assert.equal(context.window.YUTAKA_SITE.microsoftStoreUrl,microsoft);
  } finally { await rm(dir,{recursive:true,force:true}); }
});
test('untrusted markup in store URL cannot prematurely terminate the generated script', () => {
  const attack='https://play.google.com/store/apps/details?id=</script><script>alert(1)</script>';
  const rendered=renderSiteConfig(attack,'');
  assert.ok(!rendered.includes('</script>'));
  assert.match(rendered,/%3Cscript%3E/);
});

test('store buttons activate independently and never link to a removed signup form', async () => {
  const js = await readFile(new URL('../public/assets/main.js', import.meta.url),'utf8');
  function link(store) {
    const status = {textContent:'Coming soon'};
    return {
      dataset:{store},status,attrs:{'aria-disabled':'true'},href:'#',
      removeAttribute(name){delete this.attrs[name];if(name==='href')delete this.href;},
      setAttribute(name,value){this.attrs[name]=value;},
      querySelector(){return status;}
    };
  }
  const playLink=link('play'),microsoftLink=link('microsoft');
  const context = {window:{YUTAKA_SITE:{playStoreUrl:play,microsoftStoreUrl:''}},document:{
    getElementById(id){return id==='year'?{textContent:''}:null;},
    querySelectorAll(selector){return selector==='[data-store]'?[playLink,microsoftLink]:[];}
  }};
  vm.runInNewContext(js,context);
  assert.equal(playLink.href,play);assert.equal(playLink.status.textContent,'↗');
  assert.ok(!('aria-disabled' in playLink.attrs));
  assert.equal(microsoftLink.href,undefined);
  assert.equal(microsoftLink.attrs['aria-disabled'],'true');
  assert.equal(microsoftLink.status.textContent,'Coming soon');
});
