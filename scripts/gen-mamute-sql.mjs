// Gera supabase/operations/mamute-seed.sql a partir dos mesmos dados do seed-mamute.mjs
import fs from 'node:fs';
const q = (s) => `'${String(s).replace(/'/g, "''")}'`;
let codigo = 1, order = 1;
const rows = [];
const prod = (cat, name, desc, base, isPizza, avail, g, gg, hasExtras = isPizza) => rows.push({ cat, name, desc, base, isPizza, avail, g, gg, hasExtras, order: order++, codigo: codigo <= 999 ? codigo++ : null });
// --- copia fiel dos dados do seed-mamute.mjs ---
// Entradas — molhos como adicional (grupo "Adicionais Molhos"), não na descrição
prod('Entradas', 'Batata Frita', 'Porção de batata frita. Escolha 1 molho no adicional.', 15, false, true, null, null, true);
prod('Entradas', 'Batata Frita com Bacon e Molho', 'Porção de batata frita com bacon. Escolha 1 molho no adicional.', 20, false, true, null, null, true);
prod('Entradas', 'Batata Frita com Bacon e Calabresa e Molho', 'Porção de batata frita com bacon e calabresa. Escolha 1 molho no adicional.', 24, false, true, null, null, true);
prod('Entradas', 'Batata com Costela Desfiada e Molho', 'Porção de batata com costela desfiada. Escolha 1 molho no adicional.', 28, false, true, null, null, true);
prod('Entradas', 'Onion Rings 10 unidades', 'Porção de onion rings (10 unidades). Acompanha molho — escolha 1 no adicional.', 15, false, true, null, null, true);
prod('Entradas', 'Cebola Crispy com Calabresa e Bacon e Molho', 'Porção de cebola crispy com calabresa e bacon. Escolha 1 molho no adicional.', 24, false, true, null, null, true);
prod('Entradas', 'Cebola Crispy com Costela Desfiada e Molho', 'Porção de cebola crispy com costela desfiada. Escolha 1 molho no adicional.', 28, false, true, null, null, true);
const TRAD = [
  ['Mista', 'Molho, mussarela, frango, calabresa, milho, ervilha e orégano.'],
  ['Calabresa', 'Molho, mussarela, calabresa, cebola e orégano.'],
  ['Calabresa c/ Catupiry', 'Molho, mussarela, calabresa, catupiry, cebola e orégano.'],
  ['Bacon', 'Molho, mussarela, bacon, cebola e orégano.'],
  ['Frango', 'Molho, mussarela, frango, milho, ervilha e orégano.'],
  ['Frango c/ Catupiry', 'Molho, mussarela, frango, catupiry, milho, ervilha e orégano.'],
  ['Frango Crocante', 'Molho, mussarela, frango e batata palha.'],
  ['Portuguesa', 'Molho, mussarela, presunto, ovo, milho, ervilha, palmito e orégano.'],
  ['Presunto', 'Molho, mussarela, presunto, milho, ervilha e orégano.'],
  ['Moda do Chefe', 'Molho, mussarela, presunto, catupiry, milho, ervilha e orégano.'],
  ['Moda da Casa', 'Molho, mussarela, presunto, frango, calabresa, milho, ervilha, palmito e orégano.'],
  ['Mussarela', 'Molho, mussarela, tomate e orégano.'],
  ['Mussarela Crocante', 'Molho, mussarela e batata palha.'],
  ['Catupiry Crocante', 'Molho, mussarela, catupiry e batata palha.'],
  ['Quatro Queijos', 'Molho, mussarela, catupiry, cheddar, parmesão e orégano.'],
  ['Palmito', 'Molho, mussarela, palmito, cebola e orégano.'],
  ['Margarita', 'Molho, mussarela, manjericão, tomate e orégano.'],
  ['Vegetariana', 'Molho, mussarela, manjericão, tomate, pimentão, palmito, milho, ervilha e orégano.'],
];
for (const [n, d] of TRAD) prod('Pizzas Tradicionais', n, d, 35, true, true, 35, 40);
const ESP = [
  ['Calabacon', 'Molho, mussarela, calabresa, bacon, cebola e orégano.'],
  ['Calapalmito', 'Molho, mussarela, calabresa, palmito, cebola e orégano.'],
  ['Calabresa c/ Creme Cheese', 'Molho, mussarela, calabresa, creme cheese, cebola e orégano.'],
  ['Bacon c/ Palmito', 'Molho, mussarela, bacon, palmito, cebola e orégano.'],
  ['Bacon c/ Presunto', 'Molho, mussarela, bacon, presunto, cebola e orégano.'],
  ['Bacon c/ Creme Cheese', 'Molho, mussarela, bacon, creme cheese, cebola e orégano.'],
  ['Franbacon', 'Molho, mussarela, frango, bacon, cebola e orégano.'],
  ['Bacon c/ Ovos', 'Molho, mussarela, bacon, ovos, cebola e orégano.'],
  ['Bacon c/ Catupiry', 'Molho, mussarela, bacon, catupiry, cebola e orégano.'],
  ['Lombinho', 'Molho, mussarela, lombinho, milho, ervilha e orégano.'],
  ['Lombinho c/ Catupiry', 'Molho, mussarela, lombinho, catupiry, milho, ervilha e orégano.'],
  ['Frango c/ Creme Cheese', 'Molho, mussarela, frango, creme cheese, cebola e orégano.'],
  ['Moda do Pizzaiolo', 'Molho, mussarela, lombinho, bacon, catupiry, cebola e orégano.'],
  ['Moda do Gordo', 'Molho, mussarela, lombinho, calabresa, bacon, cheddar e orégano.'],
  ['Quatro Queijos c/ Bacon', 'Molho, mussarela, catupiry, parmesão, cheddar, bacon e orégano.'],
  ['Cinco Queijos c/ Creme Cheese', 'Molho, mussarela, catupiry, parmesão, cheddar e creme cheese.'],
  ['Maravilhosa', 'Molho, mussarela, peito de peru, manjericão e orégano.'],
  ['Peito de Peru', 'Molho, mussarela, peito de peru, milho, ervilha e orégano.'],
  ['Mexicana', 'Molho, mussarela, calabresa, pimenta calabresa, cebola e orégano.'],
];
for (const [n, d] of ESP) prod('Pizzas Especiais', n, d, 45, true, true, 45, 50);
const PRI65 = [
  ['Charque', 'Molho, mussarela, charque, cebola e orégano.'],
  ['Charque c/ Creme Cheese', 'Molho, mussarela, charque, cebola, orégano e creme cheese.'],
  ['Camarão Regional', 'Molho, mussarela, camarão regional, milho, ervilha e orégano.'],
  ['Camarão c/ Catupiry', 'Molho, mussarela, camarão, catupiry, cebola e orégano.'],
  ['Camarão c/ Creme Cheese', 'Molho, mussarela, camarão, creme cheese, milho, ervilha e orégano.'],
  ['Filé', 'Molho, mussarela, carne e orégano.'],
  ['Filé com Bacon', 'Molho, mussarela, carne, bacon, cebola e orégano.'],
  ['Filé com Creme Cheese', 'Molho, mussarela, carne, creme cheese e orégano.'],
  ['Carne de Sol', 'Molho, mussarela, carne de sol, cebola e orégano.'],
  ['Atum', 'Molho, mussarela, atum, milho, ervilha e orégano.'],
  ['Peruana', 'Molho, mussarela, atum, palmito, cebola e orégano.'],
  ['Costela Desfiada', 'Molho, mussarela, costela desfiada, cebola crispy e orégano.'],
  ['Costela Desfiada com Creme Cheese', 'Molho, mussarela, costela desfiada, creme cheese e orégano.'],
  ['Strogonoff de Carne', 'Molho, mussarela, strogonoff de carne e batata palha.'],
  ['Strogonoff de Frango', 'Molho, mussarela, strogonoff de frango e batata palha.'],
  ['Strogonoff de Camarão Regional', 'Molho, mussarela, strogonoff de camarão regional e batata palha.'],
];
for (const [n, d] of PRI65) prod('Pizzas Primes', n, d, 65, true, true, 65, 70);
prod('Pizzas Primes', 'Camarão Rosa', 'Molho, mussarela, camarão rosa e orégano.', 80, true, true, 80, 100);
prod('Pizzas Primes', 'Camarão Rosa c/ Catupiry', 'Molho branco, mussarela, camarão rosa e orégano.', 80, true, true, 80, 100);
prod('Pizzas Primes', 'Filé com Frita', 'Molho, mussarela, filé e batata frita.', 70, true, true, 70, 75);
prod('Pizzas Primes', 'Carne de Sol c/ Fritas', 'Molho, mussarela, carne de sol com fritas e orégano.', 70, true, true, 70, 75);
const DOC = [
  ['Brigadeiro', 'Brigadeiro com granulado.'],
  ['Chocolate', 'Chocolate com granulado.'],
  ['Chocolate Branco', 'Chocolate branco com granulado.'],
  ['Mix (Chocolate e Chocolate Branco)', 'Chocolate e chocolate branco.'],
  ['Doce de Leite', 'Doce de leite e MM.'],
  ['Banana', 'Molho, mussarela, banana, leite condensado e canela.'],
  ['Banana Nevada', 'Banana, chocolate branco e canela.'],
  ['Romeu e Julieta', 'Molho, mussarela, goiabada e creme de leite.'],
  ['Banoffee', 'Banana, doce de leite e canela.'],
];
for (const [n, d] of DOC) prod('Pizzas Doces', n, d, 35, true, true, 35, 40);
prod('Pizzas Nutella', 'Nutella', 'Chocolate Nutella.', 55, true, true, 55, 60);
prod('Pizzas Nutella', 'Banana com Nutella', 'Banana e Nutella.', 55, true, true, 55, 60);
prod('Pizzas Nutella', 'Nutella com Morango', 'Nutella e morango.', 55, true, true, 55, 60);
prod('Pizzas Nutella', 'Nutella com Uva', 'Nutella e uva.', 55, true, true, 55, 60);
prod('Lanches Tradicionais', '1 Burg Kid - R$ 13,00', 'Pão, carne e queijo.', 13, false, true, null, null);
prod('Lanches Tradicionais', '2 Burg Simples - R$ 15,00', 'Pão, carne, queijo, ovo, molho e salada.', 15, false, true, null, null);
prod('Lanches Tradicionais', '3 Burg Especial - R$ 18,00', 'Pão, carne, queijo, presunto, calabresa, ovo, molho e salada.', 18, false, true, null, null);
prod('Lanches Tradicionais', '4 Burg Hot - R$ 18,00', 'Pão, carne, queijo, presunto, salsicha hot, ovo, molho e salada.', 18, false, true, null, null);
prod('Lanches Tradicionais', '5 Burg Hot Cala - R$ 20,00', 'Pão, carne, queijo, presunto, calabresa, salsicha hot, ovo, molho e salada.', 20, false, true, null, null);
prod('Lanches Tradicionais', '6 Burg Calabresa - R$ 20,00', 'Pão, carne, queijo, presunto, calabresa, molho e salada.', 20, false, true, null, null);
prod('Lanches Tradicionais', '7 Burg Bacon - R$ 20,00', 'Pão, carne, queijo, presunto, bacon, molho e salada.', 20, false, true, null, null);
prod('Lanches Tradicionais', '8 Burg Calabacon - R$ 22,00', 'Pão, carne, queijo, presunto, calabresa, bacon, molho e salada.', 22, false, true, null, null);
prod('Lanches Tradicionais', '9 Burg Duplo - R$ 26,00', 'Pão, 2 carnes, 2 queijos, 2 presuntos, 2 ovos, molho e salada.', 26, false, true, null, null);
prod('Lanches Tradicionais', '10 Burg Tudo - R$ 28,00', 'Pão, carne, queijo, presunto, calabresa, bacon, salsicha hot, ovo, molho e salada.', 28, false, true, null, null);
prod('Lanches Tradicionais', '11 Queijo Quente', 'Pão de forma e queijo mussarela. (Preço a confirmar no balcão)', 0, false, false, null, null);
prod('Lanches Tradicionais', '12 Misto Quente', 'Pão de forma, queijo e presunto. (Preço a confirmar no balcão)', 0, false, false, null, null);
prod('Lanches Tradicionais', '13 Misto Duplo', 'Pão de forma, 2 queijos e 2 presuntos. (Preço a confirmar no balcão)', 0, false, false, null, null);
prod('Lanches Tradicionais', '14 Misto com Ovo', 'Pão de forma, queijo, presunto e ovo. (Preço a confirmar no balcão)', 0, false, false, null, null);
prod('Lanches Tradicionais', '15 Misto com Costela Desfiada', 'Pão de forma, queijo, costela desfiada e creme cheese. (Preço a confirmar no balcão)', 0, false, false, null, null);
prod('Lanches Artesanais', '16 Burg - R$ 16,00', 'Pão, carne 160g e queijo.', 16, false, true, null, null);
prod('Lanches Artesanais', '17 Burg - R$ 22,00', 'Pão, carne 160g, queijo, calabresa, molho da casa, salada e cebola crispy.', 22, false, true, null, null);
prod('Lanches Artesanais', '18 Burg - R$ 24,00', 'Pão, carne 160g, queijo, bacon, molho da casa, salada e cebola crispy.', 24, false, true, null, null);
prod('Lanches Artesanais', '19 Burg - R$ 24,00', 'Pão, carne 160g, queijo, catupiry empanado e molho da casa.', 24, false, true, null, null);
prod('Lanches Artesanais', '20 Burg - R$ 26,00', 'Pão, carne 160g, queijo, catupiry empanado, bacon e onion ring.', 26, false, true, null, null);
prod('Lanches Artesanais', '21 Burg - R$ 28,00', 'Pão, carne 160g, queijo, catupiry empanado, costela bovina desfiada, creme cheese e cebola crispy.', 28, false, true, null, null);
prod('Lanches Artesanais', '22 Burg - R$ 30,00', 'Pão, carne 160g, queijo, bacon, abacaxi chapeado, creme cheese e costela desfiada.', 30, false, true, null, null);
prod('Lanches Artesanais', '23 Burg - R$ 32,00', 'Pão, carne 160g, queijo, bacon, costela desfiada, mussarela empanada e molho.', 32, false, true, null, null);
prod('Lanches Artesanais', '24 Burg - R$ 32,00', 'Pão, 2 carnes 160g, queijo, bacon e calabresa.', 32, false, true, null, null);
prod('Lanches Artesanais', '25 Burg - R$ 36,00', 'Pão, carne 160g, queijo, bacon, calabresa, costela desfiada, onion ring e catupiry empanado.', 36, false, true, null, null);
prod('Lasanha', 'Lasanha de Camarão', 'Lasanha porção individual de camarão. Novidade!', 30, false, true, null, null);
prod('Lasanha', 'Lasanha de Carne', 'Lasanha porção individual de carne. Novidade!', 25, false, true, null, null);
prod('Lasanha', 'Lasanha de Frango', 'Lasanha porção individual de frango. Novidade!', 25, false, true, null, null);
prod('Lasanha', 'Lasanha Queijo e Presunto', 'Lasanha porção individual de queijo e presunto. Novidade!', 25, false, true, null, null);
prod('Combos', 'Combo Individual - R$ 26,00', '1 burg especial + 1 batata frita + 1 refrigerante lata.', 26, false, true, null, null);
prod('Combos', 'Combo Dobro - R$ 40,00', '2 burg especial + 1 batata frita + 1 refrigerante de 600ml.', 40, false, true, null, null);
prod('Combos', 'Combo Triplo - R$ 60,00', '3 burg especial + 1 batata frita + 1 refrigerante de 1 litro.', 60, false, true, null, null);
prod('Combos', 'Combo Quarto - R$ 75,00', '4 burg especial + 1 batata frita + 1 refrigerante de 1 litro.', 75, false, true, null, null);
prod('Combos', 'Combo Quinto - R$ 90,00', '5 burg especial + 1 batata frita com calabresa e molho + 1 refrigerante de 2 litros.', 90, false, true, null, null);
prod('Combos', 'Combo Sexto - R$ 110,00', '6 burg especial + 1 batata frita com calabresa e molho + 1 refrigerante de 2 litros.', 110, false, true, null, null);
prod('Bebidas', 'Refrigerante 1 Litro', 'Refrigerante 1 litro. (Preço a confirmar)', 0, false, false, null, null);
prod('Bebidas', 'Refrigerante 1,5 Litro', 'Refrigerante 1,5 litro. (Preço a confirmar)', 0, false, false, null, null);
prod('Bebidas', 'Refrigerante 2 Litros', 'Refrigerante 2 litros. (Preço a confirmar)', 0, false, false, null, null);
prod('Bebidas', 'Refrigerante Lata 350ml', 'Refrigerante lata 350ml. (Preço a confirmar)', 0, false, false, null, null);
prod('Bebidas', 'Suco 1 Litro', 'Suco 1 litro. (Preço a confirmar)', 0, false, false, null, null);
prod('Bebidas', 'Suco 400ml', 'Suco 400ml. (Preço a confirmar)', 0, false, false, null, null);
prod('Bebidas', 'Água Mineral 500ml', 'Água mineral 500ml. (Preço a confirmar)', 0, false, false, null, null);

