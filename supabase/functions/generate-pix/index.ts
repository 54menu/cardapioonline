import {createClient} from 'https://esm.sh/@supabase/supabase-js@2.112.4';
import {cors,response,required} from '../_shared/http.ts';
Deno.serve(async req=>{
 if(req.method==='OPTIONS') return new Response('ok',{headers:cors});
 if(req.method!=='POST') return response({error:'POST required'},405);
 try {
  const url=required('SUPABASE_URL');
  const authorization=req.headers.get('Authorization')||'';
  const client=createClient(url,required('SUPABASE_ANON_KEY'),{global:{headers:{Authorization:authorization}}});
  const {data:{user},error:authError}=await client.auth.getUser();
  if(authError||!user) return response({error:'Entre na sua conta para gerar o PIX.'},401);
  const {store_id,amount}=await req.json();
  if(![19,114].includes(Number(amount))) return response({error:'Plano inválido.'},400);
  const {data:store,error:storeError}=await client.from('stores').select('id,name,owner_id').eq('id',store_id).single();
  if(storeError||store?.owner_id!==user.id) return response({error:'Loja não autorizada.'},403);
  const mpToken=required('MP_ACCESS_TOKEN');
  required('MP_WEBHOOK_SECRET');
  const {error:ensureError}=await client.rpc('ensure_subscription',{p_store_id:store_id});
  if(ensureError) throw ensureError;
  const db=createClient(url,required('SUPABASE_SERVICE_ROLE_KEY'));
  const {data:invoice,error}=await db.rpc('prepare_billing',{p_store_id:store_id,p_amount:Number(amount)});
  if(error) return response({error:error.message},409);
  if(invoice.mp_payment_id?.startsWith('mock_')) return response({error:'Esta fatura antiga é de teste. Contate o suporte para conciliá-la antes de pagar.'},409);
  if(invoice.mp_payment_id && invoice.pix_copy_paste) return response({...invoice,ok:true});
  const mpResponse=await fetch('https://api.mercadopago.com/v1/payments',{
   method:'POST',headers:{Authorization:'Bearer '+mpToken,'Content-Type':'application/json','X-Idempotency-Key':invoice.id},
   body:JSON.stringify({transaction_amount:Number(invoice.amount),description:store.name+' - Assinatura '+invoice.competence,
    payment_method_id:'pix',external_reference:store_id,notification_url:url+'/functions/v1/webhook-mercadopago',
    payer:{email:user.email},date_of_expiration:invoice.grace_until})
  });
  if(!mpResponse.ok) throw new Error('Payment provider rejected the request');
  const mp=await mpResponse.json();
  const transaction=mp.point_of_interaction?.transaction_data;
  if(!mp.id||!transaction?.qr_code) throw new Error('Invalid payment provider response');
  const updates={mp_payment_id:String(mp.id),pix_copy_paste:transaction.qr_code,pix_qr:transaction.qr_code_base64?'data:image/png;base64,'+transaction.qr_code_base64:''};
  const {error:saveError}=await db.from('payments').update(updates).eq('id',invoice.id);
  if(saveError) throw saveError;
  const {error:subError}=await db.from('subscriptions').update(updates).eq('store_id',store_id);
  if(subError) throw subError;
  return response({ok:true,...updates,due_date:invoice.due_date,expires_at:invoice.grace_until});
 }catch(error){console.error('generate-pix failed',error instanceof Error?error.message:'unknown');return response({error:'Não foi possível gerar o PIX. Tente novamente ou contate o suporte.'},503);}
});
