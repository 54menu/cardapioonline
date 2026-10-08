// A pizza offers only active sizes with a valid persisted association.
window.pizzaCatalog={
 sizes(product){
  const sizes=window.appState?.pizzaSizes||window.storage?.getPizzaSizes?.()||[];
  const prices=window.appState?.productSizePrices||window.storage?.getProductSizePrices?.(product.id)||[];
  return sizes.filter(s=>s.is_active!==false).sort((a,b)=>(a.display_order||0)-(b.display_order||0)).flatMap(s=>{
   const row=prices.find(p=>p.product_id===product.id&&p.size_id===s.id);
   return row&&typeof row.price==='number'&&Number.isFinite(row.price)&&row.price>0?[{size:s,price:row.price}]:[];
  });
 }
};
function getDisplayPrice(product){
 if(!product.is_pizza)return Number(product.price||0);
 const rows=window.pizzaCatalog.sizes(product);return rows.length?Math.min(...rows.map(r=>r.price)):null;
}
function getSizePrices(product){return product.is_pizza?window.pizzaCatalog.sizes(product):[];}
function renderProductSections(container, searchQuery = '', onSelectProduct) {
  // compat: searchQuery pode ser string ou objeto {query, sizeId, priceRange}
  let filter = { query: '', sizeId: '', priceRange: '' };
  if (typeof searchQuery === 'string') filter.query = searchQuery;
  else if (searchQuery && typeof searchQuery === 'object') filter = { query: searchQuery.query||'', sizeId: searchQuery.sizeId||'', priceRange: searchQuery.priceRange||'' };
  const categories = (window.appState.categories || []).slice().sort((a, b) => (a.order || 0) - (b.order || 0));
  const products = (window.appState.products || []).filter(p => p.available !== false).slice().sort((a,b)=> (a.codigo||9999)-(b.codigo||9999) || (a.order||0)-(b.order||0));
  const cs = window.customerService;

  let filteredProducts = products;
  if (filter.query) {
    const q = filter.query.toLowerCase();
    filteredProducts = filteredProducts.filter(p => 
      p.name.toLowerCase().includes(q) ||
      (p.description && p.description.toLowerCase().includes(q)) ||
      String(p.codigo||'').includes(q)
    );
  }
  if (filter.sizeId) {
    filteredProducts = filteredProducts.filter(p => {
      if (!p.is_pizza) return false;
      const allPrices = window.appState?.productSizePrices || [];
      return getSizePrices(p).some(pr=>pr.size.id===filter.sizeId);
    });
  }
  if (filter.priceRange) {
    const [minStr, maxStr] = filter.priceRange.split('-');
    const min = Number(minStr||0), max = Number(maxStr||9999);
    filteredProducts = filteredProducts.filter(p => {
      if (p.is_pizza) {
        const allPrices = window.appState?.productSizePrices || [];
        const myPrices = getSizePrices(p).map(r=>({size_id:r.size.id,price:r.price}));
        if (filter.sizeId) {
          const found = myPrices.find(pr=> pr.size_id===filter.sizeId);
          if (!found) return false;
          const price = Number(found.price);
          return price >= min && price <= max;
        } else {
          // sem tamanho selecionado: verifica se ALGUM tamanho está na faixa
          if (myPrices.length) return myPrices.some(pr=> { const v=Number(pr.price); return v>=min && v<=max; });
          const price = getDisplayPrice(p);
          return price !== null && price >= min && price <= max;
        }
      } else {
        const price = getDisplayPrice(p);
        return price >= min && price <= max;
      }
    });
  }

  if (filteredProducts.length === 0) {
    container.innerHTML = window.safeHTML(`
      <div style="text-align: center; padding: 4rem 1rem; color: var(--text-muted);">
        <div style="font-size: 2.5rem; margin-bottom: 0.75rem;">🔍</div>
        <p style="font-size: 1.1rem; font-weight: 600; color: var(--text-secondary);">Nenhum produto encontrado para "${searchQuery}"</p>
        <p style="font-size: 0.9rem; margin-top: 0.25rem;">Tente buscar por outro termo ou navegue pelas categorias acima.</p>
      </div>
    `);
    return;
  }

  const sectionsHtml = categories.map(cat => {
    const catProducts = filteredProducts.filter(p => p.category_id === cat.id);
    if (catProducts.length === 0) return '';

    return `
      <section class="category-section" id="section_${cat.id}">
        <h2 class="category-section-title">${cat.name}</h2>
        <div class="products-grid">
          ${catProducts.map(product => `
            <div class="product-card" data-product-id="${product.id}">
              <div class="product-card-body">
                <div>
                  <h3 class="product-title">${product.codigo ? `<span style="color:var(--primary); font-weight:800;">#${String(product.codigo).padStart(3,'0')}</span> ` : ''}${product.name}</h3>
                  <p class="product-description">${product.description || ''}</p>
                </div>
                <div class="product-price-bar">
                  <div style="flex:1;">
                    ${(()=>{
                      const sps=getSizePrices(product);
                      if(sps.length){
                        return `<div style="display:flex; gap:0.35rem; flex-wrap:wrap; align-items:center;">${sps.map(sp=>`<span style="font-size:0.78rem; font-weight:700; white-space:nowrap;">${sp.size.name.split('(')[0].trim()} ${cs?cs.formatCurrency(sp.price):'R$ '+sp.price}</span>`).join('<span style="color:var(--text-muted); font-size:0.7rem;">•</span>')}</div>`;
                      } else {
                        return `<span class="product-price">${getDisplayPrice(product)===null?'Indisponível — preço não configurado':cs ? cs.formatCurrency(getDisplayPrice(product)) : 'R$ ' + getDisplayPrice(product)}</span>`;
                      }
                    })()}
                  </div>
                </div>
              </div>
              ${product.image ? `<div class="product-image-container"><img src="${product.image}" alt="${product.name}" class="product-image" loading="lazy" /></div>` : ''}
            </div>
          `).join('')}
        </div>
      </section>
    `;
  }).join('');

  container.innerHTML = window.safeHTML(sectionsHtml);

  // Bind click nos cards de produto
  container.querySelectorAll('.product-card').forEach(card => {
    card.addEventListener('click', () => {
      const productId = card.dataset.productId;
      const product = window.appState.products.find(p => p.id === productId);
      if (product && (!product.is_pizza||getSizePrices(product).length) && onSelectProduct) {
        onSelectProduct(product);
      }
    });
  });
}

window.renderProductSections = renderProductSections;
