# Especificação e Arquitetura do Sistema: DOC Intelligence

Este documento serve como especificação técnica, contrato de dados e contexto de engenharia para o agente de IA (Claude Code / Copilot), contendo o escopo completo de funcionalidades, modelo relacional robusto com travas de integridade no banco e a arquitetura hexagonal com Ports & Adapters.

---

## 1. Funcionalidades do Sistema

### 1.1 Ingestão e Processamento de Documentos
- **Upload Manual Geral:** Upload de arquivos (PDF ou imagem) na listagem geral de documentos. O sistema tenta associar automaticamente o documento a um `Cliente` existente via CPF extraído; se não localizar por CPF, realiza fallback buscando por Nome. Caso não encontre correspondência, `cliente_id` permanece nulo (`nullable: true`).
- **Upload Manual Vinculado ao Cliente:** Dentro da ficha do cliente, permite importar documentos que já são diretamente associados a ele.
- **Ingestão Automatizada via Webhooks com Idempotência de Evento:**
  - **WhatsApp:** Múltiplas instâncias/números configuráveis via `configuracoes_whatsapp`.
  - **E-mail (SMTP/IMAP/Inbound):** Múltiplas caixas postais configuráveis via `configuracoes_smtp`.
  - **Deduplicação de Evento (Early Rejection):** Checagem imediata no recebimento do webhook por `(origem, referencia_origem)` via constraint única no banco, descartando retries automáticos da Meta/provedores de e-mail antes de qualquer download pesado ou job em fila.
  - Triagem de payloads e sanitização por magic bytes.
- **Pipeline de Extração Assíncrono com IA:**
  - Classificação do tipo de documento e extração de dados estruturados via modelo multimodal ativo.
  - Atribuição de índice de confiança (`score_confianca`) determinando o status (`processado` vs `necessita_revisao`).
  - Geração de sugestão de nome padronizado para o arquivo (`nome_arquivo`).
  - Registro de auditoria por extração (`historicos_extracao`) com contagem de tokens de entrada/saída, tempo de resposta, provedor, modelo e custo financeiro consultado dinamicamente via adapter.

### 1.2 Gestão de Clientes e Endereços
- **Datatable de Clientes:** Listagem com paginação, busca e filtros avançados (por estado, cidade, CPF, nome).
- **Ficha do Cliente:** Edição de dados cadastrais, visualização de endereços e histórico completo de documentos pertencentes ao cliente.
- **Base Geográfica Normalizada:** Estrutura relacional de `Estado` (has_many `Cidades`) e `Cidade` populadas via seed migration para filtros performáticos.

### 1.3 Gestão, Conferência de Documentos e Trilha de Auditoria Humana
- **Datatable Global de Documentos:** Listagem com filtros compostos por Cliente, Tipo de Documento, Status (`pendente`, `processando`, `processado`, `necessita_revisao`, `falhou`), Provedor e Período.
- **Fila de Conferência Humana:** Visualização dos documentos em `necessita_revisao` ou `falhou`, permitindo ao operador conferir o arquivo original lado a lado com os campos e corrigir o JSON extraído.
- **Rastreabilidade de Revisão Humana:** Registro explícito do usuário responsável e timestamp de conferência (`revisado_por_id` e `revisado_em`), assegurando conformidade com auditoria de dados sensíveis (LGPD).
- **Notificações em Tempo Real:** Transmissão via broadcast WebSockets (ActionCable) para todos os administradores conectados quando novos documentos forem recebidos por integrações externas (WhatsApp / E-mail).

