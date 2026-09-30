export const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
export function response(value: unknown, status=200) { return new Response(JSON.stringify(value), {status,headers:{...cors,'Content-Type':'application/json'}}); }
export function required(name:string) { const value=Deno.env.get(name); if(!value) throw new Error('Service configuration missing'); return value; }
