import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {seed,transaction,editTransaction,balance,repayLoan} from '../public/assets/demo-model.js';
const read = name => readFile(new URL(name,import.meta.url),'utf8');

test('Analysis reproduces Flutter mini-metrics, cash-flow trend and averages',async()=>{
 const [js,css]=await Promise.all([read('../public/assets/demo.js'),read('../public/assets/app-demo.css')]);
 for(const token of ['Cash flow trend','Net','Balance','Averages','Income / day','Expense / day','trend-view','periodDayCount','native-cash-flow'])assert.ok(js.includes(token),token);
 for(const token of ['native-chart-card','native-trend-selector','flutter-mini-metric'])assert.ok(css.includes(token)||js.includes(token),token);
});
test('Loans reproduces Portfolio, Collect/Pay/Settled/All and repayments',async()=>{
 const js=await read('../public/assets/demo.js');
 for(const token of ['Portfolio','To collect','To pay','Net position','Collect','Pay','Settled','People','Payment history','loan-toggle-search','loan-filter','repay-loan'])assert.ok(js.includes(token),token);
 const s=seed(),a=s.accounts.find(a=>a.id==='cash');
 const orig=a.balance;repayLoan(s,'l1','cash',25);
 assert.equal(a.balance,orig+25);assert.equal(s.loans[0].outstanding,185);
 assert.equal(s.loans[0].payments.length,1);assert.equal(s.loans[0].payments[0].amount,25);
});
test('Transaction supports sort, filter, edit, duplicate and deleting records',async()=>{
 const js=await read('../public/assets/demo.js');
 for(const token of ['Sort','Filters','dateNewest','amountHigh','native-active-chip','duplicate-tx','edit-tx','delete-tx','tx-sort','tx-type','tx-account'])assert.ok(js.includes(token),token);
 const s=seed(),baseline=balance(s);
 const tx=transaction(s,{type:'expense',title:'Test',amount:9,category:'Shopping',accountId:'cash'});
 assert.equal(balance(s),baseline-9);
 editTransaction(s,tx.id,{type:'income',title:'Corrected',amount:18,category:'Salary',accountId:'bank'});
 assert.equal(balance(s),baseline+18);
 const snapshot=JSON.stringify(s);
 assert.throws(()=>editTransaction(s,tx.id,{type:'transfer',amount:12,accountId:'cash',toAccountId:'cash'}));
 assert.equal(JSON.stringify(s),snapshot,'Invalid edits must not partially alter balances or transactions');
});
test('Categories reproduces Expense/Income donut breakdown and Manage categories',async()=>{
 const js=await read('../public/assets/demo.js');
 for(const token of ['Expense breakdown','Income breakdown','native-donut','native-orbit-badge','Manage categories','add-category','edit-category','delete-category','category-mode','category-open'])assert.ok(js.includes(token),token);
 assert.ok(js.includes('categoryList(type)'),'Both category types must be available');
 const s=seed();assert.deepEqual(s.customCategories,[]);
});
test('No website Turso integration remains and release links use GitHub secrets', async()=>{
 const [workflow,readme,pkg,lock]=await Promise.all(['../.github/workflows/deploy-website.yml','../README.md','../package.json','../package-lock.json'].map(read));
 for(const secret of ['PLAY_STORE_URL','MICROSOFT_STORE_URL']){assert.ok(workflow.includes(`secrets.${secret}`));assert.ok(readme.includes(secret));}
 for(const old of ['TURSO_DATABASE_URL','TURSO_AUTH_TOKEN','RATE_LIMIT_KEY'])assert.ok(!workflow.includes(old));
 assert.equal(JSON.parse(pkg).version,'1.3.0');assert.equal(JSON.parse(lock).packages[''].version,'1.3.0');
 assert.ok(!JSON.parse(pkg).dependencies?.['@libsql/client']);
});