### 1.4 Painel Administrativo, Integrações e Auditoria de Custos
- **Configuração Dinâmica de Provedores de IA (`configuracoes_provedor_ia`):** Cadastro de credenciais de IA (Groq, OpenAI, OpenRouter, Gemini, Ollama) com armazenamento seguro via criptografia de aplicação (`ActiveRecord::Encryption`). Apenas **um** provedor pode estar com `ativo: true` simultaneamente.
- **Configuração de Canais de Ingestão:**
  - Cadastro e gerenciamento de múltiplas conexões de WhatsApp (`configuracoes_whatsapp`).
  - Cadastro e gerenciamento de múltiplas caixas de E-mail (`configuracoes_smtp`).
- **Nomenclatura Unificada de Credenciais:** Padronização do campo `credencial_criptografada` em todas as tabelas de integração externa.
- **Painel de Auditoria Financeira de IA:** Visualização agregada de gastos por provedor e por modelo, com detalhamento drill-down de cada documento processado, exibindo tokens consumidos ($input / output$), tempo de resposta e custo retornado/calculado pelo adapter do provedor.

---

## 2. Arquitetura e Modelagem do Sistema

### 2.1 Modelo Relacional de Dados (Schema em Português)

```text
  ┌──────────────────┐
  │      Estado      │
  └────────┬─────────┘
           │ 1
           │ has_many
           │ *
  ┌────────┴─────────┐       ┌────────────────────────┐
  │      Cidade      │       │        Usuario         │
  └────────┬─────────┘       │    (Administrador)     │
           │ 1               └───────────┬────────────┘
           │ has_many                    │ 1
           │ *                           │ has_many (revisões)
  ┌────────┴─────────┐ 1           1 ┌───┴────────────────────┐
  │     Endereco     ├───────────────┤        Cliente         │
  └──────────────────┘  belongs_to   └───────────┬────────────┘
                                                 │ 1
                                                 │ has_many
                                                 │ * (cliente_id nullable)
                                     ┌───────────┴────────────┐
                                     │       Documento        │
                                     └───────────┬────────────┘
                                                 │ 1
                                                 │ has_many
                                                 │ *
                                     ┌───────────┴────────────┐
                                     │   HistoricoExtracao    │
                                     └────────────────────────┘
```

#### Definição das Tabelas

* **`usuarios`**
  - `id`: UUID (PK)
  - `nome`: VARCHAR NOT NULL
  - `email`: VARCHAR NOT NULL (UNIQUE)
  - `created_at`, `updated_at`: TIMESTAMP

* **`estados`**
  - `id`: BIGSERIAL (PK)
  - `nome`: VARCHAR NOT NULL
  - `sigla`: VARCHAR(2) NOT NULL (UNIQUE) -- 'RN', 'SP', etc.

* **`cidades`**
  - `id`: BIGSERIAL (PK)
  - `estado_id`: FK -> `estados.id` NOT NULL
  - `nome`: VARCHAR NOT NULL

* **`clientes`**
  - `id`: UUID (PK)
  - `nome`: VARCHAR NOT NULL
  - `cpf`: VARCHAR(14) (INDEX, UNIQUE)
  - `email`: VARCHAR
  - `telefone`: VARCHAR
  - `created_at`, `updated_at`: TIMESTAMP

* **`enderecos`**
  - `id`: UUID (PK)
  - `cliente_id`: FK -> `clientes.id` NOT NULL
  - `cidade_id`: FK -> `cidades.id` NOT NULL
  - `logradouro`: VARCHAR NOT NULL
  - `numero`: VARCHAR NOT NULL
  - `bairro`: VARCHAR
  - `cep`: VARCHAR(10)
  - `complemento`: VARCHAR

