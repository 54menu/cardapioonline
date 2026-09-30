# ZapMenu — Cardápio Online + WhatsApp

Cardápio público e painel de gestão para lojas, com Supabase, pedidos enviados pelo cliente ao WhatsApp e cobrança de assinatura por PIX.

## Desenvolvimento

Requer Node.js 24.

```sh
npm ci
npm start
```

Abra `http://localhost:3000/index.html?store=SLUG_DA_LOJA` ou `http://localhost:3000/admin.html`.
O ambiente local usa o projeto Supabase configurado em `js/lib/supabase.js`; as operações autenticadas afetam esse projeto. Para desenvolvimento isolado, configure outro projeto Supabase.

## Verificação e publicação

```sh
npm test
npm run build
```

Os testes iniciam seu próprio servidor local e verificam endpoints, MIME, WhatsApp, preços, frações, combos, assinatura de webhook, sanitização, horários e integração do modal/checkout. Não criam pedidos nem cobranças em produção.

O GitHub Pages publica somente `dist/`, após `npm ci`, testes e build. SQL, relatórios, configurações e testes ficam fora do site. O repositório em si é público: não versionar credenciais ou dados de clientes.

## Estrutura

- `index.html`, `js/app-supabase.js`: cardápio público.
- `admin.html`, `js/admin-supabase.js`: painel de gestão.
- `js/components/`, `js/state/`, `js/services/`: apresentação, estado e pedido/WhatsApp.
- `js/vendor/`: DOMPurify distribuído localmente, com sua licença.
- `supabase/functions/`: geração de PIX, webhook e criação de pedidos com preços do servidor.
- `supabase/migrations/`: correções versionadas do banco.
- `tests/`: testes locais e validação SQL transacional.

Consulte [supabase/README.md](supabase/README.md) antes de modificar o banco, publicar funções ou configurar a renovação.

Abrir o WhatsApp não envia a mensagem automaticamente: o cliente confirma o envio no aplicativo. O pedido só sai do checkout após a confirmação de gravação no servidor.
