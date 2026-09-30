import test from 'node:test';import assert from 'node:assert/strict';import {JSDOM} from 'jsdom';import fs from 'node:fs';
test('catalog, pizza modal and checkout render with the new safe HTML boundary',async()=>{
 const dom=new JSDOM(fs.readFileSync('index.html','utf8'),{url:'http://localhost/?store=test',runScripts:'outside-only'});const w=dom.window;
 const store={id:'store',name:'Loja',status:'open',phone:'5585999999999',default_delivery_fee:7,neighborhoods:[]};
 const pizza={id:'pizza',name:'Pizza <img src=x onerror=alert(1)>',price:40,base_price:40,category_id:'cat',is_pizza:true,has_crusts:true,has_extras:true,available:true};
 w.storage={storeId:'store',getStore:()=>store,getCategories:()=>[{id:'cat',name:'Pizzas'}],getProducts:()=>[pizza],getAddonGroups:()=>({}),getSettings:()=>({}),getPizzaSizes:()=>[{id:'g',name:'Grande',max_flavors:2,is_active:true}],getProductSizePrices:()=>[{product_id:'pizza',size_id:'g',price:40}],getNeighborhoods:()=>[],getCustomerProfile:()=>({token:'t',name:'Teste',phone:'85999999999',addresses:[]}),getOrders:()=>[],getLastOrder:()=>null};
 for(const file of ['js/vendor/purify.min.js','js/lib/safe-html.js','js/lib/schedule.js','js/state/store.js','js/services/customer.js','js/services/order.js','js/services/whatsapp.js','js/components/productCard.js','js/components/productModal.js','js/components/checkoutModal.js','js/components/cartDrawer.js'])w.eval(fs.readFileSync(file,'utf8'));
 await w.appState.ready();await w.appState.refreshData();
 w.renderProductSections(w.document.getElementById('menuContainer'));
 const modal=w.setupProductModal();modal.openModal(pizza);
 assert.ok(w.document.querySelector('#btnConfirmAddToCart'));assert.equal(w.document.querySelectorAll('[onerror]').length,0);
 w.document.querySelector('#btnConfirmAddToCart').click();
 assert.equal(w.appState.cart.items.length,1);assert.equal(w.appState.cart.items[0].size.id,'g');
 w.appState.setOrderType('pickup');w.setupCheckoutModal().openCheckout();
 assert.ok(w.document.querySelector('#btnSubmitOrderToWhatsApp'));
 dom.window.close();
});