* **`documentos`**
  - `id`: UUID (PK)
  - `cliente_id`: FK -> `clientes.id` (NULLABLE)
  - `tipo`: VARCHAR NOT NULL -- 'rg', 'cnh', 'comprovante_residencia', 'contracheque', 'desconhecido'
  - `origem`: VARCHAR NOT NULL -- 'manual', 'whatsapp', 'email'
  - `referencia_origem`: VARCHAR -- Message-ID WhatsApp/Email
  - `status`: VARCHAR NOT NULL DEFAULT 'pendente' -- 'pendente', 'processando', 'processado', 'necessita_revisao', 'falhou'
  - `sha256_arquivo`: VARCHAR(64) NOT NULL
  - `url_arquivo_bruto`: TEXT
  - `nome_arquivo`: VARCHAR -- Sugestão de nome padronizado
  - `dados_extraidos`: JSONB DEFAULT '{}' -- Validado por PORO Schemas
  - `versao_schema`: INT DEFAULT 1
  - `score_confianca`: FLOAT DEFAULT 0.0
  - `lock_version`: INT DEFAULT 0 -- Concorrência otimista para múltiplos atendentes
  - `revisado_por_id`: FK -> `usuarios.id` (NULLABLE) -- Auditoria de intervenção humana
  - `revisado_em`: TIMESTAMP (NULLABLE)
  - `created_at`, `updated_at`: TIMESTAMP

* **`historicos_extracao`**
  - `id`: UUID (PK)
  - `documento_id`: FK -> `documentos.id` NOT NULL
  - `configuracao_provedor_ia_id`: FK -> `configuracoes_provedor_ia.id` (NULLABLE)
  - `nome_provedor`: VARCHAR NOT NULL -- 'groq', 'openai', 'gemini', 'openrouter', 'ollama', 'mock'
  - `nome_modelo`: VARCHAR NOT NULL
  - `versao_prompt`: VARCHAR NOT NULL -- 'v1.0'
  - `tokens_entrada`: INT DEFAULT 0
  - `tokens_saida`: INT DEFAULT 0
  - `tempo_resposta_ms`: INT DEFAULT 0
  - `custo_estimado_usd`: DECIMAL(10, 6) DEFAULT 0.0 -- Obtido via adapter do provedor
  - `resposta_bruta`: JSONB
  - `mensagem_erro`: TEXT
  - `created_at`: TIMESTAMP

* **`configuracoes_provedor_ia`**
  - `id`: UUID (PK)
  - `nome_provedor`: VARCHAR NOT NULL -- 'groq', 'openai', 'gemini', 'openrouter', 'ollama'
  - `nome_modelo`: VARCHAR NOT NULL
  - `credencial_criptografada`: TEXT -- Criptografado nativamente via ActiveRecord::Encryption
  - `ativo`: BOOLEAN DEFAULT false NOT NULL -- Apenas um ativo no sistema
  - `created_at`, `updated_at`: TIMESTAMP

* **`configuracoes_whatsapp`**
  - `id`: UUID (PK)
  - `nome`: VARCHAR NOT NULL -- ex: "Atendimento Principal"
  - `tipo_provedor`: VARCHAR NOT NULL -- 'evolution_api', 'zapi', 'meta_cloud'
  - `credencial_criptografada`: TEXT -- Criptografado via ActiveRecord::Encryption
  - `numero_telefone`: VARCHAR
  - `ativo`: BOOLEAN DEFAULT true NOT NULL
  - `created_at`, `updated_at`: TIMESTAMP

* **`configuracoes_smtp`**
  - `id`: UUID (PK)
  - `nome`: VARCHAR NOT NULL -- ex: "Documentos Lamarck"
  - `tipo_provedor`: VARCHAR NOT NULL -- 'sendgrid_inbound', 'imap', 'postmark'
  - `credencial_criptografada`: TEXT -- Criptografado via ActiveRecord::Encryption
  - `endereco_email`: VARCHAR NOT NULL
  - `ativo`: BOOLEAN DEFAULT true NOT NULL
  - `created_at`, `updated_at`: TIMESTAMP

* **`notificacoes`**
  - `id`: UUID (PK)
  - `titulo`: VARCHAR NOT NULL
  - `conteudo`: TEXT NOT NULL
  - `lida_em`: TIMESTAMP
  - `metadados`: JSONB DEFAULT '{}'
  - `created_at`: TIMESTAMP

