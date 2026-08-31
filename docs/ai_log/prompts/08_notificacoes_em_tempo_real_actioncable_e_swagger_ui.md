# Prompt 08: Notificações em Tempo Real com ActionCable e Documentação Completa Swagger UI

**Data:** 31/08/2026  
**Contexto:** Implementação do sistema de notificações em tempo real via WebSockets (ActionCable) para documentos recebidos por integrações (WhatsApp e E-mail), disparo automático no pipeline de extração e geração da documentação OpenAPI 3.0 interativa com Swagger UI.

---

## 1. Prompt Fornecido / Intenção

> *"Agora, preciso que voce implemente notificacoes em tempo real usando websockets e ActionCable para documentos criados a partir de integrações(email ou whatsapp), conforme explicitei na modelagem da arquitetura, a notificação deve conter alguns dados basicos da extração como nivel de confiança, status e nome do documento, tambem deve conter o id do documento para facilitar o front fazer o fetch. Apos isso preciso que voce gere a documentação completa da api usando swagger"*

---

## 2. Ações Executadas

1. **Configuração de Infraestrutura ActionCable (`config/cable.yml` e `app/channels/`):**
   - Configuração do adapter Redis com `REDIS_URL` dinâmica (`redis://localhost:6380/1`).
   - `ApplicationCable::Connection` com autenticação segura via token JWT (`Warden::JWTAuth::TokenDecoder`).
   - Criação de `DocumentosChannel` transmitindo para o stream `"documentos_integracoes"`.

2. **Serviço Emissor de Notificações (`app/services/notificacoes/emissor_notificacao_service.rb`):**
   - Disparo automático acionado no encerramento de `ProcessadorDocumentoService` para origens `whatsapp` e `email`.
   - Persistência na tabela `notificacoes` com título, conteúdo e metadados (`documento_id`, `score_confianca`, `nome_arquivo`, `tipo`, `status`, `cliente_nome`).
   - Broadcast em tempo real no ActionCable contendo todos os dados estruturados para fetch imediato no front-end.

3. **Endpoints REST de Notificações (`app/controllers/api/v1/notificacoes_controller.rb`):**
   - `GET /api/v1/notificacoes`: Listagem paginada via `huginn_datatable`.
   - `GET /api/v1/notificacoes/nao_lidas_count`: Contagem de não lidas.
   - `PATCH /api/v1/notificacoes/:id/lida`: Marcar notificação individual como lida.
   - `POST /api/v1/notificacoes/marcar_todas_lidas`: Marcar todas as pendentes como lidas.

4. **Documentação Completa da API via Swagger / OpenAPI 3.0:**
   - Criação do arquivo de especificação OpenAPI 3.0.3 estruturado em `public/swagger.json` abrangendo todas as rotas da API, esquemas de entrada/saída, headers de autenticação e filtros de Datatables.
   - Criação do controlador `ApiDocsController` servindo o Swagger UI moderno e interativo no endpoint `GET /api-docs`.
   - Criação do guia consolidado em Markdown `docs/API_DOCUMENTATION.md`.

---

## 3. Verificação de Resultados

- Suítes de testes em:
  - `spec/services/notificacoes/emissor_notificacao_service_spec.rb`
  - `spec/requests/api/v1/notificacoes_spec.rb`
  - `spec/requests/api_docs_spec.rb`
- **96 testes RSpec passando com 100% de sucesso.**
