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
 const mode=settings.fraction_pricing_mode==='proportional'?'proportional':'max';
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
  let unit=Math.max(price(p,size),...flavors.map(f=>price(f,size)));
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
  const crust=addon(raw.crust,'crust');const extras=(raw.extras||[]).map(a=>addon(a,'extra'));
  const fraction=raw.fractionValue===undefined?1:raw.fractionValue;
  if(typeof fraction!=='number'||![1,0.5,1/3,0.25].includes(fraction)) fail('Fração inválida.');
  const denominator=Math.round(1/fraction);
  if(![1,2,3,4].includes(denominator)||Math.abs(1/denominator-fraction)>0.00001) fail('Fração inválida.');
  if(denominator>1&&(!p.is_pizza||!size||denominator>size.max_flavors||flavors.length)) fail('Fração não permitida.');
  const label=denominator===1?'':`1/${denominator} `;
  const item={productId:p.id,productName:label+[p.name,...flavors.map(f=>f.name)].join(' + ')+(size?' ['+size.name+']':''),productCodigo:p.codigo,
   size:size?{id:size.id,name:size.name}:null,flavorIds,quantity:qty,fractionValue:fraction,unitPrice:unit/100,crust,extras,observation,itemTotal:Math.round(unit*qty*fraction)/100};
  if(denominator>1){
   const entries=fractionGroups.get(size.id)||[];
   for(let i=0;i<qty;i++) entries.push({item,unit,units:12/denominator});
   fractionGroups.set(size.id,entries);
  }
  return item;
 });
 for(const entries of fractionGroups.values()){
  if(entries.reduce((s,e)=>s+e.units,0)%12!==0) fail('Complete as pizzas fracionadas.');
  if(mode==='proportional') continue;
  entries.forEach(e=>e.item.itemTotal=0);
  const remaining=entries.slice().sort((a,b)=>b.unit-a.unit);
  while(remaining.length){
   let units=0;const pizza=[];
   while(units<12){
    const index=remaining.findIndex(e=>e.units<=12-units);
    if(index<0) fail('Combinação de frações inválida.');
    const [part]=remaining.splice(index,1);pizza.push(part);units+=part.units;
   }
   const highest=Math.max(...pizza.map(e=>e.unit));let assigned=0;
   pizza.forEach((e,i)=>{const cents=i===pizza.length-1?highest-assigned:Math.round(highest*e.units/12);assigned+=cents;e.item.itemTotal+=cents/100;});
  }
 }
 const subtotal=items.reduce((s,i)=>s+money(i.itemTotal),0);
 const type=input.orderType;
 if(!['pickup','delivery'].includes(type)) fail('Tipo de pedido inválido.');
 if(settings[type==='pickup'?'allow_pickup':'allow_delivery']===false) fail('Modalidade indisponível.');
 let fee=0;
 if(type==='delivery'){
  if(!input.deliveryAddress?.street||!input.deliveryAddress?.number||!input.deliveryAddress?.neighborhood) fail('Endereço incompleto.');
  const active=neighborhoods.filter(n=>n.is_active!==false);
  fee=active.length>1?money(active.find(n=>n.id===input.neighborhoodId)?.delivery_fee??fail('Selecione o bairro.')):money(store.default_delivery_fee||0);
 }
 const minimum=settings[type==='delivery'?'min_order_delivery':'min_order_pickup']??(type==='delivery'?store.min_order_value:0);
 if(subtotal<money(minimum||0)) fail('Pedido abaixo do valor mínimo.');
 const method=input.payment?.method;
 if(!['pix','card','cash'].includes(method)||settings['accept_'+method]===false) fail('Pagamento indisponível.');
 if(!Number.isFinite(subtotal+fee)||subtotal<0||fee<0) fail('Preço inválido no catálogo.');
 const name=String(input.customer?.name||'').trim();const phone=String(input.customer?.phone||'').replace(/\D/g,'');
 if(name.length<2||name.length>120||phone.length<10||phone.length>15) fail('Dados do cliente inválidos.');
 return {storeId:store.id,storeName:store.name,storePhone:store.phone,orderType:type,customer:{name,phone},deliveryAddress:type==='delivery'?input.deliveryAddress:null,
  payment:{method,cashChange:method==='cash'?Number(input.payment.cashChange)||null:null},items,subtotal:subtotal/100,deliveryFee:fee/100,total:(subtotal+fee)/100,notes:String(input.notes||'').slice(0,1000)};
}
