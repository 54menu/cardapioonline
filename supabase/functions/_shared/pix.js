// Postgres timestamps need explicit ISO normalization for Mercado Pago (error 23).
export function formatPixExpiration(value) {
 const date=new Date(value);
 if(!Number.isFinite(date.getTime())) throw new Error('Invalid PIX expiration');
 return date.toISOString().replace('Z','+00:00');
}
