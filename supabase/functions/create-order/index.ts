import {createClient} from 'https://esm.sh/@supabase/supabase-js@2.112.4';
import {cors,response,required} from '../_shared/http.ts';
import {priceOrder} from '../_shared/pricing.js';
Deno.serve(async req=>{
 if(req.method==='OPTIONS') return new Response('ok',{headers:cors});
 if(req.method!=='POST') return response({error:'POST required'},405);
 try {
  const text=await req.text();if(text.length>50000) return response({error:'Pedido muito grande.'},413);
  const {store_id,request_id,order}=JSON.parse(text);
  if(!/^[a-f0-9-]{36}$/i.test(store_id||'')||!/^[a-f0-9-]{36}$/i.test(request_id||'')) return response({error:'Pedido inválido.'},400);
  const db=createClient(required('SUPABASE_URL'),required('SUPABASE_SERVICE_ROLE_KEY'));
  const results=await Promise.all([
   db.from('stores').select('*').eq('id',store_id).eq('status','open').single(),
   db.from('store_settings').select('*').eq('store_id',store_id).maybeSingle(),
   db.from('products').select('*').eq('store_id',store_id).eq('available',true),
   db.from('pizza_sizes').select('*').eq('store_id',store_id).eq('is_active',true),
   db.from('addon_groups').select('*,addon_options(*)').eq('store_id',store_id),
   db.from('offers').select('*,offer_groups(*,offer_group_items(*)),offer_schedules(*)').eq('store_id',store_id).eq('active',true),
   db.from('neighborhoods').select('*').eq('store_id',store_id).eq('is_active',true)
  ]);
  if(results.some(r=>r.error)) throw new Error('Não foi possível carregar o catálogo.');
  const [store,settings,products,sizes,groups,offers,neighborhoods]=results.map(r=>r.data);
  const {data:prices,error}=await db.from('product_size_prices').select('*').in('product_id',products.map((p:any)=>p.id));if(error) throw error;
  const now=new Date();const local=new Date(now.toLocaleString('en-US',{timeZone:'America/Fortaleza'}));
  const minute=local.getHours()*60+local.getMinutes(),day=local.getDay();
  const activeOffers=offers.filter((o:any)=>!o.offer_schedules.length||o.offer_schedules.some((s:any)=>{
   const minutes=(t:string)=>Number(t.slice(0,2))*60+Number(t.slice(3,5));const start=minutes(s.start_time),end=minutes(s.end_time);
   return end<start?(s.weekday===day&&minute>=start)||((s.weekday+1)%7===day&&minute<=end):s.weekday===day&&minute>=start&&minute<=end;
  })).map((o:any)=>({...o,groups:o.offer_groups}));
  const snapshot=priceOrder(order,{store,settings:settings||{},products,sizes,prices,neighborhoods,offers:activeOffers,addons:groups.flatMap((g:any)=>g.addon_options.map((a:any)=>({...a,group_name:g.name})))});
  if(Math.abs(snapshot.total-Number(order.total))>0.01) return response({error:'Os preços mudaram. Atualize o cardápio e confira a sacola.'},409);
  const {data,error:saveError}=await db.rpc('place_verified_order',{p_store_id:store_id,p_request_id:request_id,p_snapshot:snapshot});
  if(saveError) throw new Error('Não foi possível registrar o pedido. Aguarde e tente novamente.');
  return response({order:data});
 } catch(error){return response({error:error instanceof Error?error.message:'Não foi possível registrar o pedido.'},400);}
});
