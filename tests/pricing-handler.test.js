import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
import {priceOrder} from '../supabase/functions/_shared/pricing.js';

// Execute the real Edge handler with Request/Response and an isolated database double.
// No production calls or catalog mutations are performed by this suite.
const source=stripTypeScriptTypes(readFileSync(new URL('../supabase/functions/create-order/index.ts',import.meta.url),'utf8').replace(/^import .*;\r?\n/gm,''));
const storeId='11111111-1111-4111-8111-111111111111';
const requestId='22222222-2222-4222-8222-222222222222';
async function call(item, total=60, extras={}){
 const saved=[];
 const tables={
  stores:{id:storeId,name:'Fixture',status:'open'},store_settings:{},
  products:[{id:'pizza',name:'Pizza',available:true,is_pizza:true,base_price:0},{id:'drink',name:'Drink',available:true,is_pizza:false,base_price:10}],
  pizza_sizes:[{id:'large',name:'Large',is_active:true,max_flavors:2}],
  product_size_prices:[{product_id:'pizza',size_id:'large',price:60}],
  addon_groups:[],offers:[],neighborhoods:[]
 };
 const db={
  from(name){const q={};for(const op of ['select','eq','in','single','maybeSingle'])q[op]=()=>q;q.then=(resolve,reject)=>Promise.resolve({data:tables[name],error:null}).then(resolve,reject);return q;},
  async rpc(name,args){if(name==='public_store_status')return {data:'active',error:null};assert.equal(name,'place_verified_order');saved.push(args.p_snapshot);return {data:{id:requestId,total:args.p_snapshot.total},error:null};}
 };
 let handler;
 new Function('Deno','createClient','required','response','cors','priceOrder',source)(
  {serve:fn=>{handler=fn;}},()=>db,()=> 'fixture',
  (value,status=200)=>new Response(JSON.stringify(value),{status}),{},priceOrder
 );
 const order={items:[item],orderType:'pickup',customer:{name:'Fixture test',phone:'5500000000000'},payment:{method:'pix'},total,...extras};
 const result=await handler(new Request('http://localhost/create-order',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({store_id:storeId,request_id:requestId,order})}));
 return {status:result.status,body:await result.json(),saved};
}
const pizza=()=>({productId:'pizza',quantity:1,size:{id:'large'}});
test('direct handler: valid size persists server price, omitted size never reaches save RPC',async()=>{
 const good=await call(pizza());assert.equal(good.status,200);assert.equal(good.saved[0].total,60);
 const bad=await call({productId:'pizza',quantity:1});assert.equal(bad.status,400);assert.match(bad.body.error,/tamanho/);assert.equal(bad.saved.length,0);
});
for(const size of [{},{id:''},{id:'foreign-size'}])test('direct handler refuses size '+JSON.stringify(size),async()=>{
 const result=await call({...pizza(),size});assert.equal(result.status,400);assert.equal(result.saved.length,0);
});
test('direct handler ignores forged item and subtotal economics',async()=>{
 const result=await call({...pizza(),unitPrice:0,price:0,itemTotal:0,size:{id:'large',price:0}},60,{subtotal:0,discount:999});
 assert.equal(result.status,200);assert.equal(result.saved[0].items[0].unitPrice,60);assert.equal(result.saved[0].subtotal,60);
});
test('direct handler requires quote reconfirmation when total is forged',async()=>{
 const result=await call(pizza(),0);assert.equal(result.status,409);assert.equal(result.saved.length,0);
});
test('direct handler rejects string quantity without saving',async()=>{
 const result=await call({...pizza(),quantity:'1'});assert.equal(result.status,400);assert.equal(result.saved.length,0);
});
test('direct handler preserves normal base-priced product checkout',async()=>{
 const result=await call({productId:'drink',quantity:2},20);assert.equal(result.status,200);assert.equal(result.saved[0].total,20);
});
