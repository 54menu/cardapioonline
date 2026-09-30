import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import vm from 'node:vm';
import {JSDOM} from 'jsdom';import {parse} from 'acorn';
import {priceOrder} from '../supabase/functions/_shared/pricing.js';
import {verifySignature} from '../supabase/functions/_shared/signature.js';
const catalog={store:{id:'shop',name:'Loja',phone:'5585999999999',default_delivery_fee:7,min_order_value:0},settings:{},
 products:[{id:'pizza',name:'Pizza A',base_price:40,is_pizza:true,has_crusts:true,has_extras:true},{id:'pizza2',name:'Pizza B',base_price:60,is_pizza:true},{id:'drink',name:'Bebida',base_price:10}],
 sizes:[{id:'g',name:'Grande',max_flavors:4}],prices:[],addons:[{id:'crust',name:'Borda',price_diff:8,group_name:'Bordas'},{id:'extra',name:'Queijo',price_diff:4,group_name:'Extras'}],neighborhoods:[{id:'a',delivery_fee:5},{id:'b',delivery_fee:9}],offers:[]};
const order=()=>({items:[{productId:'pizza',quantity:1}],orderType:'pickup',customer:{name:'Teste',phone:'85999999999'},payment:{method:'pix'},total:40});
test('prices come from catalog, not user values',()=>{const o=order();o.items[0].unitPrice=0.01;o.items[0].itemTotal=0.01;assert.equal(priceOrder(o,catalog).total,40);});
test('rejects negative quantity, foreign products and extras',()=>{
 for(const item of [{productId:'pizza',quantity:-1},{productId:'foreign',quantity:1},{productId:'pizza',quantity:1,extras:[{id:'foreign',price:0}]}])assert.throws(()=>priceOrder({...order(),items:[item]},catalog));
});
test('whole pizza combines sizes, flavors and addons',()=>{
 const o=order();o.items=[{productId:'pizza',size:{id:'g'},flavorIds:['pizza2'],quantity:2,crust:{id:'crust',price:0},extras:[{id:'extra'}]}];
 assert.equal(priceOrder(o,catalog).total,144);
});
test('fractional max and proportional modes and incomplete pizza',()=>{
 const o=order();o.items=[{productId:'pizza',size:{id:'g'},fractionValue:0.5,quantity:1},{productId:'pizza2',size:{id:'g'},fractionValue:0.5,quantity:1}];
 assert.equal(priceOrder(o,catalog).total,60);
 assert.equal(priceOrder(o,{...catalog,settings:{fraction_pricing_mode:'proportional'}}).total,50);
 o.items.pop();assert.throws(()=>priceOrder(o,catalog),/Complete/);
});
test('delivery fee is chosen from store neighborhood',()=>{
 const o={...order(),orderType:'delivery',neighborhoodId:'b',deliveryAddress:{street:'Rua',number:'1',neighborhood:'B'}};
 assert.equal(priceOrder(o,catalog).total,49);o.neighborhoodId='foreign';assert.throws(()=>priceOrder(o,catalog),/bairro/);
});
test('offer checks group quantities, product membership and max per order',()=>{
 const c={...catalog,offers:[{id:'offer',name:'Combo',price:45,active:true,max_per_order:1,groups:[{id:'group',name:'Bebidas',quantity:1,offer_group_items:[{product_id:'drink',extra_price:2}]}]}]};
 const o={...order(),items:[{isOffer:true,offerId:'offer',quantity:1,offerGroups:[{groupId:'group',items:[{product_id:'drink'}]}]}]};
 assert.equal(priceOrder(o,c).total,47);o.items[0].quantity=2;assert.throws(()=>priceOrder(o,c),/Limite/);
});
test('webhook verifies signature and rejects forged or missing headers',async()=>{
 const secret='test-only';const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['sign']);
 const hash=Buffer.from(await crypto.subtle.sign('HMAC',key,new TextEncoder().encode('id:123;request-id:req;ts:1704908010;'))).toString('hex');
 assert.equal(await verifySignature(secret,'123','req','ts=1704908010,v1='+hash),true);
 assert.equal(await verifySignature(secret,'999','req','ts=1704908010,v1='+hash),false);
 assert.equal(await verifySignature(secret,'123',null,null),false);
});
test('unsafe customer HTML cannot execute and UI controls survive',()=>{
 const dom=new JSDOM('',{runScripts:'outside-only'});const w=dom.window;
 w.eval(fs.readFileSync('js/vendor/purify.min.js','utf8'));w.eval(fs.readFileSync('js/lib/safe-html.js','utf8'));
 const result=w.safeHTML('<img src=x onerror="alert(1)"><svg onload="alert(2)"></svg><a href="javascript:alert(3)">a</a><input id="quantity" data-id="a" value="1"><script>alert(4)</script>');
 w.document.body.innerHTML=result;assert.equal(w.document.querySelectorAll('[onerror],[onload],script,[href^="javascript:"]').length,0);assert.ok(w.document.getElementById('quantity'));dom.window.close();
});
test('overnight schedule belongs to previous day in Fortaleza',()=>{
 const w={};vm.runInNewContext(fs.readFileSync('js/lib/schedule.js','utf8'),{window:w,Intl,Date});
 const schedule={seg:{open:'18:00',close:'02:00'},ter:{closed:true}};
 assert.equal(w.storeOpenNow(schedule,'open',new Date('2026-09-29T04:00:00Z')),true);
 assert.equal(w.storeOpenNow(schedule,'closed',new Date('2026-09-29T04:00:00Z')),false);
 assert.equal(w.storeOpenNow(schedule,'open',new Date('2026-09-29T06:00:00Z')),false);
});
test('order waits for database and uses server number',async()=>{
 let resolve;const saved=new Promise(r=>resolve=r);const w={appState:{store:{id:'s'},cart:{items:[],orderType:'pickup'},getSubtotal:()=>0,getDeliveryFee:()=>0,getTotal:()=>0},storage:{saveOrder:()=>saved}};
 vm.runInNewContext(fs.readFileSync('js/services/order.js','utf8'),{window:w,crypto,Date,Math});
 let done=false;const result=w.orderService.createOrderSnapshot({customer:{name:'Teste'}}).then(r=>{done=true;return r;});await Promise.resolve();assert.equal(done,false);
 resolve({orderNumber:'PDV-123'});assert.equal((await result).orderNumber,'PDV-123');
 w.storage.saveOrder=()=>Promise.reject(new Error('offline'));await assert.rejects(w.orderService.createOrderSnapshot({customer:{}}),/offline/);
});
test('public server refuses database and private files',async()=>{
 for(const path of ['/supabase-schema.sql','/.git/config','/package.json'])assert.equal((await fetch(process.env.TEST_BASE_URL+path)).status,404);
});
test('all runtime JavaScript parses and HTML sinks are sanitized',()=>{
 function files(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(dir+'/'+e.name):[dir+'/'+e.name]);}
 for(const file of files('js').filter(p=>p.endsWith('.js')&&!p.includes('/vendor/'))){
  const source=fs.readFileSync(file,'utf8'),ast=parse(source,{ecmaVersion:'latest',sourceType:'module'});
  function walk(n){if(!n||typeof n!=='object')return;
   if(n.type==='AssignmentExpression'&&n.left.type==='MemberExpression'&&['innerHTML','outerHTML'].includes(n.left.property.name))assert.ok(source.slice(n.right.start,n.right.end).startsWith('window.safeHTML('),file);
   Object.values(n).forEach(v=>Array.isArray(v)?v.forEach(walk):v&&typeof v==='object'?walk(v):null);
  }walk(ast);
 }
});
