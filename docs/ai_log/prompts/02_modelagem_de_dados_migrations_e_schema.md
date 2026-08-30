# Prompt 02: Modelagem de Dados, Migrations e Schema do Banco

**Data:** 30/08/2026  
**Contexto:** Criação do banco de dados relacional no PostgreSQL estritamente em português, com chaves UUID, integridade referencial, índices parciais de idempotência/deduplicação e modelos ActiveRecord.

---

## 1. Prompt Fornecido / Intenção

> "Agora gere todas as migrations com base na especificação de arquitetura que forneci para inicializar o schema do banco"

---

## 2. Ações Executadas

1. **Geração de Migrations via Rails Generator (`bin/rails g migration`):**
   - `bin/rails active_storage:install` (tabelas de anexos com suporte a chaves UUID).
   - `bin/rails g migration CreateUsuariosAndJwtDenylist` (`usuarios`, `jwt_denylists`).
   - `bin/rails g migration CreateEstadosAndCidades` (`estados`, `cidades` com `BIGSERIAL`).
   - `bin/rails g migration CreateClientesAndEnderecos` (`clientes`, `enderecos`).
   - `bin/rails g migration CreateConfiguracoesIntegracoes` (`configuracoes_provedor_ia`, `configuracoes_whatsapp`, `configuracoes_smtp`).
   - `bin/rails g migration CreateDocumentosAndHistoricosExtracao` (`documentos`, `historicos_extracao`).
   - `bin/rails g migration CreateNotificacoes` (`notificacoes`).

2. **Garantias de Integridade no PostgreSQL:**
   - **Idempotência de Evento (Webhooks):**  
     `CREATE UNIQUE INDEX idx_documentos_origem_referencia ON documentos (origem, referencia_origem) WHERE referencia_origem IS NOT NULL;`
   - **Deduplicação de Arquivo por Cliente (SHA-256):**  
     `CREATE UNIQUE INDEX idx_documentos_cliente_sha256 ON documentos (cliente_id, sha256_arquivo) WHERE cliente_id IS NOT NULL;`
   - **Busca por Hash sem Cliente Vinculado:**  
     `CREATE INDEX idx_documentos_sha256_nulo ON documentos (sha256_arquivo) WHERE cliente_id IS NULL;`
   - **Concorrência Otimista:** Campo `lock_version` para evitar sobreposição na conferência humana concorrente.

3. **Criação dos Modelos ActiveRecord (`app/models/`):**
   - `Usuario` (Devise, JWT revogação com `JwtDenylist`).
   - `Estado` e `Cidade` (relacionamento 1:N).
   - `Cliente` e `Endereco` (validações e integridade).
   - `ConfiguracaoProvedorIa`, `ConfiguracaoWhatsapp`, `ConfiguracaoSmtp` (com `encrypts :credencial_criptografada`).
   - `Documento` (enums de status/origem, anexo ActiveStorage, validações de unicidade condicional).
   - `HistoricoExtracao` e `Notificacao`.

---

## 3. Verificação de Resultados

- Execução bem-sucedida de `bin/rails db:migrate`.
- Schema gerado em `db/schema.rb`.
- Validação no `bin/rails runner` confirmando carregamento de todos os models sem inconsistências.
