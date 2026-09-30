import {CATEGORIES,today,id,seed,money,sum,balance,thisMonth,spent,earned,transaction,editTransaction,removeTransaction,buyPlan,recordSubscription,repayLoan,escapeHtml as e} from './demo-model.js';
const KEY='yutaka-public-demo-v1';
let state;
try { const saved=JSON.parse(localStorage.getItem(KEY)||'null');state=saved?.version===1&&Array.isArray(saved.accounts)&&Array.isArray(saved.transactions)?saved:seed(); }catch{state=seed();}
let page=(location.hash.replace('#','')||'overview');
let txCategoryFilter='';
state.demoPeriod ||= 'month';
state.amountsHidden ??= false;
state.customCategories ||= [];
state.loanShowSettled ??= true;
const PAGES={overview:'Home',analytics:'Analysis',loans:'Loans',transactions:'Transaction',categories:'Categories',accounts:'Accounts',budgets:'Budgets',plans:'Plan',subscriptions:'Subscription',notes:'Note',settings:'Settings'};
if(!PAGES[page])page='overview';
const $=s=>document.querySelector(s);
const fmt=n=>money(n,state.currency);
const accountName=id=>state.accounts.find(a=>a.id===id)?.name||'Account';
const save=()=>{try{localStorage.setItem(KEY,JSON.stringify(state));}catch{toast('Browser storage is unavailable; changes will not persist.');}};
const shortDate=d=>{if(!d)return '—';const v=new Date(`${d}T12:00:00`);return Number.isNaN(v.getTime())?d:v.toLocaleDateString('en-US',{month:'short',day:'numeric'});};
const iconFor=t=>t.type==='income'?'↙':t.type==='transfer'?'⇄':'↗';
const amountText=t=>(t.type==='income'?'+':t.type==='expense'?'−':'')+fmt(t.amount);
const sortTx=tx=>[...tx].sort((a,b)=>b.date.localeCompare(a.date));
const acctOptions=(selected='',skip='')=>state.accounts.filter(a=>a.id!==skip).map(a=>`<option value="${e(a.id)}" ${a.id===selected?'selected':''}>${e(a.name)}</option>`).join('');
const catOptions=(selected='Food & drinks',type='expense')=>categoryList(type).map(c=>`<option value="${e(c)}" ${c===selected?'selected':''}>${e(c)}</option>`).join('');
const field=(label,name,html)=>`<label class="field">${e(label)}${html}</label>`;
const input=(name,placeholder,opts='')=>`<input name="${name}" placeholder="${e(placeholder)}" ${opts} required>`;
const select=(name,items)=>`<select name="${name}" required>${items}</select>`;
const stateRow=(t,del=false)=>`<div class="list-row"><div class="row-icon ${e(t.type)}">${iconFor(t)}</div><div class="row-details"><strong>${e(t.title)}</strong><small>${e(t.category)} · ${e(accountName(t.accountId))} · ${e(shortDate(t.date))}</small></div><div class="row-money ${t.type==='income'?'positive':''}">${amountText(t)}${del?`<div style="margin-top:6px"><button class="small-action danger" data-action="delete-tx" data-id="${e(t.id)}">Delete</button></div>`:''}</div></div>`;
let toastTimer;
function toast(message){const t=$('#demo-toast');t.textContent=message;t.classList.add('visible');clearTimeout(toastTimer);toastTimer=setTimeout(()=>t.classList.remove('visible'),3200);}
function chartBars(){const points=Array.from({length:7},(_,i)=>{const d=new Date();d.setDate(d.getDate()-(6-i));const key=`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;const rows=state.transactions.filter(t=>t.date===key);return {label:d.toLocaleDateString('en-US',{weekday:'short'}),inc:sum(rows.filter(t=>t.type==='income').map(t=>t.amount)),exp:sum(rows.filter(t=>t.type==='expense').map(t=>t.amount))};});const top=Math.max(1,...points.flatMap(p=>[p.inc,p.exp]));return `<div class="chart-bars" role="img" aria-label="Income and expenses over the last seven days">${points.map(p=>`<div class="chart-bar-group" title="${e(p.label)}: income ${fmt(p.inc)}, expenses ${fmt(p.exp)}"><div class="chart-bar" style="height:${Math.max(p.inc?5:1,Math.round(p.inc/top*100))}%"></div><div class="chart-bar exp" style="height:${Math.max(p.exp?5:1,Math.round(p.exp/top*100))}%"></div></div>`).join('')}</div><div class="chart-labels">${points.map(p=>`<span>${e(p.label)}</span>`).join('')}</div>`;}
function budgetRows(max=99){return state.budgets.slice(0,max).map(b=>{const used=spent(state,b.category),pct=used/b.limit*100;return `<div class="budget-item"><div class="budget-head"><span><strong>${e(b.category)}</strong><br><small>${Math.round(pct)}% used</small></span><span>${fmt(used)} <small>/ ${fmt(b.limit)}</small></span></div><div class="budget-track"><div class="budget-fill ${pct>100?'over':''}" style="width:${Math.min(100,pct)}%"></div></div>${max>10?`<div class="budget-summary">${fmt(Math.max(0,b.limit-used))} remaining <button class="small-action" style="float:right" data-action="edit-budget" data-id="${e(b.id)}">Edit</button> <button class="small-action danger" style="float:right;margin-right:6px" data-action="delete-budget" data-id="${e(b.id)}">Remove</button></div>`:''}</div>`;}).join('')||'<div class="empty">Create a budget to see your spending progress.</div>';}
const glyph=name=>`<svg aria-hidden="true"><use href="#i-${name}"/></svg>`;
const catVisuals={
 'Food & drinks':['♨','#ffbf7b'],'Shopping':['▦','#ddacff'],'Transport':['➤','#7dcaf1'],
 'Home':['⌂','#76e1b0'],'Health':['✚','#fa9a9e'],'Entertainment':['♫','#e0c18d'],
 'Education':['▤','#9dbbff'],'Other':['◈','#adb5bb']
};
const hiddenFmt=n=>state.amountsHidden?'••••••':fmt(n);
function periodLabel(){return ({today:'Today',week:'This week',month:'This month',year:'This year',all:'All Time',custom:'Custom range'})[state.demoPeriod]||'This month';}
function inPeriod(date){
 if(!date||state.demoPeriod==='all')return true;
 const now=new Date(), d=new Date(`${date}T12:00:00`);
 if(state.demoPeriod==='custom')return (!state.demoStart||date>=state.demoStart)&&(!state.demoEnd||date<=state.demoEnd);
 if(state.demoPeriod==='today')return date===today();
 if(state.demoPeriod==='week') {const start=new Date(now.getFullYear(),now.getMonth(),now.getDate()-(now.getDay()+6)%7),end=new Date(start);end.setDate(start.getDate()+7);return d>=start&&d<end;}
 if(state.demoPeriod==='month')return d.getFullYear()===now.getFullYear()&&d.getMonth()===now.getMonth();
 if(state.demoPeriod==='year')return d.getFullYear()===now.getFullYear();
 return true;
}
function filteredTransactions(){return state.transactions.filter(t=>inPeriod(t.date));}
function expenseByCategory(cat){return sum(filteredTransactions().filter(t=>t.type==='expense'&&(!cat||t.category===cat)).map(t=>t.amount));}
function summary(){const tx=filteredTransactions();return {income:sum(tx.filter(t=>t.type==='income').map(t=>t.amount)),expense:sum(tx.filter(t=>t.type==='expense').map(t=>t.amount))};}
function section(title,trailing='',destination=''){return `<div class="app-section-head"><h2>${e(title)}</h2>${trailing?`<button type="button" data-page="${destination}">${e(trailing)}</button>`:''}</div>`;}
function nativeBudget(b){const used=spent(state,b.category),percent=b.limit>0?Math.round(used/b.limit*100):0;
 return `<button class="app-budget-tile" data-page="budgets"><div class="budget-head"><span><strong>${e(b.category)}</strong><br><small>${percent}% used</small></span><span><strong>${hiddenFmt(used)}</strong><small> / ${hiddenFmt(b.limit)}</small></span></div><div class="budget-track"><span class="budget-fill ${percent>100?'over':''}" style="width:${Math.min(100,percent)}%;display:block;height:100%;border-radius:inherit"></span></div><div class="budget-summary">${state.amountsHidden?'••••••':fmt(Math.max(0,b.limit-used))} remaining</div></button>`;
}
function homeCategoryRows(){const totals=categoryList('expense').map(c=>({name:c,value:expenseByCategory(c)})).filter(c=>c.value>0).sort((a,b)=>b.value-a.value).slice(0,4),grand=sum(totals.map(c=>c.value));
 return totals.map(({name,value})=>{const [icon,color]=catVisuals[name]||['◈','#aaa'];return `<button class="category-row" data-action="category-open" data-category="${e(name)}"><span class="category-icon" style="background:${color}20;color:${color}">${icon}</span><span class="category-row-main"><strong>${e(name)}</strong><span class="category-meter"><span style="width:${Math.round(value/grand*100)}%"></span></span></span><span class="category-amount">${hiddenFmt(value)}</span></button>`;}).join('')||'<div class="app-empty">Add an expense to see category spending.</div>';
}
function sparkline(){return `<svg class="hero-sparkline" viewBox="0 0 600 60" preserveAspectRatio="none" role="img" aria-label="Animated decorative balance trend"><defs><linearGradient id="spark-fade" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#00bd91" stop-opacity=".10"/><stop offset="1" stop-color="#00bd91" stop-opacity="0"/></linearGradient></defs><path class="spark-fill" d="M0 53 C30 48 43 55 76 42 S125 48 154 36 S200 43 230 25 S270 34 310 26 S350 35 400 13 S455 26 485 10 S530 19 600 4 L600 60 L0 60Z"/><path class="spark-track" d="M0 53 C30 48 43 55 76 42 S125 48 154 36 S200 43 230 25 S270 34 310 26 S350 35 400 13 S455 26 485 10 S530 19 600 4"/></svg>`;}
function homeTile(title,subtitle,amount,icon,colorCls){return `<button class="app-nav-tile" data-page="accounts"><span class="nav-tile-icon ${colorCls}">${glyph(icon)}</span><span class="nav-tile-label"><strong>${title}</strong><small>${subtitle}</small></span><span class="nav-tile-amount">${hiddenFmt(amount)}</span>${glyph('arrow')}</button>`;}
function overview(){const totals=summary(),operating=state.accounts.filter(a=>a.type!=='Savings'),savings=state.accounts.filter(a=>a.type==='Savings');return `<div class="app-home-grid"><div class="app-column"><section class="demo-card app-hero"><div class="hero-top"><span>Net Balance</span><button class="hero-eye" data-action="toggle-amounts" aria-label="${state.amountsHidden?'Show':'Hide'} amounts" title="${state.amountsHidden?'Show':'Hide'} amounts">${glyph(state.amountsHidden?'eye-off':'eye')}</button></div><div class="hero-value">${hiddenFmt(balance(state))}</div><p class="hero-subtitle">${state.accounts.length} accounts total • ${periodLabel()} balance ${hiddenFmt(totals.income-totals.expense)}</p>${sparkline()}<div class="hero-mini-grid"><div class="hero-metric"><span class="metric-mark">${glyph('loans')}</span><div><small>Total income</small><strong>${hiddenFmt(totals.income)}</strong></div></div><div class="hero-metric"><span class="metric-mark expense">${glyph('analysis')}</span><div><small>Total expense</small><strong>${hiddenFmt(totals.expense)}</strong></div></div></div></section>${section('Accounts')}${homeTile('Accounts',`${operating.length} regular accounts`,sum(operating.map(a=>a.balance)),'wallet','')}${homeTile('Savings Accounts',`${savings.length} savings ${savings.length===1?'account':'accounts'}`,sum(savings.map(a=>a.balance)),'savings','savings')}${section('Budgets','View all','budgets')}${state.budgets.slice(0,2).map(nativeBudget).join('')||'<div class="app-empty">No budget yet. Create a sample budget.</div>'}</div><div class="app-column">${section('Category spending') }<div class="demo-card category-list">${homeCategoryRows()}</div></div></div>`;}


function accounts(){return `<div class="demo-message">Balances here represent sample money only. Create an account or transfer between existing accounts to try it out.</div><div class="section-toolbar"><button class="pill-button" data-action="add-account">+ Add account</button><button class="pill-button" data-action="add-transaction" data-type="transfer">⇄ Transfer money</button></div><div class="demo-account-grid">${state.accounts.map(a=>`<div class="demo-card account-card"><div class="account-head"><div class="account-symbol">${a.type==='Cash'?'◈':a.type==='Savings'?'◎':'▣'}</div><span class="type-pill">${e(a.type)}</span></div><div><div class="metric-label">${e(a.name)}</div><div class="account-amount">${fmt(a.balance)}</div></div></div>`).join('')}</div>`;}
function budgets(){return `<div class="demo-message">The sample budgets measure expenses in your current calendar month. Adding expenses updates them instantly.</div><div class="section-toolbar"><button class="pill-button" data-action="add-budget">+ New budget</button><button class="pill-button" data-action="add-transaction" data-type="expense">+ Record an expense</button></div><div class="demo-grid"><div class="demo-card span8"><div class="card-title-row"><h2>Category budgets</h2><span class="muted-caption">This month</span></div>${budgetRows()}</div><div class="demo-card span4"><div class="metric-label">TOTAL ALLOCATION</div><div class="metric-number">${fmt(sum(state.budgets.map(b=>b.limit)))}</div><div class="metric-hint">${fmt(sum(state.budgets.map(b=>spent(state,b.category))))} spent in budgeted categories</div><div style="margin-top:28px" class="metric-label">TIP</div><p class="note-content">Select Edit on a budget to try increasing or reducing the limit, or add a sample expense to change its progress.</p></div></div>`;}
function plans(){return `<div class="demo-message">Tap Buy on a plan to pick a sample account and record the purchase. This reflects the app's one-tap purchase flow.</div><div class="section-toolbar"><button class="pill-button" data-action="add-plan">+ New plan</button></div><div class="demo-item-grid">${state.plans.map(p=>`<div class="demo-card item-card"><div class="item-top"><div class="row-icon">✳</div><span class="type-pill">${e(p.category)}</span></div><div><h3>${e(p.title)}</h3><p>Saved for later</p><div class="item-amount">${fmt(p.amount)}</div></div><div class="item-footer"><button class="small-action" data-action="buy-plan" data-id="${e(p.id)}">Buy →</button><div class="item-actions"><button class="small-action" data-action="edit-plan" data-id="${e(p.id)}">Edit</button><button class="small-action danger" data-action="delete-plan" data-id="${e(p.id)}">Delete</button></div></div></div>`).join('')||'<div class="empty">Your plan list is clear. Add something you want to buy.</div>'}</div>`;}
function subscriptions(){return `<div class="demo-message">Real Yutaka supports scheduled recurring transactions. This public demo demonstrates adding subscriptions and manually recording a payment; no background scheduling runs here.</div><div class="section-toolbar"><button class="pill-button" data-action="add-sub">+ Add subscription</button></div><div class="demo-item-grid">${state.subscriptions.map(s=>`<div class="demo-card item-card"><div class="item-top"><div class="row-icon">◷</div><span class="type-pill">${e(s.period)}</span></div><div><h3>${e(s.title)}</h3><p>${e(s.category)} · ${e(accountName(s.accountId))}</p><div class="item-amount">${fmt(s.amount)} <span class="muted-caption">/ ${e(s.period.toLowerCase())}</span></div></div><div class="item-footer"><button class="small-action" data-action="record-sub" data-id="${e(s.id)}">Record now →</button><button class="small-action danger" data-action="delete-sub" data-id="${e(s.id)}">Delete</button></div></div>`).join('')||'<div class="empty">No subscriptions yet.</div>'}</div>`;}


// The four primary pages below mirror their Flutter screen structure rather
// than borrowing the product website's marketing dashboard components.
let categoryMode = 'expense';
let trendView='both';
let categoryManaging = false;
let loanFilter = 'collect';
let loanSearch = '';
let loanSearchOpen = false;
let loanDetailId = '';
let txSearch = '';
let txType = 'all';
let txSort = 'dateNewest';
let txAccount = 'all';
let txCategoryFilterOpen = false;
let txSortOpen = false;
let txFilterOpen = false;

const INCOME_CATEGORIES = ['Salary','Freelance','Other income'];
const incomeCategoryVisuals = {'Salary':['↙','#42d8a0'],'Freelance':['✧','#91c7fa'],'Other income':['✦','#adbbdb']};
const palette = ['#22dfb4','#a79bff','#7dcaf1','#ffb779','#fb9296','#93d989','#f3ce82','#a3b4ba'];
const categoryList = type => [...new Set([...(type==='income'?INCOME_CATEGORIES:CATEGORIES),...(state.customCategories||[]).filter(x=>x.type===type).map(x=>x.name)])];
const catDisplay = (name,index=0) => catVisuals[name]||incomeCategoryVisuals[name]||['◈',palette[index%palette.length]];
const miniMetric = (label,amount,icon,tone='') => `<div class="flutter-mini-metric"><span class="flutter-mini-icon ${tone}">${glyph(icon)}</span><span class="flutter-mini-content"><small>${e(label)}</small><strong>${hiddenFmt(amount)}</strong></span></div>`;
const dateKey = d => `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
const shortMoney = n => state.amountsHidden?'••••':fmt(n);

function trendBins(){
  const now=new Date(), period=state.demoPeriod;
  const points=[];
  if(period==='year'||period==='all'){
    const dates=filteredTransactions().map(t=>t.date.slice(0,7)).sort();
    const months=period==='year'?12:Math.min(12,Math.max(6,dates.length));
    const end=new Date(now.getFullYear(),now.getMonth(),1);
    const first=period==='year'?new Date(now.getFullYear(),0,1):new Date(end.getFullYear(),end.getMonth()-months+1,1);
    for(let month=new Date(first);month<=end;month.setMonth(month.getMonth()+1)){
      const key=dateKey(month).slice(0,7),tx=filteredTransactions().filter(t=>t.date.startsWith(key));
      points.push({key,label:month.toLocaleDateString('en-US',{month:'short'}),income:sum(tx.filter(t=>t.type==='income').map(t=>t.amount)),expense:sum(tx.filter(t=>t.type==='expense').map(t=>t.amount))});
    }
  }else{
    const end=period==='custom'&&state.demoEnd?new Date(`${state.demoEnd}T12:00:00`):new Date(now.getFullYear(),now.getMonth(),now.getDate());
    const first=period==='today'?new Date(end):period==='week'?new Date(end.getFullYear(),end.getMonth(),end.getDate()-(end.getDay()+6)%7):period==='custom'&&state.demoStart?new Date(`${state.demoStart}T12:00:00`):new Date(end.getFullYear(),end.getMonth(),1);
    const count=Math.max(1,Math.round((end-first)/86400000)+1);
    const stride=Math.max(1,Math.ceil(count/45));
    for(let i=0;i<count;i+=stride){
      const start=new Date(first);start.setDate(first.getDate()+i);
      const stop=new Date(start);stop.setDate(start.getDate()+stride);
      const date=dateKey(start),tx=filteredTransactions().filter(t=>t.date>=date&&t.date<dateKey(stop));
      points.push({key:date,label:start.toLocaleDateString('en-US',{month:'short',day:'numeric'}),income:sum(tx.filter(t=>t.type==='income').map(t=>t.amount)),expense:sum(tx.filter(t=>t.type==='expense').map(t=>t.amount))});
    }
  }
  return points.length?points:[{key:today(),label:'Today',income:0,expense:0}];
}
function cashFlowChart(){
  const points=trendBins(),s=summary(),net=s.income-s.expense;
  const visible=['income','expense'].filter(key=>trendView==='both'||key===trendView);
  const max=Math.max(1,...points.flatMap(x=>visible.map(key=>x[key])));
  const xx=i=>24+(points.length===1?296:(i/(points.length-1))*592),yy=n=>191-n/max*155;
  const path=key=>points.map((p,i)=>`${i?'L':'M'}${xx(i).toFixed(1)},${yy(p[key]).toFixed(1)}`).join(' ');
  const mid=Math.floor((points.length-1)/2);
  return `<div class="native-chart-card demo-card"><div class="native-trend-title"><span><strong class="native-card-title">Cash flow trend</strong><small>${e(periodLabel())}</small></span><span class="native-net-chip"><small>Net</small><strong class="${net>=0?'income':'expense'}">${hiddenFmt(net)}</strong></span></div><div class="native-trend-pills"><span><i class="income-dot"></i>Income <strong>${hiddenFmt(s.income)}</strong></span><span><i class="expense-dot"></i>Expense <strong>${hiddenFmt(s.expense)}</strong></span></div><div class="native-trend-selector" role="group" aria-label="Cash flow series">${[['both','Both'],['income','Income'],['expense','Expense']].map(([v,label])=>`<button data-action="trend-view" data-view="${v}" class="${trendView===v?'active':''}" aria-pressed="${trendView===v}">${label}</button>`).join('')}</div><div class="native-chart-inner"><svg class="native-cash-flow" viewBox="0 0 640 231" role="img" aria-label="${e(trendView)} line chart for ${e(periodLabel())}" preserveAspectRatio="none"><defs><linearGradient id="income-chart-fill" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#00bd91" stop-opacity=".24"/><stop offset="1" stop-color="#00bd91" stop-opacity="0"/></linearGradient></defs>${[0,1,2,3].map(i=>`<line x1="23" x2="620" y1="${36+i*51.7}" y2="${36+i*51.7}" class="native-chart-grid"/>`).join('')}${visible.includes('income')?`<path d="${path('income')} L${xx(points.length-1)},191 L${xx(0)},191 Z" fill="url(#income-chart-fill)" stroke="none"/><path d="${path('income')}" class="native-chart-income"/>${points.map((p,i)=>`<circle cx="${xx(i)}" cy="${yy(p.income)}" r="${points.length<12?3.3:1.5}" class="native-income-point"><title>${e(p.label)}: income ${fmt(p.income)}</title></circle>`).join('')}`:''}${visible.includes('expense')?`<path d="${path('expense')}" class="native-chart-expense"/>${points.map((p,i)=>`<circle cx="${xx(i)}" cy="${yy(p.expense)}" r="${points.length<12?3.3:1.5}" class="native-expense-point"><title>${e(p.label)}: expense ${fmt(p.expense)}</title></circle>`).join('')}`:''}<text x="24" y="222">${e(points[0].label)}</text><text x="316" y="222" text-anchor="middle">${e(points[mid].label)}</text><text x="618" y="222" text-anchor="end">${e(points[points.length-1].label)}</text></svg></div></div>`;
}
function periodDayCount(){
  const now=new Date(),period=state.demoPeriod;
  if(period==='today')return 1;
  if(period==='week')return 7;
  if(period==='month')return new Date(now.getFullYear(),now.getMonth()+1,0).getDate();
  if(period==='year')return Math.round((new Date(now.getFullYear()+1,0,1)-new Date(now.getFullYear(),0,1))/86400000);
  if(period==='custom'&&state.demoStart&&state.demoEnd)return Math.max(1,Math.round((new Date(`${state.demoEnd}T12:00:00`)-new Date(`${state.demoStart}T12:00:00`))/86400000)+1);
  const dates=state.transactions.map(t=>t.date).sort();if(!dates.length)return 1;
  return Math.max(1,Math.round((new Date(`${today()}T12:00:00`)-new Date(`${dates[0]}T12:00:00`))/86400000)+1);
}
function analytics(){
  const {income,expense}=summary(),days=periodDayCount();
  return `<div class="native-analysis-page"><div class="native-two-metrics">${miniMetric('Income',income,'loans','income')}${miniMetric('Expense',expense,'analysis','expense')}</div><div class="native-single-metric">${miniMetric('Balance',income-expense,'wallet','accent')}</div><div class="app-section-head"><h2>Cash flow</h2></div>${cashFlowChart()}<div class="app-section-head"><h2>Averages</h2></div><div class="native-two-metrics">${miniMetric('Income / day',income/Math.max(1,days),'analysis','income')}${miniMetric('Expense / day',expense/Math.max(1,days),'analysis','expense')}</div></div>`;
}

const txSortLabels = {dateNewest:'Newest first',dateOldest:'Oldest first',amountHigh:'Amount: high to low',amountLow:'Amount: low to high',categoryAsc:'Category: A–Z',categoryDesc:'Category: Z–A',titleAsc:'Title: A–Z',titleDesc:'Title: Z–A'};
function transactions(){
  const chips=[txCategoryFilter?`<button type="button" class="native-active-chip" data-action="clear-category">${e(txCategoryFilter)} ×</button>`:'',txType!=='all'?`<button type="button" class="native-active-chip" data-action="tx-clear-type">${e(txType)} ×</button>`:'',txAccount!=='all'?`<button type="button" class="native-active-chip" data-action="tx-clear-account">${e(accountName(txAccount))} ×</button>`:''].filter(Boolean);
  return `<div class="native-transactions-page"><div class="native-list-controls"><div class="native-search-shell">${glyph('transaction')}<input id="tx-search" class="native-search-input" type="search" value="${e(txSearch)}" placeholder="Search transactions" aria-label="Search transactions"></div><div class="native-control-buttons"><button type="button" data-action="tx-toggle-sort" class="native-tool-button ${txSortOpen?'selected':''}" aria-label="Sort transactions">≡ <span>Sort</span></button><button type="button" data-action="tx-toggle-filters" class="native-tool-button ${txFilterOpen?'selected':''}" aria-label="Filter transactions">☷ <span>Filters</span></button></div></div>${txSortOpen?`<label class="native-filter-label">Sort by<select id="tx-sort">${Object.entries(txSortLabels).map(([id,label])=>`<option value="${id}" ${txSort===id?'selected':''}>${e(label)}</option>`).join('')}</select></label>`:''}${txFilterOpen?`<div class="native-filter-panel"><label>Type<select id="tx-type"><option value="all">All types</option>${['expense','income','transfer'].map(t=>`<option value="${t}" ${txType===t?'selected':''}>${e(t[0].toUpperCase()+t.slice(1))}</option>`).join('')}</select></label><label>Account<select id="tx-account"><option value="all">All accounts</option>${state.accounts.map(a=>`<option value="${e(a.id)}" ${txAccount===a.id?'selected':''}>${e(a.name)}</option>`).join('')}</select></label><button data-action="tx-clear-all" class="native-text-action">Clear filters</button></div>`:''}${chips.length?`<div class="native-active-chips">${chips.join('')}<button data-action="tx-clear-all" class="native-text-action">Clear all</button></div>`:''}<div id="transactions-list" class="native-transaction-list"></div></div>`;
}
function txDisplay(t){
  const [icon,color]=t.type==='transfer'?['⇄','#38bdf8']:catDisplay(t.category);
  const amountTone=t.type==='income'?'income':t.type==='expense'?'expense':'accent';
  const title=t.type==='transfer'?`${accountName(t.accountId)} → ${accountName(t.toAccountId)}`:t.title||t.category;
  const subtitle=t.type==='transfer'?`${shortDate(t.date)} · Transfer`:`${t.category} · ${shortDate(t.date)} · ${accountName(t.accountId)}`;
  return `<div class="native-tx-row" data-tx-id="${e(t.id)}"><button type="button" data-action="edit-tx" data-id="${e(t.id)}" class="native-tx-main" aria-label="Edit ${e(title)} transaction"><span class="native-row-icon" style="--tone:${color}">${e(icon)}</span><span class="native-row-copy"><strong>${e(title)}</strong><small>${e(subtitle)}</small></span><strong class="native-row-money ${amountTone}">${t.type==='expense'?'−':t.type==='income'?'+':''}${hiddenFmt(t.amount)}</strong></button><div class="native-tx-actions"><button type="button" data-action="duplicate-tx" data-id="${e(t.id)}">Duplicate</button><button type="button" data-action="edit-tx" data-id="${e(t.id)}">Edit</button><button type="button" class="danger" data-action="delete-tx" data-id="${e(t.id)}">Delete</button></div></div>`;
}
function updateTxList(){
  const root=$('#transactions-list');if(!root)return;
  const rows=filteredTransactions().filter(t=>(!txCategoryFilter||t.category===txCategoryFilter)&&(txType==='all'||t.type===txType)&&(txAccount==='all'||t.accountId===txAccount)&&[t.title,t.category,accountName(t.accountId)].join(' ').toLowerCase().includes(txSearch));
  rows.sort((a,b)=>{
    if(txSort==='dateNewest')return b.date.localeCompare(a.date);
    if(txSort==='dateOldest')return a.date.localeCompare(b.date);
    if(txSort==='amountHigh')return b.amount-a.amount;
    if(txSort==='amountLow')return a.amount-b.amount;
    if(txSort==='categoryAsc')return a.category.localeCompare(b.category);
    if(txSort==='categoryDesc')return b.category.localeCompare(a.category);
    if(txSort==='titleAsc')return a.title.localeCompare(b.title);
    return b.title.localeCompare(a.title);
  });
  root.innerHTML=rows.length?rows.map(txDisplay).join(''):`<div class="app-empty">No transactions. Create one or change filters.<br><button class="native-primary-small" data-action="add-transaction">Add transaction</button></div>`;
  const shown=rows.length;$('#current-subtitle').textContent=`${shown} records • ${periodLabel()} • ${txSortLabels[txSort]}`;
}

const loanFilterNames={collect:'Collect',pay:'Pay',settled:'Settled',all:'All'};
function loanPortfolio(){
  const active=state.loans.filter(l=>l.outstanding>0),collect=sum(active.filter(l=>l.kind==='lent').map(l=>l.outstanding)),pay=sum(active.filter(l=>l.kind==='borrowed').map(l=>l.outstanding));
  const overdue=active.filter(l=>l.due&&l.due<today()).length;
  return `<section class="native-portfolio demo-card"><div class="native-card-title-row"><h2>Portfolio</h2>${overdue?`<span class="native-warn-pill">${overdue} overdue</span>`:''}</div><div class="native-two-metrics">${miniMetric('To collect',collect,'loans','income')}${miniMetric('To pay',pay,'loans','expense')}</div><div class="native-single-metric">${miniMetric('Net position',collect-pay,'wallet','accent')}</div></section>`;
}
function visibleLoans(){
  return state.loans.filter(l=>{
    if(loanFilter==='collect'&&(l.kind!=='lent'||l.outstanding<=0))return false;
    if(loanFilter==='pay'&&(l.kind!=='borrowed'||l.outstanding<=0))return false;
    if(loanFilter==='settled'&&l.outstanding>0)return false;
    if(loanFilter==='all'&&!state.loanShowSettled&&l.outstanding<=0)return false;
    return !loanSearch||`${l.title} ${l.note||''}`.toLowerCase().includes(loanSearch);
  });
}
function loanRows(){
  const rows=visibleLoans();if(!rows.length)return `<div class="app-empty">${loanFilter==='settled'?'Nothing settled yet':'No matching records'}.<br><button class="native-primary-small" data-action="add-loan">New loan</button></div>`;
  const group=new Map();for(const l of rows){const items=group.get(l.title)||[];items.push(l);group.set(l.title,items);}
  return [...group].map(([contact,items])=>`<div class="native-contact-group"><div class="native-contact-heading"><strong>${e(contact)}</strong><span>${shortMoney(sum(items.map(l=>(l.kind==='lent'?1:-1)*l.outstanding)))}</span></div>${items.map(l=>{const repaid=l.original-l.outstanding,pct=l.original?Math.min(100,Math.round(repaid/l.original*100)):100,overdue=l.outstanding>0&&l.due&&l.due<today();return `<div class="native-loan-card"><button class="native-loan-main" data-action="loan-view" data-id="${e(l.id)}"><span class="native-row-icon ${l.kind==='lent'?'income':'expense'}">${l.kind==='lent'?'⇙':'⇗'}</span><span class="native-row-copy"><strong>${e(l.title)}</strong><small class="${overdue?'warn':''}">${l.outstanding===0?'Settled':l.kind==='lent'?'They will pay you':'You will pay them'} · ${l.due?'Due '+shortDate(l.due):'No due date'}</small><span class="native-loan-progress"><span style="width:${pct}%;background:${overdue?'#ffbd68':l.kind==='lent'?'#27d17f':'#ff777e'}"></span></span></span><span class="native-loan-end"><strong>${hiddenFmt(l.outstanding)}</strong>›</span></button><div class="native-tx-actions"><button data-action="repay-loan" data-id="${e(l.id)}" ${l.outstanding<=0?'disabled':''}>Payment</button><button data-action="loan-view" data-id="${e(l.id)}">Details</button><button data-action="delete-loan" class="danger" data-id="${e(l.id)}">Delete</button></div></div>`;}).join('')}</div>`).join('');
}
function loanDetail(){
  const loan=state.loans.find(l=>l.id===loanDetailId);if(!loan){loanDetailId='';return ''}
  const payments=loan.payments||[];const pct=loan.original?Math.round((loan.original-loan.outstanding)/loan.original*100):100;
  return `<div class="native-loan-detail"><button class="native-back" data-action="back-loans">← Loans</button><div class="demo-card native-detail-hero"><h2>${e(loan.title)}</h2><p>${loan.kind==='lent'?'Money I lent':'Money I borrowed'} · ${e(accountName(loan.accountId))}</p><strong>${hiddenFmt(loan.outstanding)}</strong><small>Outstanding of ${hiddenFmt(loan.original)} · ${pct}% settled</small><div class="native-loan-progress"><span style="width:${pct}%"></span></div><button class="native-primary-small" data-action="repay-loan" data-id="${e(loan.id)}" ${loan.outstanding<=0?'disabled':''}>Record payment</button></div><div class="app-section-head"><h2>Payment history</h2></div><div class="demo-card">${payments.length?payments.map(p=>`<div class="native-history-row"><span>${e(shortDate(p.date))}</span><strong>${hiddenFmt(p.amount)}</strong></div>`).join(''):'<div class="app-empty">No repayments yet.</div>'}</div></div>`;
}
function loans(){
  if(loanDetailId)return loanDetail();
  return `<div class="native-loans-page">${loanPortfolio()}${loanSearchOpen?`<div class="native-search-shell native-loan-search">${glyph('loans')}<input id="loan-search" type="search" aria-label="Search people or notes" placeholder="Search people or notes" value="${e(loanSearch)}"></div>`:''}<div class="native-pill-selector" role="group" aria-label="Loan filter">${Object.entries(loanFilterNames).map(([id,label])=>`<button type="button" data-action="loan-filter" data-filter="${id}" class="${loanFilter===id?'active':''}" aria-pressed="${loanFilter===id}">${id==='collect'?'↙':id==='pay'?'↗':id==='settled'?'✓':'☷'} <span>${label}</span></button>`).join('')}</div><div class="app-section-head"><h2>${loanFilter==='settled'?'Settled records':'People'}</h2><button data-action="add-loan">+ New loan</button></div><div id="loan-records">${loanRows()}</div></div>`;
}

function breakdownItems(){
  const rows=filteredTransactions().filter(t=>t.type===categoryMode);
  const grand=sum(rows.map(t=>t.amount));
  const list=categoryList(categoryMode).map((name,i)=>{const value=sum(rows.filter(t=>t.category===name).map(t=>t.amount));return {name,value,color:catDisplay(name,i)[1],symbol:catDisplay(name,i)[0]};}).filter(c=>c.value>0).sort((a,b)=>b.value-a.value);
  return {grand,list};
}
function categoryDonut(list,grand){
  let offset=0;const gradient=list.length?list.map(row=>{const start=offset;offset+=row.value/grand*100;return `${row.color} ${start.toFixed(3)}% ${offset.toFixed(3)}%`;}).join(', '):'#263f3b 0% 100%';
  const badges=list.slice(0,8).map((item,i)=>{const ang=(-Math.PI/2)+2*Math.PI*(list.slice(0,i).reduce((s,r)=>s+r.value,0)+item.value/2)/grand;const x=50+Math.cos(ang)*45,y=50+Math.sin(ang)*45;return `<button class="native-orbit-badge" type="button" data-action="category-open" data-category="${e(item.name)}" style="left:${x}%;top:${y}%;--tone:${item.color}" title="${e(item.name)}: ${fmt(item.value)}"><span>${e(item.symbol)}</span><small>${Math.round(item.value/grand*100)}%</small></button>`;}).join('');
  return `<div class="native-donut-wrap"><div class="native-donut-surface"><div class="native-donut" role="img" aria-label="${e(categoryMode)} breakdown" style="background:conic-gradient(${gradient})"><div class="native-donut-hole"><strong>${hiddenFmt(grand)}</strong><span>Total ${categoryMode}</span><small>${e(periodLabel())}</small></div></div>${badges}</div></div>`;
}
function categories(){
  if(categoryManaging){const rows=categoryList(categoryMode);return `<div class="native-manage-categories"><button class="native-back" data-action="back-breakdown">← Categories</button><div class="native-card-title-row"><h2>${categoryMode==='expense'?'Expense':'Income'} categories</h2><button class="native-primary-small" data-action="add-category">+ Add</button></div><div class="demo-card native-manage-list">${rows.map((name,i)=>{const [symbol,color]=catDisplay(name,i),custom=state.customCategories?.some(c=>c.name===name&&c.type===categoryMode);return `<div class="native-manage-row"><span class="native-row-icon" style="--tone:${color}">${e(symbol)}</span><span>${e(name)}</span>${custom?`<button data-action="edit-category" data-id="${e(name)}" data-type="${categoryMode}" data-category="${e(name)}">Edit</button><button class="danger" data-action="delete-category" data-category="${e(name)}">Delete</button>`:'<small>Default</small>'}</div>`;}).join('')}</div></div>`;}
  const {grand,list}=breakdownItems();return `<div class="native-categories-page"><div class="native-pill-selector native-category-toggle" role="group" aria-label="Breakdown type"><button type="button" data-action="category-mode" data-type="expense" class="${categoryMode==='expense'?'active':''}" aria-pressed="${categoryMode==='expense'}">↗ <span>Expense</span></button><button type="button" data-action="category-mode" data-type="income" class="${categoryMode==='income'?'active':''}" aria-pressed="${categoryMode==='income'}">↙ <span>Income</span></button></div><section class="demo-card native-breakdown"><div class="native-card-title">${categoryMode==='expense'?'Expense':'Income'} breakdown</div>${list.length?categoryDonut(list,grand):`<div class="app-empty">No ${categoryMode} data yet. Transactions will appear here by category.</div>`}${list.length?`<div class="native-breakdown-list">${list.map((item,i)=>`<button class="native-breakdown-row" data-action="category-open" data-category="${e(item.name)}"><span class="native-row-icon" style="--tone:${item.color}">${e(item.symbol)}</span><span class="native-row-copy"><strong>${i+1}. ${e(item.name)}</strong><span class="native-category-track"><span style="width:${(item.value/grand*100).toFixed(2)}%;background:${item.color}"></span></span></span><span class="native-breakdown-amount"><strong>${hiddenFmt(item.value)}</strong><small>${Math.round(item.value/grand*100)}%</small></span></button>`).join('')}</div>`:''}</section><button class="native-manage-button" type="button" data-action="manage-categories"><span class="native-row-icon">◈</span><span><strong>Manage categories</strong><small>${categoryMode==='expense'?'Expense':'Income'} categories</small></span><span>›</span></button></div>`;
}

function safeRichHtml(raw){
  const template=document.createElement('template');template.innerHTML=String(raw||'');
  const allowed=new Set(['B','STRONG','I','EM','S','STRIKE','MARK','CODE','BR','P','DIV','UL','OL','LI','A']);
  const walk=node=>{
    if(node.nodeType===Node.TEXT_NODE)return e(node.textContent);
    if(node.nodeType!==Node.ELEMENT_NODE)return '';
    const tag=node.tagName.toUpperCase();
    const children=[...node.childNodes].map(walk).join('');
    if(tag==='SPAN'&&/background-color\s*:/.test(node.getAttribute('style')||''))return `<mark>${children}</mark>`;
    if(!allowed.has(tag))return children;
    if(tag==='BR')return '<br>';
    if(tag==='A'){
      const href=node.getAttribute('href');
      try{const url=new URL(href,location.href);if(['https:','http:'].includes(url.protocol))return `<a href="${e(url.href)}" target="_blank" rel="noopener noreferrer">${children}</a>`;}catch{}return children;
    }
    return `<${tag.toLowerCase()}>${children}</${tag.toLowerCase()}>`;
  };
  return [...template.content.childNodes].map(walk).join('');
}
function noteMarkup(n){return n.rich?safeRichHtml(n.body):e(n.body).replace(/\n/g,'<br>');}
function noteCards(rows){return rows.map(n=>`<div class="demo-card app-note-card"><div class="note-top"><span class="row-icon">${glyph('note')}</span><div class="note-card-text"><strong>${e(n.title)}</strong><small>${e(shortDate(n.created))}</small></div></div><div class="note-content native-note-content">${noteMarkup(n)}</div><div class="item-footer"><button class="small-action" data-action="edit-note" data-id="${e(n.id)}">Edit</button><button class="small-action danger" data-action="delete-note" data-id="${e(n.id)}">Delete</button></div></div>`).join('');}
function notes(){return `<div class="section-toolbar"><button class="pill-button" data-action="add-note">+ Add note</button><input id="note-search" class="text-input" aria-label="Search notes" type="search" placeholder="Search notes…"></div><div id="notes-list">${noteList(state.notes)}</div>`;}
function noteList(rows){if(!rows.length)return '<div class="app-empty">No matching notes. Add a note or try another search.</div>';return `<div class="app-section-head"><h2>Recent</h2></div><div class="app-note-grid">${noteCards(rows.slice(0,2))}</div>${rows.length>2?`<div class="app-section-head"><h2>More entries</h2></div><div class="app-note-grid">${noteCards(rows.slice(2))}</div>`:''}`;}
function updateNoteList(){const term=($('#note-search')?.value||'').trim().toLowerCase();$('#notes-list').innerHTML=noteList(state.notes.filter(n=>`${n.title} ${n.body.replace(/<[^>]*>/g,'')}`.toLowerCase().includes(term)));}

function settings(){return `<div class="demo-message">Demo mode uses fictional data stored in this browser. Self-hosted sync, backup, notifications and actual bank integrations are intentionally unavailable.</div><div class="demo-card"><div class="app-setting-row"><span class="row-icon">${glyph('wallet')}</span><span class="row-label"><strong>Currency customization</strong><small>Choose how sample amounts are displayed.</small></span><select id="currency-picker" aria-label="Currency"><option value="USD" ${state.currency==='USD'?'selected':''}>USD</option><option value="BDT" ${state.currency==='BDT'?'selected':''}>BDT</option><option value="EUR" ${state.currency==='EUR'?'selected':''}>EUR</option></select></div><div class="app-setting-row"><span class="row-icon">${glyph('eye')}</span><span class="row-label"><strong>Hide amounts</strong><small>Mask the financial figures on the Home screen.</small></span><button data-action="toggle-amounts">${state.amountsHidden?'Show':'Hide'}</button></div><div class="app-setting-row"><span class="row-icon">${glyph('restore')}</span><span class="row-label"><strong>Reset sample data</strong><small>Restore the fictional starter transactions and balances.</small></span><button data-action="reset-demo">Reset</button></div><div class="app-setting-row"><span class="row-icon">${glyph('settings')}</span><span class="row-label"><strong>Account & sync</strong><small>Available only in the installed Yutaka app.</small></span><span class="muted-caption">Demo only</span></div></div><div class="section-toolbar" style="margin-top:17px"><a href="/" class="pill-button">← Back to website</a></div><div class="app-section-head"><h2>Explore other pages</h2></div><div class="demo-grid">${[['Accounts','accounts'],['Budgets','budgets'],['Plan','plans'],['Subscription','subscriptions'],['Note','notes']].map(([title,target])=>`<button class="app-nav-tile span6" data-page="${target}"><span class="nav-tile-label"><strong>${title}</strong></span>${glyph('arrow')}</button>`).join('')}</div>`;}
const views={overview,analytics,loans,transactions,categories,accounts,budgets,plans,subscriptions,notes,settings};
const MAIN_PAGES=new Set(['overview','analytics','loans','transactions','categories']);
function render(){
 const title=PAGES[page];$('#current-path').textContent=title;
 const sub=page==='loans'?'Money you lent and borrowed':page==='categories'?(categoryMode==='expense'?'Expense breakdown':'Income breakdown'):MAIN_PAGES.has(page)?periodLabel():page==='settings'?'Personalize your sample':'Sample data';
 $('#current-subtitle').textContent=sub;
 $('#demo-view').innerHTML=views[page]();
 document.querySelectorAll('.demo-nav button, .app-dock button, .app-more-nav button').forEach(b=>{const active=(b.dataset.page||b.dataset.mobile)===page;b.classList.toggle('active',active);if(active)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current');});
 $('#date-range-trigger').hidden=!MAIN_PAGES.has(page);$('#settings-trigger').hidden=page==='settings';
 $('#native-page-actions').innerHTML=page==='loans'?`<button class="native-header-action" data-action="loan-toggle-search" title="Search people" aria-label="Search people">⌕</button><button class="native-header-action" data-action="loan-preferences" title="Loan preferences" aria-label="Loan preferences">☷</button><button class="native-header-action" data-action="add-loan" title="New loan" aria-label="New loan">＋</button>`:page==='transactions'?`<button class="native-header-action" data-action="tx-toggle-sort" title="Sort" aria-label="Sort transactions">≡</button><button class="native-header-action" data-action="tx-toggle-filters" title="Filters" aria-label="Filter transactions">☷</button>`:page==='analytics'?`<button class="native-header-action" data-action="analysis-filter" title="Change period" aria-label="Change analysis period">☷</button>`:'';
 if(page==='transactions'){
   updateTxList();$('#tx-search').addEventListener('input',ev=>{txSearch=ev.target.value.trim().toLowerCase();updateTxList();});
   $('#tx-sort')?.addEventListener('change',ev=>{txSort=ev.target.value;updateTxList();});
   $('#tx-type')?.addEventListener('change',ev=>{txType=ev.target.value;render();});
   $('#tx-account')?.addEventListener('change',ev=>{txAccount=ev.target.value;render();});
 }
 if(page==='loans')$('#loan-search')?.addEventListener('input',ev=>{loanSearch=ev.target.value.trim().toLowerCase();$('#loan-records').innerHTML=loanRows();});
 if(page==='notes')$('#note-search').addEventListener('input',updateNoteList);
 if(page==='settings')$('#currency-picker').addEventListener('change',ev=>{state.currency=ev.target.value;save();render();toast('Demo currency updated.');});
}
function closeMore(){$('#demo-sidebar').hidden=true;$('#more-backdrop').hidden=true;$('#sidebar-trigger').setAttribute('aria-expanded','false');}
function openMore(){closeQuick();$('#demo-sidebar').hidden=false;$('#more-backdrop').hidden=false;$('#sidebar-trigger').setAttribute('aria-expanded','true');}
function closeQuick(){$('#quick-menu').hidden=true;$('#quick-backdrop').hidden=true;$('#quick-menu-button').setAttribute('aria-expanded','false');}
function toggleQuick(){const isClosed=$('#quick-menu').hidden;closeMore();$('#quick-menu').hidden=!isClosed;$('#quick-backdrop').hidden=!isClosed;$('#quick-menu-button').setAttribute('aria-expanded',String(isClosed));}
function navigate(p){if(!PAGES[p])return;page=p;history.replaceState(null,'',`#${p}`);closeMore();closeQuick();render();$('#demo-main').scrollTo({top:0,behavior:'instant'});}
function openDialog(kind,entryId='',preset=''){
  const dialog=$('#demo-dialog'),form=$('#dialog-form');form.dataset.kind=kind;form.dataset.id=entryId;$('#dialog-error').hidden=true;let body='',title='',submit='Save';
  if(kind==='add-transaction'||kind==='edit-tx'){const original=state.transactions.find(t=>t.id===entryId);title=original?'Edit transaction':'New transaction';const selected=original?.type||(['expense','income','transfer'].includes(preset)?preset:'expense');body=`${field('Type','type',select('type',`<option value="expense" ${selected==='expense'?'selected':''}>Expense</option><option value="income" ${selected==='income'?'selected':''}>Income</option><option value="transfer" ${selected==='transfer'?'selected':''}>Transfer</option>`))}${field('Title','title',`<input name="title" maxlength="90" placeholder="e.g. Coffee or Paycheck" value="${e(original?.title||'')}">`)}<div class="field-row">${field('Amount','amount',`<input name="amount" type="number" min="0.01" max="1000000000" step="0.01" value="${original?.amount||''}" required>`)}${field('Date','date',`<input name="date" type="date" value="${e(original?.date||today())}" required>`)}</div>${field('Account','accountId',select('accountId',acctOptions(original?.accountId)))}<div id="category-field">${field('Category','category',select('category',catOptions(original?.category|| (selected==='income'?'Salary':'Food & drinks'),selected==='income'?'income':'expense')))}</div><div id="destination-field" hidden>${field('Destination account','toAccountId',select('toAccountId',acctOptions(original?.toAccountId||state.accounts[1]?.id||'',original?.accountId||state.accounts[0]?.id||'')))}</div>`;submit=original?'Save changes':'Add transaction';}
  if(kind==='add-account'){title='New sample account';body=`${field('Account name','name',input('name','e.g. Travel savings','maxlength="55"'))}${field('Account type','type',select('type','<option>Cash</option><option>Bank</option><option>Savings</option><option>Card</option><option>Custom</option>'))}${field('Starting balance','balance',input('balance','0.00','type="number" min="0" max="1000000000" step="0.01"'))}`;}
  if(kind==='add-budget'||kind==='edit-budget'){const b=state.budgets.find(v=>v.id===entryId);title=b?'Edit budget':'New budget';const remaining=categoryList('expense').filter(c=>!state.budgets.some(v=>v.category===c)||c===b?.category);body=`${field('Category','category',select('category',remaining.map(c=>`<option ${c===b?.category?'selected':''}>${e(c)}</option>`).join('')))}${field('Monthly limit','limit',`<input name="limit" type="number" min="0.01" max="1000000000" step="0.01" value="${b?.limit||''}" required>`)}`;}
  if(kind==='add-plan'||kind==='edit-plan'){const p=state.plans.find(v=>v.id===entryId);title=p?'Edit plan':'Add a plan';body=`${field('Purchase name','title',`<input name="title" maxlength="90" placeholder="e.g. New headphones" value="${e(p?.title||'')}" required>`)}${field('Expected price','amount',`<input name="amount" type="number" min="0.01" max="1000000000" step="0.01" value="${p?.amount||''}" required>`)}${field('Category','category',select('category',catOptions(p?.category)))}`;}
  if(kind==='buy-plan'){const p=state.plans.find(v=>v.id===entryId);if(!p)return;title=`Buy ${p.title}`;body=`<p class="note-content">Record a ${fmt(p.amount)} purchase against one of your sample accounts.</p>${field('Pay from','accountId',select('accountId',acctOptions()))}`;submit='Confirm purchase';}
  if(kind==='add-sub'){title='New subscription';body=`${field('Subscription name','title',input('title','e.g. Streaming plan','maxlength="90"'))}${field('Amount','amount',input('amount','0.00','type="number" min="0.01" max="1000000000" step="0.01"'))}<div class="field-row">${field('Frequency','period',select('period','<option>Monthly</option><option>Weekly</option><option>Yearly</option><option>Daily</option>'))}${field('Category','category',select('category',catOptions('Entertainment')))}</div>${field('Pay from','accountId',select('accountId',acctOptions()))}`;}
  if(kind==='record-sub'){const s=state.subscriptions.find(v=>v.id===entryId);if(!s)return;title='Record subscription';body=`<p class="note-content">Add a ${fmt(s.amount)} expense for ${e(s.title)}. The subscription itself stays on your list.</p>${field('Pay from','accountId',select('accountId',acctOptions(s.accountId)))}`;submit='Record payment';}
  if(kind==='add-loan'){title='New loan';body=`${field('Person or purpose','title',input('title','e.g. Alex','maxlength="90"'))}${field('Direction','kind',select('kind','<option value="lent">Money I lent</option><option value="borrowed">Money I borrowed</option>'))}${field('Principal amount','amount',input('amount','0.00','type="number" min="0.01" max="1000000000" step="0.01"'))}<div class="field-row">${field('Account','accountId',select('accountId',acctOptions()))}${field('Due date','due',`<input name="due" type="date" value="${today()}" required>`)}</div>`;}
  if(kind==='repay-loan'){const l=state.loans.find(v=>v.id===entryId);if(!l)return;title='Record repayment';body=`<p class="note-content">Outstanding: ${fmt(l.outstanding)}. ${l.kind==='lent'?'Your account receives this repayment.':'Your account pays this repayment.'}</p>${field('Amount','amount',`<input name="amount" type="number" min="0.01" max="${l.outstanding}" value="${l.outstanding}" step="0.01" required>`)}${field('Account','accountId',select('accountId',acctOptions(l.accountId)))}`;submit='Record repayment';}
  if(kind==='add-category'||kind==='edit-category'){const old=kind==='edit-category'?entryId:'';title=old?'Edit category':'New category';body=`${field('Name','name',`<input name="name" maxlength="45" value="${e(old)}" placeholder="Category name" required>`)}${field('Type','type',select('type',`<option value="expense" ${categoryMode==='expense'?'selected':''}>Expense</option><option value="income" ${categoryMode==='income'?'selected':''}>Income</option>`))}`;}
  if(kind==='add-note'||kind==='edit-note'){
    const n=state.notes.find(v=>v.id===entryId);title=n?'Edit note':'New note';
    body=`${field('Title','title',`<input name="title" maxlength="90" placeholder="e.g. Savings goal" value="${e(n?.title||'')}" required>`)}<div class="field"><span>Note</span><div class="note-format-toolbar" aria-label="Text formatting"><button type="button" data-note-format="bold" aria-label="Bold" title="Bold"><b>B</b></button><button type="button" data-note-format="italic" aria-label="Italic" title="Italic"><i>I</i></button><button type="button" data-note-format="strikeThrough" aria-label="Strikethrough" title="Strikethrough"><s>S</s></button><button type="button" data-note-format="hiliteColor" aria-label="Highlight" title="Highlight">◩</button><button type="button" data-note-format="createLink" aria-label="Insert link" title="Insert link">↗</button><button type="button" data-note-format="insertUnorderedList" aria-label="Bullet list" title="Bullet list">☷</button><button type="button" data-note-format="inlineCode" aria-label="Inline code" title="Inline code">&lt;/&gt;</button><button type="button" data-note-format="undo" aria-label="Undo" title="Undo">↶</button><button type="button" data-note-format="redo" aria-label="Redo" title="Redo">↷</button></div><div id="rich-editor" class="note-rich-editor" contenteditable="true" role="textbox" aria-label="Note text" aria-multiline="true" data-placeholder="Your thoughts…">${n?noteMarkup(n):''}</div><input type="hidden" name="body" value=""></div>`;
  }
  if(!title)return;$('#dialog-title').textContent=title;$('#dialog-body').innerHTML=body;$('#dialog-submit').textContent=submit;
  if(kind==='add-transaction'||kind==='edit-tx'){const refresh=()=>{const t=form.elements.type.value;const categorySelect=form.elements.category,old=categorySelect.value;categorySelect.innerHTML=catOptions(old|| (t==='income'?'Salary':'Food & drinks'),t==='income'?'income':'expense');$('#category-field').hidden=t==='transfer';$('#destination-field').hidden=t!=='transfer';form.elements.category.required=t!=='transfer';form.elements.toAccountId.required=t==='transfer';};form.elements.type.addEventListener('change',refresh);form.elements.accountId.addEventListener('change',()=>{const f=$('#destination-field select');f.innerHTML=acctOptions('',form.elements.accountId.value);});refresh();}
  if(kind==='add-note'||kind==='edit-note')noteSelection=null;dialog.showModal();const first=form.querySelector('.dialog-body input,.dialog-body select');setTimeout(()=>first?.focus(),10);
}
function processForm(event){event.preventDefault();const form=$('#dialog-form'),kind=form.dataset.kind,entryId=form.dataset.id;
 if(kind==='add-note'||kind==='edit-note'){form.elements.body.value=safeRichHtml($('#rich-editor').innerHTML);}
 const fd=new FormData(form),get=k=>String(fd.get(k)||'').trim(),number=k=>Number(fd.get(k));const error=$('#dialog-error');error.hidden=true;
  try {
    if(kind==='add-transaction'||kind==='edit-tx'){const data={type:get('type'),title:get('title'),amount:number('amount'),date:get('date'),category:get('category'),accountId:get('accountId'),toAccountId:get('toAccountId')};if(kind==='edit-tx')editTransaction(state,entryId,data);else transaction(state,data);}
    else if(kind==='add-account'){if(!get('name'))throw Error('Enter an account name.');if(!Number.isFinite(number('balance'))||number('balance')<0||number('balance')>1e9)throw Error('Invalid starting balance.');state.accounts.push({id:id(),name:get('name'),type:get('type'),balance:number('balance')});}
    else if(kind==='add-budget'||kind==='edit-budget'){if(!number('limit')||number('limit')<0||number('limit')>1e9)throw Error('Invalid budget limit.');if(kind==='add-budget')state.budgets.push({id:id(),category:get('category'),limit:number('limit')});else Object.assign(state.budgets.find(b=>b.id===entryId),{category:get('category'),limit:number('limit')});}
    else if(kind==='add-plan'||kind==='edit-plan'){if(!get('title')||number('amount')<=0||number('amount')>1e9)throw Error('Enter a name and valid amount.');const obj={title:get('title'),amount:number('amount'),category:get('category')};if(kind==='add-plan')state.plans.push({id:id(),...obj});else Object.assign(state.plans.find(p=>p.id===entryId),obj);}
    else if(kind==='buy-plan')buyPlan(state,entryId,get('accountId'));
    else if(kind==='add-sub'){if(!get('title')||number('amount')<=0||number('amount')>1e9)throw Error('Enter a name and valid amount.');state.subscriptions.push({id:id(),title:get('title'),amount:number('amount'),category:get('category'),period:get('period'),accountId:get('accountId')});}
    else if(kind==='record-sub')recordSubscription(state,entryId,get('accountId'));
    else if(kind==='add-loan'){if(!get('title')||number('amount')<=0||number('amount')>1e9)throw Error('Enter a name and valid amount.');const acc=state.accounts.find(a=>a.id===get('accountId'));if(!acc)throw Error('Choose an account.');acc.balance+=get('kind')==='lent'?-number('amount'):number('amount');state.loans.push({id:id(),title:get('title'),kind:get('kind'),outstanding:number('amount'),original:number('amount'),accountId:get('accountId'),due:get('due')});}
    else if(kind==='repay-loan')repayLoan(state,entryId,get('accountId'),number('amount'));
    else if(kind==='add-category'||kind==='edit-category'){const name=get('name'),type=get('type');if(!name||name.length>45)throw Error('Enter a category name.');if(categoryList(type).some(c=>c.toLowerCase()===name.toLowerCase()&&!(kind==='edit-category'&&c===entryId&&type===categoryMode)))throw Error('That category already exists.');if(kind==='edit-category'){const target=state.customCategories.find(c=>c.name===entryId&&c.type===categoryMode);if(!target)throw Error('Category not found.');if(type!==categoryMode&&(state.transactions.some(t=>t.type===categoryMode&&t.category===entryId)||state.budgets.some(b=>b.category===entryId)||state.plans.some(v=>v.category===entryId)||state.subscriptions.some(v=>v.category===entryId)))throw Error('Change the linked records before changing category type.');for(const t of state.transactions)if(t.type===categoryMode&&t.category===entryId)t.category=name;for(const b of state.budgets)if(categoryMode==='expense'&&b.category===entryId)b.category=name;for(const p of state.plans)if(p.category===entryId&&categoryMode==='expense')p.category=name;for(const sub of state.subscriptions)if(sub.category===entryId&&categoryMode==='expense')sub.category=name;Object.assign(target,{name,type});categoryMode=type;}else{state.customCategories.push({name,type});categoryMode=type;}}
    else if(kind==='add-note'||kind==='edit-note'){if(!get('title')||!$('#rich-editor').textContent.trim())throw Error('Enter a title and note.');if(kind==='add-note')state.notes.unshift({id:id(),title:get('title'),body:get('body'),rich:true,created:today()});else Object.assign(state.notes.find(n=>n.id===entryId),{title:get('title'),body:get('body'),rich:true});}
    save();$('#demo-dialog').close();render();toast('Sample data updated.');
  }catch(err){error.textContent=err.message||'Could not save.';error.hidden=false;}
}
let noteSelection=null;
document.addEventListener('selectionchange',()=>{const editor=$('#rich-editor');if(!editor)return;const selection=window.getSelection();if(selection?.rangeCount&&editor.contains(selection.anchorNode))noteSelection=selection.getRangeAt(0).cloneRange();});
document.addEventListener('mousedown',event=>{if(event.target.closest('[data-note-format]'))event.preventDefault();});
document.addEventListener('click',event=>{
  const formatButton=event.target.closest('[data-note-format]');
  if(formatButton){
    const editor=$('#rich-editor');if(!editor)return;
    editor.focus();const selection=window.getSelection();if(noteSelection){selection.removeAllRanges();selection.addRange(noteSelection);}
    const kind=formatButton.dataset.noteFormat;
    if(kind==='createLink'){
      const href=window.prompt('Enter an HTTPS link:','https://');if(!href)return;
      try{const url=new URL(href);if(!['https:','http:'].includes(url.protocol))throw Error('Unsupported link');document.execCommand('createLink',false,url.href);}catch{toast('Use an http or https link.');}
    } else if(kind==='inlineCode'){
      if(!selection.rangeCount||selection.isCollapsed){toast('Select text to format as inline code.');return;}
      const range=selection.getRangeAt(0),code=document.createElement('code');code.appendChild(range.extractContents());range.insertNode(code);range.selectNodeContents(code);selection.removeAllRanges();selection.addRange(range);
    }else document.execCommand(kind,false,kind==='hiliteColor'?'#8fe0be':null);
    noteSelection=selection.rangeCount?selection.getRangeAt(0).cloneRange():null;
    return;
  }

  const btn=event.target.closest('[data-page],[data-mobile],[data-action]');if(!btn)return;
  if(btn.dataset.page||btn.dataset.mobile){navigate(btn.dataset.page||btn.dataset.mobile);return;}
  const action=btn.dataset.action,entryId=btn.dataset.id||'';
  if(action==='trend-view'){trendView=btn.dataset.view;render();return;}
  if(action==='analysis-filter'){document.querySelector('#date-range-trigger').click();return;}
  if(action==='category-mode'){categoryMode=btn.dataset.type;categoryManaging=false;render();return;}
  if(action==='manage-categories'){categoryManaging=true;render();return;}
  if(action==='back-breakdown'){categoryManaging=false;render();return;}
  if(action==='delete-category'){
    const name=btn.dataset.category,custom=state.customCategories.find(c=>c.name===name&&c.type===categoryMode);
    if(!custom)return;
    const used=state.transactions.some(t=>t.type===categoryMode&&t.category===name)||state.budgets.some(b=>b.category===name)||state.plans.some(p=>p.category===name)||state.subscriptions.some(s=>s.category===name);
    if(used){toast('This category has linked records and cannot be removed.');return;}
    if(!window.confirm(`Delete the ${name} sample category?`))return;
    state.customCategories=state.customCategories.filter(c=>c!==custom);save();render();return;
  }
  if(action==='loan-filter'){loanFilter=btn.dataset.filter;loanDetailId='';render();return;}
  if(action==='loan-view'){loanDetailId=btn.dataset.id;render();return;}
  if(action==='back-loans'){loanDetailId='';render();return;}
  if(action==='loan-toggle-search'){loanSearchOpen=!loanSearchOpen;if(!loanSearchOpen)loanSearch='';render();if(loanSearchOpen)$('#loan-search')?.focus();return;}
  if(action==='loan-preferences'){state.loanShowSettled=!state.loanShowSettled;save();render();toast(state.loanShowSettled?'Showing settled records in All':'Hiding settled records in All');return;}
  if(action==='tx-toggle-sort'){txSortOpen=!txSortOpen;txFilterOpen=false;render();return;}
  if(action==='tx-toggle-filters'){txFilterOpen=!txFilterOpen;txSortOpen=false;render();return;}
  if(action==='tx-clear-type'){txType='all';render();return;}
  if(action==='tx-clear-account'){txAccount='all';render();return;}
  if(action==='tx-clear-all'){txType='all';txAccount='all';txCategoryFilter='';txSearch='';render();return;}
  if(action==='duplicate-tx'){
    const original=state.transactions.find(t=>t.id===entryId);if(!original)return;
    try{transaction(state,{...original,date:today()});save();render();toast('Sample transaction duplicated.');}catch(err){toast(err.message||'Could not duplicate.');}return;
  }
  if(action==='quick-menu'){toggleQuick();return;}
  if(action==='toggle-amounts'){state.amountsHidden=!state.amountsHidden;save();render();return;}
  if(action==='date-range'){const dialog=$('#range-dialog');dialog.querySelector(`input[name=period][value=${state.demoPeriod}]`).checked=true;$('#range-start').value=state.demoStart||today();$('#range-end').value=state.demoEnd||today();$('#custom-range').hidden=state.demoPeriod!=='custom';dialog.showModal();return;}
  if(action==='clear-category'){txCategoryFilter='';render();return;}
  if(action==='category-open'){txCategoryFilter=btn.dataset.category;txType=page==='categories'?categoryMode:'expense';navigate('transactions');toast(`Showing ${txCategoryFilter} transactions`);return;}
  if(action==='reset-demo'){if(!window.confirm('Reset all changes and restore fictional sample data?'))return;state=seed();state.demoPeriod='month';state.amountsHidden=false;state.customCategories=[];state.loanShowSettled=true;txCategoryFilter='';txAccount='all';txType='all';txSearch='';loanFilter='collect';loanDetailId='';categoryMode='expense';categoryManaging=false;save();closeMore();render();toast('Demo reset.');return;}
  const modals=new Set(['edit-tx','add-category','edit-category','add-transaction','add-account','add-budget','edit-budget','add-plan','edit-plan','buy-plan','add-sub','record-sub','add-loan','repay-loan','add-note','edit-note']);
  if(modals.has(action)){closeQuick();openDialog(action,entryId,btn.dataset.type);return;}
  if(action?.startsWith('delete-')){
    const names={'delete-tx':'transaction','delete-budget':'budget','delete-plan':'plan','delete-sub':'subscription','delete-loan':'loan','delete-note':'note'};
    if(!names[action]||!window.confirm(`Remove this sample ${names[action]}?`))return;
    if(action==='delete-tx')removeTransaction(state,entryId);
    else if(action==='delete-loan'){const loan=state.loans.find(l=>l.id===entryId);if(loan){const originalAccount=state.accounts.find(a=>a.id===loan.accountId);if(originalAccount)originalAccount.balance+=loan.kind==='lent'?loan.original:-loan.original;for(const payment of loan.payments||[]){const account=state.accounts.find(a=>a.id===payment.accountId);if(account)account.balance+=loan.kind==='lent'?-payment.amount:payment.amount;}state.loans=state.loans.filter(l=>l.id!==entryId);loanDetailId='';}}
    else {const arr={'delete-budget':'budgets','delete-plan':'plans','delete-sub':'subscriptions','delete-loan':'loans','delete-note':'notes'}[action];state[arr]=state[arr].filter(v=>v.id!==entryId);}
    save();render();toast('Sample item removed.');
  }
});
$('#dialog-form').addEventListener('submit',processForm);
$('#dialog-close').addEventListener('click',()=>$('#demo-dialog').close());
$('#dialog-cancel').addEventListener('click',()=>$('#demo-dialog').close());
$('#sidebar-trigger').addEventListener('click',()=>$('#demo-sidebar').hidden?openMore():closeMore());
$('#more-close').addEventListener('click',closeMore);
$('#more-backdrop').addEventListener('click',closeMore);
$('#quick-backdrop').addEventListener('click',closeQuick);
$('#range-close').addEventListener('click',()=>$('#range-dialog').close());
$('#range-cancel').addEventListener('click',()=>$('#range-dialog').close());
$('#period-options').addEventListener('change',event=>{$('#custom-range').hidden=event.target.value!=='custom';});
$('#range-form').addEventListener('submit',event=>{event.preventDefault();const period=new FormData(event.target).get('period')||'month',start=$('#range-start').value,end=$('#range-end').value;if(period==='custom'&&(!start||!end||start>end)){toast('Choose a valid start and end date.');return;}state.demoPeriod=period;state.demoStart=start;state.demoEnd=end;save();$('#range-dialog').close();render();});
window.addEventListener('keydown',event=>{if(event.key==='Escape'){closeQuick();closeMore();}});
window.addEventListener('hashchange',()=>{const next=location.hash.slice(1);if(PAGES[next]&&next!==page){page=next;closeMore();closeQuick();render();}});
render();
