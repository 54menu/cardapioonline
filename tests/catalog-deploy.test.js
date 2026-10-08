import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import os from 'node:os';import path from 'node:path';import net from 'node:net';import crypto from 'node:crypto';
import EmbeddedPostgres from 'embedded-postgres';import {fixture,sid,uid,cat,size} from './catalog-fixture.js';
import {priceOrder} from '../supabase/functions/_shared/pricing.js';
const read=p=>fs.readFileSync(p,'utf8');
const compatibility=read('supabase/migrations/20261007113743_achado4_catalog_compatibility.sql');
const enforcement=read('supabase/migrations/20261007113745_achado4_catalog_enforcement.sql');
const operation=name=>read('supabase/operations/achado4/'+name+'.sql');
const data={name:'Synthetic deploy test',category_id:cat,codigo:101,is_pizza:true,available:true,has_crusts:true,has_extras:true,is_featured:false,featured_order:0,base_price:0};
const rpc=(c,id,prices,patch={})=>c.query('select (public.save_product_with_prices($1,$2,$3,$4)).id',[sid,id,JSON.stringify({...data,...patch}),JSON.stringify(prices)]);
const login=c=>c.query(`set role authenticated;select set_config('request.jwt.claim.sub','${uid}',false)`);
const directInsert=`insert into products(store_id,category_id,name,base_price,is_pizza,available) values('${sid}','${cat}','Old panel synthetic',0,true,true) returning id`;
const denial=async fn=>{await assert.rejects(fn,e=>['23514','55000','42501','P0001'].includes(e.code));};