const CATS = [
  ['Entradas', 1, 'Porções'],
  ['Pizzas Tradicionais', 2, 'G (8 fatias) R$ 35,00 / GG (12 fatias) R$ 40,00'],
  ['Pizzas Especiais', 3, 'G inteira R$ 45,00 / GG inteira R$ 50,00 (meia: G R$ 40,00 / GG R$ 45,00)'],
  ['Pizzas Primes', 4, 'G 8 fatias / GG 12 fatias — ver descrição'],
  ['Pizzas Doces', 5, 'G (8 fatias) R$ 35,00 / GG (12 fatias) R$ 40,00'],
  ['Pizzas Nutella', 6, 'G inteira R$ 55,00 / GG inteira R$ 60,00 (meia: G R$ 45,00 / GG R$ 50,00)'],
  ['Lanches Tradicionais', 7, null],
  ['Lanches Artesanais', 8, 'Carne 160g'],
  ['Lasanha', 9, 'Porção individual — Novidade!'],
  ['Combos', 10, null],
  ['Bebidas', 11, null],
];
const varn = (s) => 'v_' + s.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
let sql = `-- Seed Pizzaria Mamute (pizzaria-mamute) gerado em ${new Date().toISOString()}\n-- Loja: a5f88e35-f150-4c37-a7bd-2220e02ad2c8 | ${rows.length} produtos\n-- Rode no SQL Editor do Supabase (postgres, bypass RLS). Transacional.\nDO $$\nDECLARE\n  v_store uuid := 'a5f88e35-f150-4c37-a7bd-2220e02ad2c8';\n`;
for (const [n] of CATS) sql += `  ${varn(n)} uuid;\n`;
sql += `  v_g uuid; v_gg uuid; v_prod uuid; v_molho uuid;\nBEGIN\n`;
sql += `  DELETE FROM public.addon_group_categories WHERE group_id IN (SELECT id FROM public.addon_groups WHERE store_id=v_store);\n  DELETE FROM public.product_size_prices WHERE product_id IN (SELECT id FROM public.products WHERE store_id=v_store);\n  DELETE FROM public.products WHERE store_id=v_store;\n  DELETE FROM public.categories WHERE store_id=v_store;\n  DELETE FROM public.pizza_sizes WHERE store_id=v_store;\n  DELETE FROM public.addon_groups WHERE store_id=v_store;\n`;
for (const [n, o, l] of CATS) sql += `  INSERT INTO public.categories (store_id,name,display_order,is_active,price_label) VALUES (v_store,${q(n)},${o},true,${l ? q(l) : 'NULL'}) RETURNING id INTO ${varn(n)};\n`;
sql += `  INSERT INTO public.pizza_sizes (store_id,name,slices,max_flavors,display_order,is_active) VALUES (v_store,'G (8 fatias)',8,2,1,true) RETURNING id INTO v_g;\n  INSERT INTO public.pizza_sizes (store_id,name,slices,max_flavors,display_order,is_active) VALUES (v_store,'GG (12 fatias)',12,2,2,true) RETURNING id INTO v_gg;\n`;
sql += `  INSERT INTO public.addon_groups (store_id,name,title,type,required,applies_to,max_free,display_order) VALUES (v_store,'Adicional Molho (Entradas)','Escolha o molho','single',false,ARRAY['Entradas'],1,1) RETURNING id INTO v_molho;\n`;
sql += `  INSERT INTO public.addon_options (group_id,name,price_diff,allows_half_half,is_default,cumulative,display_order) VALUES (v_molho,'Molho da Casa',0,false,true,false,1),(v_molho,'Molho Cheddar',0,false,false,false,2),(v_molho,'Cream Cheese',0,false,false,false,3);\n`;
sql += `  INSERT INTO public.addon_group_categories (group_id,category_id) VALUES (v_molho,${varn('Entradas')});\n`;
for (const r of rows) {
  sql += `  INSERT INTO public.products (store_id,category_id,name,description,base_price,image_url,is_pizza,has_crusts,has_extras,available,display_order,codigo) VALUES (v_store,${varn(r.cat)},${q(r.name)},${q(r.desc)},${r.base},NULL,${r.isPizza},${r.isPizza},${r.hasExtras},${r.avail},${r.order},${r.codigo}) RETURNING id INTO v_prod;\n`;
  if (r.isPizza) {
    sql += `  INSERT INTO public.product_size_prices (product_id,size_id,price) VALUES (v_prod,v_g,${r.g}), (v_prod,v_gg,${r.gg});\n`;
  }
}
sql += `END $$;\n`;
fs.mkdirSync('supabase/operations/mamute', { recursive: true });
fs.writeFileSync('supabase/operations/mamute/seed.sql', sql);
console.log('SQL gravado com', rows.length, 'produtos');
