# DOC Intelligence — Documentação Completa da API REST & WebSockets

Bem-vindo à documentação oficial da API do **DOC Intelligence** (Lamarck — Sociedade de Advogados).

> **Acesso Swagger UI Interativo:** Abra [http://localhost:3002/api-docs](http://localhost:3002/api-docs) no seu navegador para testar os endpoints interativamente e visualizar todos os schemas OpenAPI 3.0.

---

## 1. Visão Geral da Arquitetura e Comunicação

* **Base URL:** `http://localhost:3002/api/v1`
* **WebSocket / ActionCable:** `ws://localhost:3002/cable`
* **Autenticação:** Bearer Token JWT via cabeçalho `Authorization: Bearer <TOKEN>` (e chave no corpo do login).
* **Datatables:** Paginação e filtros de alta performance via `huginn_datatable` protegendo o schema real do banco via `huginn_attributes`.
* **Concorrência Otimista:** Campo `lock_version` para evitar colisões entre múltiplos operadores na fila de conferência.

---

## 2. Autenticação JWT (`/api/v1/auth`)

### 2.1 Login
* **Rota:** `POST /api/v1/auth/login`
* **Corpo da Requisição (JSON):**
```json
{
  "usuario": {
    "email": "admin@lamarck.adv.br",
    "password": "Admin@123456"
  }
}
```
* **Resposta de Sucesso (`200 OK`):**
```json
{
  "mensagem": "Login realizado com sucesso",
  "token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI3MjAzY2JjNC1jYjgxLTQ3MmQtOGQ1NC0yOWMzNWQxYmIxMzYiLCJzY3AiOiJ1c3VhcmlvIiwiYXVkIjpudWxsLCJpYXQiOjE3MjUwMDAwMDAsImV4cCI6MTcyNTg2NDAwMCwianRpIjoiOGE1ZjAwYzgtOTZhOS00YjBhLTg5MDAtMWQyOTY0NDQwOGY2In0...",
  "usuario": {
    "id": "7203cbc4-cb81-472d-8d54-29c35d1bb136",
    "nome": "Administrador Lamarck",
    "email": "admin@lamarck.adv.br",
    "created_at": "2026-08-31T06:36:45.830Z"
  }
}
```

### 2.2 Consultar Perfil Logado
* **Rota:** `GET /api/v1/auth/me`
* **Headers:** `Authorization: Bearer <TOKEN>`

### 2.3 Logout (Revogação de Token)
* **Rota:** `DELETE /api/v1/auth/logout`
* **Headers:** `Authorization: Bearer <TOKEN>`

---

## 3. Webhooks Públicos (`/api/v1/webhooks`)

*A autenticação é dinâmica e estrita, validando se a chave enviada pertence a alguma das instâncias ativas no banco (`ConfiguracaoWhatsapp.ativos` ou `ConfiguracaoSmtp.ativos`).*

### 3.1 WhatsApp Webhook
* **Handshake Meta Cloud:** `GET /api/v1/webhooks/whatsapp?hub.mode=subscribe&hub.verify_token=SUA_CHAVE&hub.challenge=1158201444` (retorna `hub.challenge` em texto puro).
* **Ingestão de Mensagens / Mídias:** `POST /api/v1/webhooks/whatsapp/evolution_api` ou `POST /api/v1/webhooks/whatsapp/meta_cloud`.
* **Headers:** `apikey: <SUA_CHAVE_ATIVA>` ou `Authorization: Bearer <TOKEN>`

### 3.2 E-mail Webhook
* **Ingestão de E-mails / Anexos:** `POST /api/v1/webhooks/email/sendgrid` (multipart/form-data) ou `POST /api/v1/webhooks/email/postmark` (JSON).
* **Headers:** `X-Postmark-Server-Token: <SUA_CHAVE_ATIVA>`

---

## 4. Gestão de Documentos & Fila de Conferência (`/api/v1/documentos`)

### 4.1 Datatable Global de Documentos
* **Rota:** `GET /api/v1/documentos`
* **Parâmetros de Filtro (Huginn):**
  * `page=1&per_page=10`
  * `filters[tipo]=rg` (ou `cnh`, `comprovante_residencia`, `contracheque`)
  * `filters[status]=processado` (ou `pendente`, `necessita_revisao`, `falhou`)
  * `filters[origem]=whatsapp` (ou `email`, `manual`)
  * `filters[cliente_nome]=Beatriz`

### 4.2 Upload Manual Geral
* **Rota:** `POST /api/v1/documentos`
* **Form-Data:**
  * `arquivo`: binário do arquivo (PDF, JPEG, PNG, WebP)
  * `tipo`: `cnh` (opcional)
  * `cliente_id`: UUID do cliente (opcional)

### 4.3 Fila de Conferência Humana
* **Rota:** `GET /api/v1/documentos/fila_conferencia`
* Retorna todos os documentos com status `necessita_revisao` ou `falhou` para atuação do operador.

### 4.4 Revisar e Aprovar Documento (com `lock_version`)
* **Rota:** `PATCH /api/v1/documentos/:id/revisar`
* **Corpo da Requisição:**
```json
{
  "lock_version": 2,
  "tipo": "cnh",
  "cliente_id": "bf730877-d2da-4796-b989-f4b2c157430f",
  "dados_extraidos": {
    "nome": "Dra. Beatriz Albuquerque",
    "cpf": "111.444.777-99",
    "numero_cnh": "12345678900"
  }
}
```
* **Garantia de Concorrência:** Se outro atendente salvar o registro antes, a requisição é rejeitada com `HTTP 409 Conflict`.

---

## 5. Notificações em Tempo Real (WebSockets / ActionCable)

### 5.1 Conexão WebSocket
* **URL:** `ws://localhost:3002/cable?token=SEU_TOKEN_JWT`
* **Canal:** `DocumentosChannel`
* **Stream:** `documentos_integracoes`

### 5.2 Payload Transmitido em Tempo Real
Quando a IA conclui a extração de um documento vindo do WhatsApp ou E-mail, todos os clientes conectados recebem instantaneamente:
```json
{
  "evento": "documento_integracao_processado",
  "notificacao_id": "e4f8812c-cb81-472d-8d54-29c35d1bb136",
  "titulo": "Novo documento recebido via WhatsApp",
  "conteudo": "O documento 'cnh_cliente.pdf' foi extraído com sucesso (Confiança: 95%).",
  "documento": {
    "documento_id": "501cc77b-6a58-45ef-b4f2-aca1fe1967fd",
    "nome_arquivo": "cnh_cliente.pdf",
    "tipo": "cnh",
    "origem": "whatsapp",
    "status": "processado",
    "score_confianca": 0.95,
    "cliente_id": "bf730877-d2da-4796-b989-f4b2c157430f",
    "cliente_nome": "Dra. Beatriz Albuquerque",
    "created_at": "2026-08-31T13:00:00.000Z"
  },
  "enviado_em": "2026-08-31T13:00:04.000Z"
}
```

### 5.3 Endpoints REST de Notificações
* `GET /api/v1/notificacoes`: Listagem paginada de notificações recebidas.
* `GET /api/v1/notificacoes/nao_lidas_count`: Contagem de não lidas para o badge da UI.
* `PATCH /api/v1/notificacoes/:id/lida`: Marcar notificação como lida.
* `POST /api/v1/notificacoes/marcar_todas_lidas`: Marcar todas as pendentes como lidas.

---

## 6. Painel de Auditoria de Custos de IA (`/api/v1/auditoria/custos`)

* **Rota:** `GET /api/v1/auditoria/custos`
* **Filtros Opcionais:** `provedor=openrouter`, `modelo=google/gemini-2.5-flash-lite`, `data_inicio=2026-08-01`, `data_fim=2026-08-31`
* **Exemplo de Retorno:**
```json
{
  "resumo": {
    "total_custo_usd": 0.000306,
    "total_tokens_entrada": 2193,
    "total_tokens_saida": 216,
    "total_tokens": 2409,
    "total_processamentos": 1,
    "tempo_medio_resposta_ms": 3868.0,
    "gastos_por_provedor": {
      "openrouter": 0.000306
    },
    "gastos_por_modelo": {
      "google/gemini-2.5-flash-lite": 0.000306
    }
  },
  "historicos": [...]
}
```