test('native PostgreSQL deploy A–F, legacy exit and independent-session races',{timeout:120000},async t=>{
 const listener=net.createServer();await new Promise(r=>listener.listen(0,'127.0.0.1',r));const port=listener.address().port;await new Promise(r=>listener.close(r));
 const temp=fs.mkdtempSync(path.join(os.tmpdir(),'zapmenu-achado4-'));const resolved=fs.realpathSync(temp);
 assert.ok(resolved.startsWith(fs.realpathSync(os.tmpdir())+path.sep));
 const logs=[];const server=new EmbeddedPostgres({databaseDir:temp,port,user:'postgres',password:crypto.randomBytes(24).toString('hex'),persistent:true,authMethod:'scram-sha-256',postgresFlags:['-h','127.0.0.1'],onLog:m=>logs.push(String(m)),onError:m=>logs.push(String(m))});
 const clients=[];let started=false;
 const connect=async()=>{const c=server.getPgClient('postgres','127.0.0.1');await c.connect();clients.push(c);await c.query("set statement_timeout='10s';set lock_timeout='7s'");return c;};
 try{
 await server.initialise();await server.start();started=true;
 const admin=await connect(),client=await connect();await admin.query(fixture);await login(client);
 const snapshot=async()=> (await admin.query("select jsonb_agg(p order by id) rows from products p where name like 'Legacy %'")).rows;
 const original=await snapshot();
 await t.test('A: old panel two writes still work, exposing intermediate inconsistency',async()=>{
   const id=(await client.query(directInsert)).rows[0].id;
   assert.equal((await admin.query('select count(*)::int n from product_size_prices where product_id=$1',[id])).rows[0].n,0);
   await client.query('insert into product_size_prices values($1,$2,60)',[id,size]);await client.query('delete from products where id=$1',[id]);
 });
 await admin.query(compatibility);
 await t.test('compatibility alone: RPC validates itself without enforcement objects',async()=>{
   assert.equal((await admin.query("select to_regclass('private.catalog_write_guard') x")).rows[0].x,null);
   await denial(()=>rpc(client,null,[]));const id=(await rpc(client,null,[{size_id:size,price:60}])).rows[0].id;
   await client.query('delete from products where id=$1',[id]);
 });
 await t.test('compatibility leaves old panel schema-compatible',async()=>{const id=(await client.query(directInsert)).rows[0].id;await client.query('delete from products where id=$1',[id]);});
 await admin.query(operation('maintenance-install'));
 await t.test('B: old tab/direct API blocked by server maintenance',async()=>denial(()=>client.query(directInsert)));
 await t.test('B: service-role order insert is paused too',async()=>{await admin.query('set role service_role');try{await denial(()=>admin.query('insert into orders default values'));}finally{await admin.query('reset role');}});
 await t.test('B: client cannot release gate or forge a bypass setting',async()=>{
   await denial(()=>client.query('update private.achado4_maintenance set catalog_paused=false'));
   await client.query("select set_config('app.maintenance_bypass','true',false)");await denial(()=>client.query(directInsert));
 });
 await t.test('C: new panel RPC is present but ordinary saves remain paused',async()=>denial(()=>rpc(client,null,[{size_id:size,price:60}])));
 await admin.query(enforcement);
 await t.test('D: enforcement installation preserves all 37 legacy rows exactly',async()=>assert.deepEqual(await snapshot(),original));
 await t.test('D: new RPC and direct writes remain paused',async()=>{await denial(()=>rpc(client,null,[{size_id:size,price:60}]));await denial(()=>client.query(directInsert));});
 await t.test('D: owner-only transactional smoke does not release maintenance to other sessions',async()=>{
   await admin.query('begin');try{
     await admin.query('update private.achado4_maintenance set catalog_paused=false');await login(admin);
     await rpc(admin,null,[{size_id:size,price:60}]);await denial(()=>client.query(directInsert));
   }finally{await admin.query('rollback');await admin.query('reset role');}
   assert.equal((await admin.query('select catalog_paused from private.achado4_maintenance')).rows[0].catalog_paused,true);
 });
 await t.test('E: corrected pricing rejects missing association while orders stay paused',async()=>{
   const catalog={store:{id:sid,name:'Synthetic'},products:[{id:'p',is_pizza:true,base_price:0}],sizes:[{id:size,is_active:true}],prices:[]};
   assert.throws(()=>priceOrder({items:[{productId:'p',quantity:1,size:{id:size}}]},catalog),/tamanho/i);
   await denial(()=>client.query('insert into orders default values'));
 });
 await admin.query(operation('maintenance-release'));
 await t.test('F: valid RPC and order insertion work after explicit release',async()=>{const id=(await rpc(client,null,[{size_id:size,price:60}])).rows[0].id;await client.query('delete from products where id=$1',[id]);await client.query('insert into orders default values');});
 await t.test('38th inconsistent via RPC is rejected',async()=>denial(()=>rpc(client,null,[])));
 await t.test('38th inconsistent via direct insert/old panel first write is rejected',async()=>denial(()=>client.query(directInsert)));
 await t.test('legacy can exit through RPC and cannot return by deleting its last price',async()=>{
   const id=(await admin.query("select id from products where name='Legacy 1'")).rows[0].id;
   await rpc(client,id,[{size_id:size,price:60}]);await denial(()=>client.query('delete from product_size_prices where product_id=$1',[id]));
 });
 await t.test('legacy unchanged edit rejected; pausing allowed',async()=>{
   const id=(await admin.query("select id from products where name='Legacy 2'")).rows[0].id;
   await denial(()=>client.query("update products set name='Still invalid' where id=$1",[id]));await client.query('update products set available=false where id=$1',[id]);
 });
 const a=await connect(),b=await connect();await login(a);await login(b);
 const apid=(await a.query('select pg_backend_pid() p')).rows[0].p,bpid=(await b.query('select pg_backend_pid() p')).rows[0].p;assert.notEqual(apid,bpid);
 const invariant=async()=>{
   const bad=await admin.query(`select count(*)::int n from products p where p.is_pizza and p.available and p.name not like 'Legacy %' and not exists(select 1 from product_size_prices v join pizza_sizes s on s.id=v.size_id where v.product_id=p.id and s.store_id=p.store_id and s.is_active and v.price>0 and v.price::text not in ('NaN','Infinity','-Infinity'))`);
   assert.equal(bad.rows[0].n,0);
 };
 async function race(label,opA,opB,expectedA){
   await t.test(label,async()=>{
     const id=(await rpc(client,null,[{size_id:size,price:60}])).rows[0].id;
     await a.query('begin');await b.query('begin');let outcomeA;let done=false;
     try{
       await opA(a,id);
       const pending=opB(b,id).then(()=>({ok:true}),error=>({ok:false,error})).finally(()=>done=true);
       let blocked=false;
       for(let n=0;n<150&&!done;n++){
         const state=(await admin.query('select wait_event_type from pg_stat_activity where pid=$1',[bpid])).rows[0];
         if(state?.wait_event_type==='Lock'){blocked=true;break;}await new Promise(r=>setTimeout(r,10));
       }
       assert.ok(blocked,'Second independent connection must overlap and wait');
       try{await a.query('commit');outcomeA=true;}catch(e){assert.equal(e.code,'23514');outcomeA=false;await a.query('rollback');}
       const outcomeB=await pending;if(!outcomeB.ok)throw outcomeB.error;await b.query('commit');
       assert.equal(outcomeA,expectedA);await invariant();
     }finally{await a.query('rollback');await b.query('rollback');await client.query('delete from products where id=$1',[id]);}
   });
 }
 await race('race: two price updates', (c,id)=>c.query('update product_size_prices set price=61 where product_id=$1',[id]),(c,id)=>c.query('update product_size_prices set price=62 where product_id=$1',[id]),true);
 await race('race: delete last price versus product edit',(c,id)=>c.query('delete from product_size_prices where product_id=$1',[id]),(c,id)=>c.query("update products set name='Concurrent valid' where id=$1",[id]),false);
 await race('race: deactivate size versus price update',c=>c.query('update pizza_sizes set is_active=false where id=$1',[size]),(c,id)=>c.query('update product_size_prices set price=63 where product_id=$1',[id]),false);
 await race('race: two simultaneous transactional RPCs',(c,id)=>rpc(c,id,[{size_id:size,price:64}]),(c,id)=>rpc(c,id,[{size_id:size,price:65}]),true);
 await race('race: remove price versus RPC edit',(c,id)=>c.query('delete from product_size_prices where product_id=$1',[id]),(c,id)=>rpc(c,id,[{size_id:size,price:66}]),false);
 await t.test('write skew: concurrent deletion of two different valid prices cannot empty product',async()=>{
   const second='77777777-7777-4777-8777-777777777777';await client.query('insert into pizza_sizes values($1,$2,true)',[second,sid]);
   const id=(await rpc(client,null,[{size_id:size,price:60},{size_id:second,price:70}])).rows[0].id;
   await a.query('begin');await b.query('begin');
   try{
     await a.query('delete from product_size_prices where product_id=$1 and size_id=$2',[id,size]);
     const pending=b.query('delete from product_size_prices where product_id=$1 and size_id=$2',[id,second]).then(()=>null,e=>e);
     let blocked=false;for(let n=0;n<150;n++){if((await admin.query('select wait_event_type from pg_stat_activity where pid=$1',[bpid])).rows[0]?.wait_event_type==='Lock'){blocked=true;break;}await new Promise(r=>setTimeout(r,10));}
     assert.ok(blocked);await a.query('commit');assert.equal(await pending,null);await assert.rejects(()=>b.query('commit'),e=>e.code==='23514');await b.query('rollback');await invariant();
   }finally{await a.query('rollback');await b.query('rollback');await client.query('delete from products where id=$1',[id]);await client.query('delete from pizza_sizes where id=$1',[second]);}
 });
 await t.test('repeatable-read stale snapshot aborts instead of bypassing serialization',async()=>{
   const id=(await rpc(client,null,[{size_id:size,price:60}])).rows[0].id;
   await a.query('begin');await b.query('begin isolation level repeatable read');await b.query('select * from product_size_prices where product_id=$1',[id]);
   try{
     await a.query('update product_size_prices set price=61 where product_id=$1',[id]);
     const pending=b.query('update product_size_prices set price=62 where product_id=$1',[id]).then(()=>null,e=>e);
     let blocked=false;for(let n=0;n<150;n++){if((await admin.query('select wait_event_type from pg_stat_activity where pid=$1',[bpid])).rows[0]?.wait_event_type==='Lock'){blocked=true;break;}await new Promise(r=>setTimeout(r,10));}
     assert.ok(blocked);await a.query('commit');assert.equal((await pending)?.code,'40001');await b.query('rollback');await invariant();
   }finally{await a.query('rollback');await b.query('rollback');await client.query('delete from products where id=$1',[id]);}
 });
 await t.test('maintenance removal leaves enforcement intact',async()=>{await admin.query(operation('maintenance-remove'));await denial(()=>client.query(directInsert));await invariant();});
 await t.test('operational rollback requires maintenance and preserves product rows',async()=>{
   await admin.query(operation('maintenance-install'));const before=(await admin.query('select jsonb_agg(p order by id) rows from products p')).rows;
   await admin.query(compatibility);await admin.query(operation('enforcement-remove'));
   assert.deepEqual((await admin.query('select jsonb_agg(p order by id) rows from products p')).rows,before);
   await denial(()=>client.query(directInsert));await admin.query(enforcement);await admin.query(operation('maintenance-release'));await admin.query(operation('maintenance-remove'));await invariant();
 });
 console.log('NATIVE_POSTGRES_VERSION='+ (await admin.query('show server_version')).rows[0].server_version+'; independent_backends='+apid+','+bpid+'; races=7; invariant_violations=0');
 }catch(e){console.error(logs.slice(-8).join('\n'));throw e;}
 finally{
   for(const c of clients)await c.end().catch(()=>{});
   if(started)await server.stop();
   if(fs.existsSync(temp)&&fs.realpathSync(temp)===resolved&&resolved.startsWith(fs.realpathSync(os.tmpdir())+path.sep))fs.rmSync(temp,{recursive:true,force:true});
 }
});
