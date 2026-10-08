// Administrative input: empty is not offered; malformed input is never deletion.
export function validateProductPrices(isPizza,available,fields){
 const errors={};const prices=[];
 if(!isPizza)return {errors,prices};
 for(const f of fields){
  const raw=f.value;const text=typeof raw==='string'?raw.trim():raw;
  if(text==='')continue;
  let value=NaN;
  if(typeof text==='number')value=text;
  else if(typeof text==='string'&&/^(?:\d+|\d{1,3}(?:\.\d{3})+)(?:,\d{1,2})?$/.test(text))value=Number(text.replace(/\./g,'').replace(',','.'));
  if(!Number.isFinite(value)||value<=0||value>99999999.99||Math.abs(value*100-Math.round(value*100))>0.00001){errors[f.id]='Informe um preço válido maior que zero, com até duas casas decimais.';continue;}
  prices.push({size_id:f.id,price:value});
 }
 if(available&&!prices.some(p=>fields.some(f=>f.id===p.size_id&&f.active===true)))errors._sizes='Pizza disponível precisa de pelo menos um tamanho ativo com preço válido.';
 return {errors,prices};
}
