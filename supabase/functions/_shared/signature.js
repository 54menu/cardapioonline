export async function verifySignature(secret, dataId, requestId, signature) {
 if (!secret || !dataId || !requestId || !signature) return false;
 const parts=Object.fromEntries(signature.split(',').map(s=>s.trim().split('=')));
 if (!/^\d+$/.test(parts.ts||'') || !/^[a-f0-9]{64}$/i.test(parts.v1||'')) return false;
 const manifest='id:'+String(dataId).toLowerCase()+';request-id:'+requestId+';ts:'+parts.ts+';';
 const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['verify']);
 const bytes=Uint8Array.from(parts.v1.match(/../g),h=>parseInt(h,16));
 return crypto.subtle.verify('HMAC',key,bytes,new TextEncoder().encode(manifest));
}
