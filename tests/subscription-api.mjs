// Run: SUBSCRIPTION_TEST_FIXTURES='[manifest from subscription-api-fixtures.sql]' node tests/subscription-api.mjs
// Only synthetic stores from that manifest may be used. Cleanup is an administrator step.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
const manifest=JSON.parse(process.env.SUBSCRIPTION_TEST_FIXTURES||'null');
assert.ok(Array.isArray(manifest)&&manifest.length,'Provide the synthetic fixture manifest');
const source=fs.readFileSync(new URL('../js/lib/supabase.js',import.meta.url),'utf8');
const url=source.match(/const SUPABASE_URL = '([^']+)'/)[1];
const key=source.match(/const SUPABASE_ANON_KEY = '([^']+)'/)[1];
const headers={'Content-Type':'application/json',apikey:key,Authorization:'Bearer '+key};
let assertions=0;
for(const f of manifest){
 const info=await fetch(url+'/rest/v1/stores?id=eq.'+f.store_id+'&select=name',{headers}).then(r=>r.json());
 assert.ok(info[0]?.name.startsWith('SECURITY TEST '),'Refusing to order from a real customer store');
 const request_id=randomUUID();
 const body={store_id:f.store_id,request_id,order:{
  items:[{productId:f.product_id,quantity:1}],orderType:'pickup',
  customer:{name:'SECURITY REGRESSION',phone:'5500000000000'},payment:{method:'cash'},total:1
 }};
 const r=await fetch(url+'/functions/v1/create-order',{method:'POST',headers,body:JSON.stringify(body)});
 const data=await r.json();
 assert.equal(r.status,f.allowed?200:403,f.scenario+': '+JSON.stringify(data));
 assert.equal(!!data.order,f.allowed,f.scenario+' unexpected order');
 assertions+=2;
 const status=await fetch(url+'/rest/v1/rpc/public_store_status',{method:'POST',headers,body:JSON.stringify({p_store_id:f.store_id})});
 assert.equal(status.status,200);
 assert.equal(['trial','active'].includes(await status.json()),f.allowed);
 assertions+=2;
 console.log('PASS',f.scenario,'HTTP',r.status);
}
for(const [rpc,args] of [
 ['ensure_subscription',{p_store_id:manifest[0].store_id}],
 ['prepare_billing',{p_store_id:manifest[0].store_id,p_amount:19}],
 ['apply_verified_payment',{p_payment_id:'forged',p_store_id:manifest[0].store_id,p_amount:19,p_status:'approved'}],
 ['place_verified_order',{p_store_id:manifest[0].store_id,p_request_id:randomUUID(),p_snapshot:{}}]
]){
 const r=await fetch(url+'/rest/v1/rpc/'+rpc,{method:'POST',headers,body:JSON.stringify(args)});
 assert.ok([401,403].includes(r.status),rpc+' unexpectedly executable: '+r.status);
 assertions++;
 console.log('PASS anonymous direct RPC denied',rpc,r.status);
}
console.log(JSON.stringify({passed_assertions:assertions,synthetic_stores:manifest.length}));

