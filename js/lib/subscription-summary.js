export function subscriptionSummary(sub, now=new Date()) {
 if (!sub) return {tone:'neutral',title:'Assinatura não disponível',detail:'Consulte a aba Assinatura'};
 if (sub.status==='canceled') return {tone:'danger',title:'Plano cancelado',detail:'Consulte a aba Assinatura'};
 const due=sub.current_period_end;
 if (!due) return {tone:'neutral',title:'Assinatura sem vencimento',detail:'Consulte a aba Assinatura'};
 const today=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Fortaleza',year:'numeric',month:'2-digit',day:'2-digit'}).format(now);
 const days=Math.round((Date.parse(due+'T00:00:00Z')-Date.parse(today+'T00:00:00Z'))/86400000);
 const date=due.split('-').reverse().join('/');
 if (!Number.isFinite(days)) return {tone:'neutral',title:'Confira sua assinatura',detail:'Consulte a aba Assinatura'};
 if (sub.status==='blocked') return {tone:'danger',title:'Plano bloqueado',detail:days<0?'Vencido há '+(-days)+' dia'+(days===-1?'':'s'):'Regularize na aba Assinatura'};
 if (days<0) return {tone:'danger',title:sub.status==='trial'?'Período de teste encerrado':'Pagamento em atraso',detail:'Vencido há '+(-days)+' dia'+(days===-1?'':'s')+' · '+date};
 const trial=sub.status==='trial';
 return {tone:days<=5?'warning':'ok',title:trial?'Em período de teste':'Plano ativo',detail:days===0?(trial?'Teste termina hoje':'Vence hoje'):(trial?'Teste termina em ':'Vence em ')+days+' dia'+(days===1?'':'s')+' · '+date};
}
