import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read=name=>readFile(new URL(name,import.meta.url),'utf8');
test('interactive demo navigation mirrors Yutaka Flutter five-tab order and quick menu',async()=>{
 const html=await read('../public/demo/index.html');
 const primary=html.match(/<nav class="demo-nav rail-primary".*?<\/nav>/s)?.[0];
 const dock=html.match(/<nav class="app-dock".*?<\/nav>/s)?.[0];
 assert.ok(primary&&dock,'main navigation and dock must both be present');
 assert.deepEqual([...primary.matchAll(/data-page="(\w+)"/g)].map(x=>x[1]),['overview','analytics','loans','transactions','categories']);
 assert.deepEqual([...dock.matchAll(/data-mobile="(\w+)"/g)].map(x=>x[1]),['overview','analytics','loans','transactions','categories']);
 const menu=html.match(/<div id="quick-menu".*?<\/div>/s)?.[0];
 assert.deepEqual([...menu.matchAll(/data-page="(\w+)"/g)].map(x=>x[1]),['notes','subscriptions','plans']);
 assert.match(html,/id="demo-dialog"/);assert.match(html,/id="range-dialog"/);
 assert.match(html,/Fictional finances/);
});
test('demo includes the native Home content, date filters, masked amounts and current note toolbar',async()=>{
 const [js,style]=await Promise.all([read('../public/assets/demo.js'),read('../public/assets/app-demo.css')]);
 for(const part of ['Net Balance','Total income','Total expense','Savings Accounts','Category spending','Recent','More entries','safeRichHtml','noteSelection','inlineCode','toggle-amounts','date-range','reset-demo','inPeriod'])assert.ok(js.includes(part),`Missing: ${part}`);
 for(const part of ['#0f1216','#00bd91','app-home-grid','app-dock','app-rail','hero-sparkline','app-quick-menu','note-rich-editor'])assert.ok(style.includes(part),`Missing: ${part}`);
 for(const option of ['bold','italic','strikeThrough','hiliteColor','createLink','insertUnorderedList','inlineCode','undo','redo'])assert.ok(js.includes(`data-note-format="${option}"`),`Missing: ${option}`);
 assert.doesNotMatch(js,/data-note-format="underline"|data-note-format="quote"/i);
});
test('marketing homepage previews the actual interactive app demo capture',async()=>{
 const [html,shot,pkg,lock]=await Promise.all([read('../public/index.html'),readFile(new URL('../public/assets/app-demo-home.png',import.meta.url)),read('../package.json'),read('../package-lock.json')]);
 assert.match(html,/<img src="\/assets\/app-demo-home\.png"/);
 assert.match(html,/class=\"preview-app real-app-preview\"/);
 assert.match(html,/class=\"download-icon brand-play\"/);
 assert.match(html,/class=\"download-icon brand-microsoft\"/);
 assert.match(html,/class=\"download-icon brand-github\"/);
 assert.ok(shot.length>20000,'preview screenshot exists');
 assert.equal(JSON.parse(pkg).version,'1.3.0');
 assert.equal(JSON.parse(lock).packages[''].version,'1.3.0');
});
