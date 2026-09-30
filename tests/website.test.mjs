import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, access } from 'node:fs/promises';
import { seed, transaction, removeTransaction, balance, spent, earned, buyPlan, recordSubscription, repayLoan, escapeHtml } from '../public/assets/demo-model.js';
const read = p => readFile(new URL(p, import.meta.url), 'utf8');

test('demo expenses, income, transfers and deletion preserve account totals', () => {
  const s = seed(), initial = balance(s), expense = spent(s), income = earned(s);
  transaction(s, {title:'Snack',type:'expense',amount:12,category:'Food & drinks',accountId:'cash'});
  assert.equal(balance(s), initial - 12); assert.equal(spent(s), expense + 12);
  transaction(s, {title:'Gift',type:'income',amount:40,category:'Gift',accountId:'bank'});
  assert.equal(balance(s), initial + 28); assert.equal(earned(s), income + 40);
  const before = balance(s), from = s.accounts[0].balance, to = s.accounts[1].balance;
  const t = transaction(s, {title:'Transfer',type:'transfer',amount:50,accountId:'cash',toAccountId:'bank'});
  assert.equal(balance(s), before); assert.equal(s.accounts[0].balance, from - 50); assert.equal(s.accounts[1].balance, to + 50);
  assert.equal(removeTransaction(s,t.id), true); assert.equal(balance(s),before);
  assert.equal(s.accounts[0].balance,from); assert.equal(s.accounts[1].balance,to);
});
test('demo plan buying and subscription payments create expenses', () => {
  const s=seed(), p=s.plans[0], before=spent(s); buyPlan(s,p.id,'cash');
  assert.equal(s.plans.some(x=>x.id===p.id),false); assert.equal(spent(s),before+p.amount);
  const sub=s.subscriptions[0]; recordSubscription(s,sub.id,'bank'); assert.equal(s.subscriptions.length,2); assert.equal(spent(s),before+p.amount+sub.amount);
});
test('loan repayments update balances and reject overpayment', () => {
  const s=seed(),loan=s.loans[0],cash=s.accounts[0].balance;
  repayLoan(s,loan.id,'cash',10); assert.equal(loan.outstanding,200); assert.equal(s.accounts[0].balance,cash+10);
  assert.throws(()=>repayLoan(s,loan.id,'cash',201));
});
test('HTML escaping blocks markup injection from demo notes', () => assert.equal(escapeHtml('<script>"x"&</script>'),'&lt;script&gt;&quot;x&quot;&amp;&lt;/script&gt;'));
test('landing, demo, and privacy are static and no longer advertise release signup', async () => {
  const [home,demo,privacy,wrangler,config,main] = await Promise.all(['../public/index.html','../public/demo/index.html','../public/privacy/index.html','../wrangler.jsonc','../public/assets/config.js','../public/assets/main.js'].map(read));
  for (const id of ['features','how-it-works','sync','downloads']) assert.match(home,new RegExp(`id="${id}"`));
  for (const page of ['transactions','budgets','plans','subscriptions','loans','analytics','notes']) assert.ok(demo.includes(`data-page="${page}"`));
  assert.match(privacy,/local storage/); assert.match(privacy,/no website database/);
  assert.match(config,/playStoreUrl: ''/); assert.match(config,/microsoftStoreUrl: ''/);
  assert.match(main,/removeAttribute\('href'\)/);
  for (const text of [home,main,wrangler]) assert.doesNotMatch(text,/waitlist|TURSO_DATABASE_URL|api\/health|Turso/i);
  const styles = await read('../public/assets/styles.css');
  assert.match(styles,/scroll-margin-top:104px/);
  await assert.rejects(access(new URL('../schema.sql', import.meta.url)));
  await assert.rejects(access(new URL('../worker/index.js', import.meta.url)));
});
