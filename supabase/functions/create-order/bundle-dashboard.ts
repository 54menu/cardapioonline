// Bundle arquivo único — create-order (gerado, não edite; origem: supabase/functions/)
// Como usar: Dashboard Supabase → Edge Functions → create-order → apague o
// conteúdo do editor, cole TUDO deste arquivo e clique em Deploy.
// Inclui _shared/http.ts + _shared/pricing.js (lógica atual de metades somadas,
// fixo por tamanho e taxa-pela-loja) + handler. Requer Deno/TypeScript no editor.
import {createClient} from 'https://esm.sh/@supabase/supabase-js@2.112.4';
export const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
export function response(value: unknown, status=200) { return new Response(JSON.stringify(value), {status,headers:{...cors,'Content-Type':'application/json'}}); }
export function required(name:string) { const value=Deno.env.get(name); if(!value) throw new Error('Service configuration missing'); return value; }

const money = value => {
 if(typeof value!=='number'||!Number.isFinite(value)||value<0) fail('Preço inválido no catálogo.');
 const cents=Math.round(value*100);
 if(!Number.isSafeInteger(cents)) fail('Preço inválido no catálogo.');
 return cents;
};
const fail = message => { throw new Error(message); };
const quantity = value => typeof value==='number' && Number.isInteger(value) && value>0 && value<=50 ? value : fail('Quantidade inválida.');
export function priceOrder(input, catalog) {
 const {store,settings={},products=[],sizes=[],prices=[],addons=[],offers=[],neighborhoods=[]}=catalog;
 if(!Array.isArray(input.items)||!input.items.length||input.items.length>50) fail('Sacola inválida.');
 const product=id=>products.find(p=>p.id===id&&p.available!==false)||fail('Produto indisponível.');
 const price=(p,size)=>{
  if(!p.is_pizza) return money(p.base_price);
  if(!size) fail('Selecione um tamanho válido para a pizza.');
  const row=prices.find(v=>v.product_id===p.id&&v.size_id===size.id);
  if(!row) fail('Pizza indisponível neste tamanho.');
  const cents=money(row.price);
  if(cents<=0) fail('Preço inválido para o tamanho da pizza.');
  return cents;
 };
 const normFractionMode=value=>{
  if(value==='proportional'||value==='proporcional'||value==='average') return 'average';
  if(value==='fixed') return 'fixed';
  return 'max';
 };
 // Regra por produto com fallback para o modelo global antigo (pré-migration).
 // O fixo é por tamanho (product_size_prices); nível do produto serve de fallback legado.
 const globalFallback=settings.fraction_pricing_mode==='proportional'||settings.fraction_pricing_mode==='proporcional'||settings.fraction_pricing_mode==='average'?'average':'max';
 const productFractionConfig=(p,sizeId)=>{
  const raw=p?.fraction_pricing_mode;
  let mode=raw?normFractionMode(raw):globalFallback;
  let fixedCents=null;
  if(sizeId){
   const row=prices.find(v=>v.product_id===p?.id&&v.size_id===sizeId);
   if(row?.fraction_fixed_price!=null){
    const n=Number(row.fraction_fixed_price);
    if(Number.isFinite(n)&&n>0) fixedCents=money(n);
   }
  }
  if(fixedCents==null&&p?.fraction_fixed_price!=null){
   const n=Number(p.fraction_fixed_price);
   if(Number.isFinite(n)&&n>0) fixedCents=money(n);
  }
  if(mode==='fixed'&&fixedCents==null) mode='max';
  return {mode,fixedCents};
 };
 // parts: [{unit (cents), units (12-based), mode, fixedCents}]
 // Com parte fixa, a pizza é a SOMA das parcelas: fixa contribui
 // fixo×(fração/0,5) (½=fixo, ¼=metade do fixo); demais, proporcional.
 const priceFractionalPizzaCents=parts=>{
  if(parts.some(x=>x.mode==='fixed'&&x.fixedCents!=null))
   return parts.reduce((s,x)=>s+(x.mode==='fixed'&&x.fixedCents!=null?Math.round(x.fixedCents*x.units/6):Math.round(x.unit*x.units/12)),0);
  if(parts.some(x=>x.mode!=='average')) return Math.max(...parts.map(x=>x.unit));
  // média = soma proporcional
  return parts.reduce((s,x)=>s+Math.round(x.unit*x.units/12),0);
 };
 const fractionGroups=new Map();
 const offerCounts=new Map();
 const items=input.items.map(raw=>{
  const qty=quantity(raw.quantity);
  const observation=String(raw.observation||'').slice(0,500);
  if(raw.isOffer){
   const offer=offers.find(o=>o.id===raw.offerId&&o.active!==false)||fail('Oferta indisponível.');
   const count=(offerCounts.get(offer.id)||0)+qty; offerCounts.set(offer.id,count);
   if(offer.max_per_order && count>offer.max_per_order) fail('Limite da oferta excedido.');
   const selected=raw.offerGroups||[];
   if(selected.length!==offer.groups.length) fail('Seleção de combo inválida.');
   let extra=0;
   const groups=offer.groups.map(g=>{
    const chosen=selected.filter(v=>v.groupId===g.id);
    if(chosen.length!==1||chosen[0].items?.length!==g.quantity) fail('Quantidade do combo inválida.');
    return {groupId:g.id,groupName:g.name,quantity:g.quantity,items:chosen[0].items.map(v=>{
     const opt=g.offer_group_items.find(i=>i.product_id===v.product_id)||fail('Item fora do combo.');
     const p=product(opt.product_id);extra+=money(opt.extra_price);
     return {product_id:p.id,name:p.name,extra_price:Number(opt.extra_price)};
    })};
   });
   const unit=money(offer.price)+extra;
   return {productId:offer.id,productName:'🎁 '+offer.name,isOffer:true,offerId:offer.id,offerGroups:groups,quantity:qty,unitPrice:unit/100,itemTotal:unit*qty/100,observation};
  }
  const p=product(raw.productId);
  const size=raw.size?.id?sizes.find(s=>s.id===raw.size.id&&s.is_active!==false):null;
  if(p.is_pizza&&!size) fail('Selecione um tamanho válido para a pizza.');
  if(!p.is_pizza&&raw.size!=null) fail('Tamanho inválido para o produto.');
  const flavorIds=raw.flavorIds||[];
  if(!Array.isArray(flavorIds)||flavorIds.length>3||flavorIds.length>(size?.max_flavors||1)-1) fail('Sabores inválidos.');
  const flavors=flavorIds.map(id=>{const f=product(id);if(!f.is_pizza) fail('Sabor inválido.');return f;});
  // Pizza inteira combinada (legado): com parte fixa, soma as parcelas
  // (fixa: fixo×(quota/0,5); demais: preço×quota); senão, mais cara ou média.
  let unit;
  if(flavors.length){
   const allP=[p,...flavors];
   const cfgs=allP.map(q=>productFractionConfig(q,size?.id));
   const pricesCents=allP.map(f=>price(f,size));
   if(cfgs.some(c=>c.mode==='fixed'&&c.fixedCents!=null)){
    const share=1/allP.length;
    unit=cfgs.reduce((s,c,i)=>s+(c.mode==='fixed'&&c.fixedCents!=null?Math.round(c.fixedCents*share/0.5):Math.round(pricesCents[i]*share)),0);
   }
   else if(cfgs.every(c=>c.mode==='average')){
    const sumCents=pricesCents.reduce((s,v)=>s+v,0);
    unit=Math.round(sumCents/allP.length);
   } else unit=Math.max(...pricesCents);
  } else unit=price(p,size);
  const addon=(selection,kind)=>{
   if(!selection) return null;
   const a=addons.find(a=>a.id===selection.id);
   if(!a || !String(a.group_name).toLowerCase().match(kind==='crust'?/borda|crust/:/extra|adicional/)) fail('Adicional inválido.');
   unit+=money(a.price_diff);
   return {id:a.id,name:a.name,price:Number(a.price_diff)};
  };
  if(raw.crust&&!p.has_crusts) fail('Borda não permitida.');
  if(raw.extras?.length&&!p.has_extras) fail('Adicionais não permitidos.');
  if(!Array.isArray(raw.extras||[])||(raw.extras||[]).length>30||new Set((raw.extras||[]).map(x=>x.id)).size!==(raw.extras||[]).length) fail('Adicionais inválidos.');
   const crust=addon(raw.crust,'crust');
   // Extras: vínculo com a categoria do produto, quantidade (cumulativos),
   // exclusividade (não cumulativos) e limite de gratuitos por grupo (em unidades).
   const MAX_EXTRA_QTY=10;
   const groupState=new Map();
   const freeUnitsByGroup=new Map();
   const extras=(raw.extras||[]).map(sel=>{
    const e=addon(sel,'extra');
    const src=addons.find(a=>a.id===sel.id);
    const cats=src.group_category_ids||[];
    if(cats.length&&!cats.includes(p.category_id)) fail('Adicional inválido para este produto.');
    const qty=sel.quantity??1;
    if(!Number.isInteger(qty)||qty<1||qty>MAX_EXTRA_QTY) fail('Quantidade do adicional inválida.');
    const cumulative=src.cumulative??true;
    if(!cumulative&&qty>1) fail('Quantidade do adicional inválida.');
    const key=src.group_id||src.group_name;
    const st=groupState.get(key)||{distinct:0,exclusive:false};
    if(!cumulative){
     if(st.distinct>0) fail('Adicional exclusivo não combina com outros itens.');
     st.exclusive=true;
    }else if(st.exclusive) fail('Adicional exclusivo não combina com outros itens.');
    st.distinct+=1;
    groupState.set(key,st);
    const unitCents=money(src.price_diff);
    e.price=unitCents*qty/100;
    e.quantity=qty;
    if(qty>1) unit+=unitCents*(qty-1);
    const max=src.group_max_free;
    if(max!==null&&max!==undefined&&unitCents===0){
     const cur=(freeUnitsByGroup.get(key)||0)+qty;
     if(cur>max) fail('Limite de itens gratuitos excedido.');
     freeUnitsByGroup.set(key,cur);
    }
    return e;
   });
  const fraction=raw.fractionValue===undefined?1:raw.fractionValue;
  if(typeof fraction!=='number'||![1,0.5,1/3,0.25].includes(fraction)) fail('Fração inválida.');
  const denominator=Math.round(1/fraction);
  if(![1,2,3,4].includes(denominator)||Math.abs(1/denominator-fraction)>0.00001) fail('Fração inválida.');
  if(denominator>1&&(!p.is_pizza||!size||denominator>size.max_flavors||flavors.length)) fail('Fração não permitida.');
  const label=denominator===1?'':`1/${denominator} `;
  const item={productId:p.id,productName:label+[p.name,...flavors.map(f=>f.name)].join(' + ')+(size?' ['+size.name+']':''),productCodigo:p.codigo,
   size:size?{id:size.id,name:size.name}:null,flavorIds,quantity:qty,fractionValue:fraction,unitPrice:unit/100,crust,extras,observation,itemTotal:Math.round(unit*qty*fraction)/100};
  if(denominator>1){
   const cfg=productFractionConfig(p,size?.id);
   const entries=fractionGroups.get(size.id)||[];
   for(let i=0;i<qty;i++) entries.push({item,unit,units:12/denominator,mode:cfg.mode,fixedCents:cfg.fixedCents});
   fractionGroups.set(size.id,entries);
  }
  return item;
 });
 for(const entries of fractionGroups.values()){
  if(entries.reduce((s,e)=>s+e.units,0)%12!==0) fail('Complete as pizzas fracionadas.');
  entries.forEach(e=>e.item.itemTotal=0);
  const remaining=entries.slice().sort((a,b)=>b.unit-a.unit);
  while(remaining.length){
   let units=0;const pizza=[];
   while(units<12){
    const index=remaining.findIndex(e=>e.units<=12-units);
    if(index<0) fail('Combinação de frações inválida.');
    const [part]=remaining.splice(index,1);pizza.push(part);units+=part.units;
   }
   // Regra da pizza: fixo > mais cara > média (por produto)
   const whole=priceFractionalPizzaCents(pizza);
   let assigned=0;
   pizza.forEach((e,i)=>{const cents=i===pizza.length-1?whole-assigned:Math.round(whole*e.units/12);assigned+=cents;e.item.itemTotal+=cents/100;});
  }
 }
 const subtotal=items.reduce((s,i)=>s+money(i.itemTotal),0);
 const type=input.orderType;
 if(!['pickup','delivery'].includes(type)) fail('Tipo de pedido inválido.');
 if(settings[type==='pickup'?'allow_pickup':'allow_delivery']===false) fail('Modalidade indisponível.');
  let fee=0; let feePending=false;
  if(type==='delivery'){
   if(!input.deliveryAddress?.street||!input.deliveryAddress?.number||!input.deliveryAddress?.neighborhood) fail('Endereço incompleto.');
   const byStore=!!(store.settings && store.settings.delivery_fee_by_store);
   const active=neighborhoods.filter(n=>n.is_active!==false);
   if(byStore){
    // Taxa definida pela loja: pedido sem valor de taxa (servidor é autoritativo)
    feePending=true; fee=0;
   } else if(active.length>1){
    const chosen=active.find(n=>n.id===input.neighborhoodId);
    fee=money(chosen?.delivery_fee ?? chosen?.fee ?? fail('Selecione o bairro.'));
   } else fee=money(store.default_delivery_fee||0);
  }
 const minimum=settings[type==='delivery'?'min_order_delivery':'min_order_pickup']??(type==='delivery'?store.min_order_value:0);
 if(subtotal<money(minimum||0)) fail('Pedido abaixo do valor mínimo.');
 const method=input.payment?.method;
 if(!['pix','card','cash'].includes(method)||settings['accept_'+method]===false) fail('Pagamento indisponível.');
 if(!Number.isFinite(subtotal+fee)||subtotal<0||fee<0) fail('Preço inválido no catálogo.');
 const name=String(input.customer?.name||'').trim();const phone=String(input.customer?.phone||'').replace(/\D/g,'');
 if(name.length<2||name.length>120||phone.length<10||phone.length>15) fail('Dados do cliente inválidos.');
  return {storeId:store.id,storeName:store.name,storePhone:store.phone,orderType:type,customer:{name,phone},deliveryAddress:type==='delivery'?input.deliveryAddress:null,
   payment:{method,cashChange:method==='cash'?Number(input.payment.cashChange)||null:null},items,subtotal:subtotal/100,deliveryFee:fee/100,deliveryFeePending:feePending,total:(subtotal+fee)/100,notes:String(input.notes||'').slice(0,1000)};
}

