import {createClient} from 'https://esm.sh/@supabase/supabase-js@2.112.4';
import {response,required} from '../_shared/http.ts';
import {verifySignature} from '../_shared/signature.js';
Deno.serve(async req=>{
 if(req.method!=='POST') return response({error:'POST required'},405);
 try {
  const id=new URL(req.url).searchParams.get('data.id');
  const secret=required('MP_WEBHOOK_SECRET');
  if(!id||!/^\d+$/.test(id)||!await verifySignature(secret,id,req.headers.get('x-request-id'),req.headers.get('x-signature'))) return response({error:'Invalid signature'},401);
  const mpResponse=await fetch('https://api.mercadopago.com/v1/payments/'+id,{headers:{Authorization:'Bearer '+required('MP_ACCESS_TOKEN')}});
  if(!mpResponse.ok) return response({error:'Provider temporarily unavailable'},502);
  const payment=await mpResponse.json();
  if(String(payment.id)!==id||payment.currency_id!=='BRL'||!payment.external_reference||![29,174].includes(Number(payment.transaction_amount))) return response({error:'Payment mismatch'},422);
  const db=createClient(required('SUPABASE_URL'),required('SUPABASE_SERVICE_ROLE_KEY'));
  const {error}=await db.rpc('apply_verified_payment',{p_payment_id:id,p_store_id:payment.external_reference,p_amount:Number(payment.transaction_amount),p_status:payment.status});
  if(error) throw error;
  return response({received:true});
 }catch(error){console.error('webhook failed',error instanceof Error?error.message:'unknown');return response({error:'Notification not processed; retry required'},503);}
});
