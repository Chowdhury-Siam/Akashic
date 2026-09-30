export const CATEGORIES = ['Food & drinks', 'Shopping', 'Transport', 'Home', 'Health', 'Entertainment', 'Education', 'Other'];
const asDate = (offset = 0) => { const d = new Date(); d.setDate(d.getDate() + offset); return [d.getFullYear(), String(d.getMonth() + 1).padStart(2, '0'), String(d.getDate()).padStart(2, '0')].join('-'); };
export const today = () => asDate(0);
export const id = () => globalThis.crypto?.randomUUID?.() || `d${Date.now()}-${Math.random().toString(16).slice(2)}`;
export function seed() {
  return {
    version: 1, currency: 'USD', customCategories: [], loanShowSettled: true,
    accounts: [ {id:'cash',name:'Everyday cash',type:'Cash',balance:840}, {id:'bank',name:'Main account',type:'Bank',balance:28450}, {id:'savings',name:'Savings',type:'Savings',balance:15600} ],
    transactions: [
      {id:'t1',title:'Groceries',type:'expense',amount:84.50,category:'Food & drinks',accountId:'cash',date:asDate(0)},
      {id:'t2',title:'Monthly salary',type:'income',amount:3600,category:'Salary',accountId:'bank',date:asDate(-1)},
      {id:'t3',title:'Weekend brunch',type:'expense',amount:38.20,category:'Food & drinks',accountId:'cash',date:asDate(-1)},
      {id:'t4',title:'Shopping',type:'expense',amount:149,category:'Shopping',accountId:'bank',date:asDate(-2)},
      {id:'t5',title:'Bus pass',type:'expense',amount:44,category:'Transport',accountId:'cash',date:asDate(-4)},
      {id:'t6',title:'Freelance project',type:'income',amount:720,category:'Freelance',accountId:'bank',date:asDate(-5)},
      {id:'t7',title:'Internet bill',type:'expense',amount:56,category:'Home',accountId:'bank',date:asDate(-6)},
      {id:'t8',title:'Movie tickets',type:'expense',amount:26,category:'Entertainment',accountId:'cash',date:asDate(-10)},
      {id:'t9',title:'Gym membership',type:'expense',amount:49,category:'Health',accountId:'bank',date:asDate(-12)}
    ],
    budgets:[{id:'b1',category:'Food & drinks',limit:400},{id:'b2',category:'Shopping',limit:300},{id:'b3',category:'Transport',limit:180},{id:'b4',category:'Entertainment',limit:120}],
    plans:[{id:'p1',title:'New headphones',amount:180,category:'Shopping'},{id:'p2',title:'Weekend getaway',amount:440,category:'Entertainment'}],
    subscriptions:[{id:'s1',title:'Music streaming',amount:10.99,category:'Entertainment',period:'Monthly',accountId:'bank'},{id:'s2',title:'Cloud storage',amount:3.49,category:'Other',period:'Monthly',accountId:'bank'}],
    loans:[{id:'l1',title:'Alex',kind:'lent',outstanding:210,original:350,accountId:'cash',due:asDate(20)}],
    notes:[{id:'n1',title:'September goals',body:'Keep everyday spending in check.\nSet aside a little more for the next trip.',created:asDate(-3)}]
  };
}
export function money(value, currency = 'USD') {return new Intl.NumberFormat(currency === 'BDT' ? 'en-BD' : 'en-US',{style:'currency',currency,maximumFractionDigits:2}).format(Number(value) || 0);}
export function sum(values) {return values.reduce((total, value) => total + Number(value || 0), 0);}
export function balance(state) {return sum(state.accounts.map(a => a.balance));}
export function thisMonth(date) { const d = new Date();return typeof date === 'string' && date.slice(0, 7) === `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}`; }
export function spent(state, category) {return sum(state.transactions.filter(t=>t.type==='expense'&&thisMonth(t.date)&&(!category||t.category===category)).map(t=>t.amount));}
export function earned(state) {return sum(state.transactions.filter(t=>t.type==='income'&&thisMonth(t.date)).map(t=>t.amount));}
export function transaction(state, data) {
  if (!['expense','income','transfer'].includes(data.type)) throw new Error('Choose a transaction type.');
  if (!(Number(data.amount)>0) || !Number.isFinite(Number(data.amount)) || Number(data.amount)>1e9) throw new Error('Enter a valid positive amount.');
  const from = state.accounts.find(a=>a.id===data.accountId);
  if(!from) throw new Error('Choose an account.');
  if(data.type==='transfer') {
    const target=state.accounts.find(a=>a.id===data.toAccountId);
    if(!target||target.id===from.id) throw new Error('Choose a different destination account.');
    target.balance+=Number(data.amount);
  }
  const amount=Number(data.amount);
  from.balance+=data.type==='income'?amount:-amount;
  const row={id:id(),title:String(data.title||'').trim().slice(0,90) || (data.type==='transfer'?'Account transfer':'Untitled'),type:data.type,amount,category:data.type==='transfer'?'Transfer':data.category||'Other',accountId:from.id,toAccountId:data.type==='transfer'?data.toAccountId:undefined,date:data.date||today()};
  state.transactions.unshift(row);return row;
}
export function editTransaction(state, entryId, data){
  const old=state.transactions.find(t=>t.id===entryId);if(!old)throw new Error('Transaction not found.');
  const accounts=state.accounts.map(a=>({...a})),transactions=state.transactions.map(t=>({...t}));
  removeTransaction(state,entryId);
  try{const updated=transaction(state,data);updated.id=entryId;return updated;}
  catch(err){state.accounts=accounts;state.transactions=transactions;throw err;}
}
export function removeTransaction(state, entryId){const idx=state.transactions.findIndex(t=>t.id===entryId);if(idx===-1)return false;const t=state.transactions[idx];const from=state.accounts.find(a=>a.id===t.accountId);if(from)from.balance+=t.type==='income'?-t.amount:t.amount;if(t.type==='transfer'){const to=state.accounts.find(a=>a.id===t.toAccountId);if(to)to.balance-=t.amount;}state.transactions.splice(idx,1);return true;}
export function buyPlan(state,planId,accountId){const idx=state.plans.findIndex(p=>p.id===planId);if(idx<0)throw new Error('Plan not found.');const p=state.plans[idx];transaction(state,{type:'expense',title:p.title,amount:p.amount,category:p.category,accountId,date:today()});state.plans.splice(idx,1);}
export function recordSubscription(state,subId,accountId){const sub=state.subscriptions.find(s=>s.id===subId);if(!sub)throw new Error('Subscription not found.');transaction(state,{type:'expense',title:sub.title,amount:sub.amount,category:sub.category,accountId:accountId||sub.accountId,date:today()});}
export function repayLoan(state,loanId,accountId,amount){const loan=state.loans.find(l=>l.id===loanId);const account=state.accounts.find(a=>a.id===accountId);const n=Number(amount);if(!loan||!account)throw new Error('Choose a loan and account.');if(!Number.isFinite(n)||n<=0||n>loan.outstanding)throw new Error('Enter a repayment no greater than the outstanding balance.');loan.outstanding=Math.round((loan.outstanding-n)*100)/100;account.balance+=loan.kind==='lent'?n:-n;(loan.payments ||= []).push({id:id(),date:today(),amount:n,accountId});}
export function escapeHtml(v) {return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