Deno.serve(async req=>{
 if(req.method==='OPTIONS') return new Response('ok',{headers:cors});
 if(req.method!=='POST') return response({error:'POST required'},405);
 try {
  const text=await req.text();if(text.length>50000) return response({error:'Pedido muito grande.'},413);
  const {store_id,request_id,order}=JSON.parse(text);
  if(!/^[a-f0-9-]{36}$/i.test(store_id||'')||!/^[a-f0-9-]{36}$/i.test(request_id||'')) return response({error:'Pedido inválido.'},400);
  const db=createClient(required('SUPABASE_URL'),required('SUPABASE_SERVICE_ROLE_KEY'));
  const {data:eligibility,error:eligibilityError}=await db.rpc('public_store_status',{p_store_id:store_id});
  if(eligibilityError) return response({error:'Não foi possível verificar a disponibilidade da loja.'},503);
  if(!['trial','active'].includes(eligibility)) return response({error:'Loja temporariamente indisponível.'},403);
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
   const groupIds=groups.map((g:any)=>g.id);
   const {data:links,error:linkError}=groupIds.length?await db.from('addon_group_categories').select('group_id,category_id').in('group_id',groupIds):{data:[],error:null};
   if(linkError) throw new Error('Não foi possível carregar o catálogo.');
   const catsByGroup=new Map<string,string[]>();
   for(const l of (links||[]) as any[]){
    const arr=catsByGroup.get(l.group_id)||[];
    arr.push(l.category_id);
    catsByGroup.set(l.group_id,arr);
   }
   const snapshot=priceOrder(order,{store,settings:settings||{},products,sizes,prices,neighborhoods,offers:activeOffers,addons:groups.flatMap((g:any)=>g.addon_options.map((a:any)=>({...a,group_id:g.id,group_name:g.name,group_max_free:g.max_free ?? null,group_category_ids:catsByGroup.get(g.id)||[],cumulative:a.cumulative ?? true})))});

  if(Math.abs(snapshot.total-Number(order.total))>0.01) return response({error:'Os preços mudaram. Atualize o cardápio e confira a sacola.'},409);
  const {data,error:saveError}=await db.rpc('place_verified_order',{p_store_id:store_id,p_request_id:request_id,p_snapshot:snapshot});
  if(saveError) throw new Error('Não foi possível registrar o pedido. Aguarde e tente novamente.');
  return response({order:data});
 } catch(error){return response({error:error instanceof Error?error.message:'Não foi possível registrar o pedido.'},400);}
});
