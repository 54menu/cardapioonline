# Banco e funções

O esquema antigo da raiz não representa a produção atual. Não o reaplique.

## Migrações de segurança

As migrações em `migrations/` são ordenadas por nome e devem ser aplicadas uma única vez. As cinco migrações de 30/09/2026 foram preparadas para aplicação em uma única transação. O registro da aplicação fica em `private.schema_versions`. Não repetir a primeira migração em um banco já atualizado: ela substitui as políticas antigas.

Para validar uma atualização na estrutura existente, envolva os corpos das migrações e `tests/security.sql` em `BEGIN`/`ROLLBACK`. O teste insere apenas fixtures transacionais; não chama serviços externos. Não execute o arquivo de teste sem transação e rollback.

`baseline.sql` é uma captura estrutural sem dados destinada a um projeto Supabase vazio. Para reconstrução, aplicar baseline e migrações na mesma transação, na ordem. Nunca aplicar baseline na produção existente. Não representa backup de dados, usuários, arquivos do Storage ou configurações de Auth.

## Funções

- `generate-pix`: exige usuário autenticado e propriedade da loja; novas cobranças: 19 ou 114; confirmação de cobranças antigas preservada (29 ou 174). O valor é validado no servidor. A chave de idempotência é o identificador estável da fatura.
- `webhook-mercadopago`: entrada pública com HMAC obrigatório e conferência na API Mercado Pago. Requer `MP_WEBHOOK_SECRET` e `MP_ACCESS_TOKEN` nos segredos do Supabase. Não colocar esses valores em arquivos ou no GitHub.
- `create-order`: aceita pedidos de visitantes, recalcula preços usando o catálogo e grava por uma função SQL disponível apenas para service_role. Repetições do mesmo request_id retornam o mesmo pedido.

O gateway usa `verify_jwt=false`, conforme `config.toml`. Isso não torna a geração de PIX anônima: `generate-pix` valida o token diretamente com `auth.getUser()` e confere a propriedade da loja antes de usar privilégios elevados, preservando compatibilidade com as chaves assimétricas do Supabase. O webhook autentica a assinatura do provedor. `create-order` permite visitantes e valida catálogo, valores e estado da loja. Funções compartilhadas ficam em `functions/_shared/`.

## Renovação

O job `zapmenu-subscription-cycle` no pg_cron roda diariamente às 03:10 UTC (00:10 em Fortaleza). Move assinaturas vencidas para carência, disponibiliza avisos no painel e bloqueia após o fim da carência de cinco dias a partir do vencimento, preservando o dia 06 quando o vencimento é dia 01.

O PIX é gerado quando o proprietário solicita no painel. Não há envio automático de email ou WhatsApp. O antigo workflow GitHub que apenas imprimia instruções foi convertido em uma consulta manual informativa, sem agendamento duplicado.

Faturas antigas com identificador `mock_` não são reutilizadas para pagamento. Exigem conciliação manual, sem transformar registros simulados em pagamentos reais. Não houve conciliação nem estorno automático de dados históricos.

## Referências

A validação de assinatura segue o [formato de Webhooks do Mercado Pago](https://www.mercadopago.com.br/developers/pt/docs/wallet-connect/notifications). Reentregas são tratadas de forma idempotente no banco.

A autenticação interna considera a [compatibilidade das novas chaves do Supabase](https://supabase.com/docs/guides/getting-started/migrating-to-new-api-keys).

## Verificação em produção — 02/10/2026

Aplicada a migração `20261002125932_secure_views_and_function_grants.sql`: as três views usam `security_invoker`; pedidos recentes exigem autenticação e respeitam as políticas da loja. Revogado acesso anônimo às funções internas de assinatura e administração. A definição inicial do banco agora inclui as views. Dependência Supabase fixada em 2.112.4.

Validação: testes locais e build aprovados; testes SQL executados com rollback; catálogo e views públicas retornam 200; pedidos, perfis, assinaturas, convites e view de pedidos rejeitam acesso anônimo (401). Webhook rejeita chamada sem assinatura (401). Dados preservados: 5 lojas, 266 produtos, 16 pedidos. Rotina de assinaturas executou com sucesso em 01 e 02/10.

O verificador do Supabase retorna zero ERROR e sete WARN: seis relativos a funções SECURITY DEFINER deliberadamente acessíveis, com autorização interna ou retorno público limitado; um sobre proteção contra senhas vazadas desativada. Essa configuração de Auth permanece pendente. Não foi efetuado pagamento real: a confirmação ponta a ponta de um PIX legítimo ainda requer uma transação controlada. Pagamentos legados simulados não foram tratados como pagamentos reais.