---

### 2.2 Índices e Constraints de Integridade no PostgreSQL

```sql
-- 1. Idempotência de Evento de Ingestão (rejeita retries do webhook no início)
CREATE UNIQUE INDEX idx_documentos_origem_referencia 
  ON documentos (origem, referencia_origem) 
  WHERE referencia_origem IS NOT NULL;

-- 2. Deduplicação por Conteúdo (Scoped por Cliente quando associado)
CREATE UNIQUE INDEX idx_documentos_cliente_sha256 
  ON documentos (cliente_id, sha256_arquivo) 
  WHERE cliente_id IS NOT NULL;

-- 3. Busca performática por Hash quando o cliente ainda não foi identificado
CREATE INDEX idx_documentos_sha256_nulo 
  ON documentos (sha256_arquivo) 
  WHERE cliente_id IS NULL;
```

---

## 2.3 Validação de Schemas Dinâmicos (PORO Validations)

Os payloads no campo `dados_extraidos` (JSONB) são validados por classes PORO conforme o `tipo` e a `versao_schema`:

```text
app/
└── models/
    └── esquemas_documento/
        ├── esquema_base.rb
        ├── esquema_rg_v1.rb
        ├── esquema_cnh_v1.rb
        ├── esquema_comprovante_residencia_v1.rb
        └── esquema_contracheque_v1.rb
```

---

## 2.4 Arquitetura Hexagonal: Ports & Adapters por Domínio

Toda integração externa é desacoplada através de Ports (interfaces abstratas) e Adapters específicos, incluindo consulta de preços e execução:

```text
app/
└── services/
    ├── extracao_ia/
    │   ├── porta.rb
    │   ├── fabrica.rb
    │   └── adaptadores/
    │       ├── adaptador_mock.rb
    │       ├── adaptador_groq.rb
    │       ├── adaptador_openai.rb
    │       ├── adaptador_gemini.rb
    │       ├── adaptador_openrouter.rb
    │       └── adaptador_ollama.rb
    │
    ├── integracao_whatsapp/
    │   ├── porta.rb
    │   ├── fabrica.rb
    │   └── adaptadores/
    │       ├── adaptador_evolution_api.rb
    │       ├── adaptador_zapi.rb
    │       └── adaptador_meta_cloud.rb
    │
    └── ingestao_email/
        ├── porta.rb
        ├── fabrica.rb
        └── adaptadores/
            ├── adaptador_sendgrid.rb
            ├── adaptador_postmark.rb
            └── adaptador_imap.rb
```

---

## 2.5 Fluxo de Execução com Early Idempotency e Auditoria

```text
[Webhook Ingestão / Upload Manual]
                │
                ▼
[DocumentosController / IngestionJob]
  ├── 1. Checa idempotência de evento: idx_documentos_origem_referencia
  │      └── Se duplicado -> Retorna HTTP 200 OK imediatamente (no-op)
  ├── 2. Sanitiza arquivo & valida Magic Bytes
  ├── 3. Calcula SHA-256 e verifica duplicata existente
  └── 4. Persiste Documento (status: :pendente) -> Despacha ProcessarDocumentoJob
                │
                ▼
[ProcessarDocumentoJob]
  ├── 1. Carrega ExtracaoIa::Fabrica.provedor_ativo
  ├── 2. Dispara extração multimodal no Adaptador ativo
  ├── 3. Adaptador consulta/calcula custo dos tokens dinamicamente
  ├── 4. Cria registro em `historicos_extracao` (tokens, tempo, custo)
  ├── 5. Valida `dados_extraidos` via Esquema PORO correspondente
  ├── 6. Busca/Associa Cliente (via CPF -> Fallback Nome)
  ├── 7. Atualiza Documento (status: :processado ou :necessita_revisao)
  └── 8. Emite Broadcast ActionCable (WebSockets) para todos os administradores
```
