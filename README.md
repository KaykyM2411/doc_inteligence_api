# DOC Intelligence API

> **Serviço de Inteligência Documental e Extração Estruturada**  
> Desafio Técnico de Seleção em Tecnologia — **Trilha A (Back-end)**  
> **Lamarck — Sociedade de Advogados** · *Núcleo de Engenharia de Software*

---

## 1. Visão Geral do Produto

O **DOC Intelligence** é um serviço desacoplado de inteligência documental projetado para automatizar a triagem, classificação, validação e extração de dados estruturados a partir de documentos jurídicos e cadastrais (RG, CNH, Comprovantes de Residência, Contracheques e Procurações) recebidos via WhatsApp, e-mail e upload manual no balcão do atendimento.

O sistema elimina o trabalho manual de conferência repetitiva, aplicando validações automáticas com inteligência artificial multimodal, detecção e descarte antecipado de duplicatas (*early idempotency*), resiliência corporativa com **Multi-Provider Fallback Cascade** e **Circuit Breaker**, concorrência otimista na fila de revisão humana e auditoria *drill-down* de consumo financeiro de tokens por modelo e provedor.

---

## 2. Estratégia de Desenvolvimento: Especificação Antes do Código

A premissa que guiou todo o desenvolvimento do DOC Intelligence foi deliberada e rigorosa: **nenhuma linha de código foi escrita antes de existir uma especificação técnica completa e detalhada do sistema.**

Antes de abrir o editor, foi produzido o documento canônico [`docs/especificacao_e_arquitetura_doc_intelligence.md`](docs/especificacao_e_arquitetura_doc_intelligence.md) — um artefato com ~280 linhas contendo:

- **Modelo relacional completo** com 11 tabelas, tipos de dados, chaves estrangeiras, UUIDs nativos e constraints SQL explícitas.
- **Índices parciais de integridade** para idempotência de eventos de webhook `(origem, referencia_origem)` e deduplicação de conteúdo por SHA-256 `(cliente_id, sha256_arquivo)`.
- **Fluxo de execução ponta a ponta** desde a chegada do documento (WhatsApp, E-mail ou Upload) até a conclusão da extração, validação PORO, associação de cliente e auditoria de custos.
- **Árvore da Arquitetura Hexagonal (Ports & Adapters)** com os 6 domínios de serviço, contratos abstratos, fábricas dinâmicas e adaptadores por provedor.
- **Regras de negócio e decisões de segurança** como `ActiveRecord::Encryption` para credenciais, `lock_version` para concorrência otimista e `ActiveStorage` para gestão de arquivos.

A implementação seguiu rigorosamente esse contrato: **todas as tabelas, campos, constraints, enums, índices parciais e a estrutura hexagonal foram implementados exatamente como especificados.** O histórico de commits do repositório reflete essa sequência — a especificação e o `AGENTS.md` (diretrizes de governança de IA) foram commitados antes de qualquer código de aplicação.

As evoluções e melhorias introduzidas após os testes de estresse (como o *Circuit Breaker*, o *Fallback Cascade* e a serialização com *Alba*) foram registradas com total transparência no documento dedicado [`docs/divergencias_e_evolucoes_arquiteturais.md`](docs/divergencias_e_evolucoes_arquiteturais.md), preservando a especificação canônica intacta.

---

## 3. Principais Funcionalidades Implementadas

### 3.1 Multi-Provedores de IA Multimodal (Testados com APIs Reais)
- **Desacoplamento de Provedores:** Suporte integrado a **Grok (xAI Vision)**, **OpenAI (GPT-4o)**, **Google Gemini Multimodal**, **OpenRouter**, **Ollama** e **Mock**.
- **Chaves Reais Testadas:** A integração foi testada e homologada consumindo APIs oficiais reais (Gemini e OpenRouter), validando latência, qualidade da extração JSON e respostas multimodais de alta resolução.
- **Consulta Dinâmica de Preços (Domain Pricing):** O custo financeiro de cada requisição em USD não é *hardcoded*; o sistema consulta dinamicamente a tabela de preços via endpoints oficiais dos provedores (ex: xAI e OpenRouter) e audita o custo exato por documento.

### 3.2 Resiliência Corporativa: Fallback Cascade & Circuit Breaker (Fatos a e e)
- **Multi-Provider Fallback Cascade:** Múltiplos provedores de IA podem estar ativos simultaneamente, ordenados por prioridade (`ordem`). Se o provedor principal apresentar instabilidade, *rate limit* (429) ou indisponibilidade (503), o sistema faz **failover automático e instantâneo** para o provedor secundário da fila sem interromper o atendimento.
- **Circuit Breaker com Redis ([`app/services/extracao_ia/circuit_breaker.rb`](app/services/extracao_ia/circuit_breaker.rb)):** Máquina de 3 estados (`:closed`, `:open`, `:half_open`) compartilhada via Redis entre todos os *workers* do Sidekiq.
  - Após 5 falhas consecutivas de uma API externa, o circuito **abre (OPEN)**, ativando a política de *Fast Fail* (1ms) para não travar os *workers* do Sidekiq com timeouts longos (5-40s).
  - Após a janela de *cooldown* de 2 minutos, o circuito transita para `:half_open` e envia uma requisição piloto de teste para verificar a recuperação do serviço.

### 3.3 Ingestão Multicanal & Webhooks (WhatsApp & E-mail)
- **WhatsApp (Múltiplas Instâncias):** Suporte nativo a **Evolution API v2** (`messages.upsert`) e **Meta Cloud Graph API** (com fluxo seguro de download de mídia em 2 etapas e verificação `hub.challenge`).
- **E-mail Inbound:** Suporte a **Postmark Inbound** (JSON Base64) e **SendGrid Inbound Parse** (*multipart/form*).
- **Early Idempotency & Magic Bytes:** Descarte imediato de *retries* de webhooks por `(origem, referencia_origem)` antes de downloads pesados, e sanitização rigorosa de cabeçalhos binários para rejeição de arquivos corrompidos ou maliciosos.

### 3.4 Gestão de Clientes e Associação Automática Inteligente
- **CRUD Completo de Clientes & Endereços:** Cadastro de clientes com validação de CPF e base geográfica normalizada (Estados e Cidades).
- **Associação Automática Inteligente:** Documentos recebidos sem vínculo prévio são analisados pela IA; o sistema tenta associar automaticamente o documento a um cliente existente via CPF extraído; caso não localize, realiza fallback buscando por Nome normalizado.

### 3.5 Fila de Conferência Humana & Concorrência Otimista (Fato g)
- **Score de Confiança:** Extrações com score $\ge 0.85$ e schemas PORO válidos são marcadas automaticamente como `processado`. Casos ambíguos ou com baixa confiança são encaminhados para `necessita_revisao`.
- **Prevenção de Sobrescrita:** Uso de `lock_version` do PostgreSQL para controle de concorrência otimista. Quando dois atendentes abrem o mesmo documento simultaneamente, o segundo a salvar recebe `HTTP 409 Conflict`, impedindo perda de dados de conferência.
- **Rastreabilidade LGPD:** Registro explícito do usuário responsável e data/hora da intervenção humana (`revisado_por_id` e `revisado_em`).

### 3.6 Notificações em Tempo Real (WebSockets / ActionCable)
- **Broadcast em Tempo Real:** Transmissão instantânea via WebSocket (`/cable` no canal `documentos_integracoes`) para todos os atendentes conectados quando um documento for recebido e processado via WhatsApp ou E-mail.
- **Autenticação Segura:** Handshake autenticado via JWT (`?token=...` ou header `Authorization`), rejeitando conexões anônimas.

### 3.7 Painel de Auditoria de Custos de IA
- **Dashboard Drill-Down:** Endpoint analítico que agrega o total gasto em USD, tokens de entrada/saída consumidos, tempo médio de resposta em milissegundos e distribuição de gastos por modelo e por provedor.

---

## 4. Arquitetura e Engenharia de Software

### 4.1 Arquitetura Hexagonal (Ports & Adapters)
A aplicação adota **Arquitetura Hexagonal estrita** em `app/services/`, isolando completamente a lógica de domínio de qualquer dependência de fornecedores externos:

```text
app/services/
├── extracao_ia/              # Domínio de Extração Multimodal
│   ├── port.rb               # Contrato abstrato da interface
│   ├── factory.rb            # Fábrica que instancia provedores ativos ordenados
│   ├── circuit_breaker.rb    # Resiliência com Redis (Fast Fail & Half-Open)
│   ├── default_prompt.rb     # Prompt mestre versionado (v1.0)
│   ├── extraction_result.rb  # DTO normalizado de retorno
│   └── adapters/             # Implementações concretas (Grok, OpenAI, Gemini, etc.)
│
├── consulta_precos/          # Domínio de Precificação Dinâmica de Tokens
│   ├── port.rb, factory.rb, price_result.rb
│   └── adapters/             # GrokPricingAdapter, OpenrouterPricingAdapter, Mock
│
├── integracao_whatsapp/      # Domínio de Ingestão via WhatsApp
│   ├── port.rb, factory.rb, whatsapp_message.rb, whatsapp_media.rb
│   └── adapters/             # EvolutionApiAdapter, MetaCloudAdapter, Mock
│
├── ingestao_email/           # Domínio de Ingestão via E-mail
│   ├── port.rb, factory.rb, email_message.rb, email_attachment.rb
│   └── adapters/             # PostmarkAdapter, SendgridAdapter, Mock
│
└── documentos/               # Domínio Core de Orquestração
    ├── ingestao_service.rb
    ├── processador_documento_service.rb
    └── validador_arquivo.rb
```

### 4.2 Camada de Apresentação Desacoplada (Alba Serializers)
A API utiliza serializers dedicados baseados na gem **`alba`** em `app/serializers/` (`DocumentoSerializer`, `ClienteSerializer`, `HistoricoExtracaoSerializer`, etc.), garantindo:
- Desacoplamento entre a camada de persistência e a representação JSON pública;
- Proteção automática de credenciais e dados sensíveis (campos confidenciais nunca são expostos);
- Formatação consistente de relacionamentos encadeados.

### 4.3 Validações Dinâmicas com Schemas PORO
Os dados extraídos em JSONB são validados e sanitizados por classes PORO (`ActiveModel::Model`) em `app/models/esquemas_documento/`:
- `EsquemaRgV1`, `EsquemaCnhV1`, `EsquemaComprovanteResidenciaV1`, `EsquemaContrachequeV1`.
- `EsquemaBase`: Utilitários reutilizáveis de sanitização de CPF, telefones com regex canônica e parsing financeiro.
- `FactoryEsquemas`: Resolução dinâmica por tipo de documento e versão do schema.

### 4.4 Destaque da Stack: Gem `huginn_datatable` (Autoria Própria)
Para resolver a paginação performática, ordenação multicamadas, mapeamento de aliases públicos e filtros dinâmicos de dados em tabelas relacionais complexas (Clientes, Documentos, Estados, Cidades e Auditoria), o projeto utiliza a gem **[`huginn_datatable`](https://rubygems.org/gems/huginn_datatable)** (`require "huginn"`), desenvolvida pelo próprio candidato e publicada no RubyGems.

---

## 5. Stack Tecnológica

| Componente | Tecnologia | Finalidade |
|:---|:---|:---|
| **Linguagem & Framework** | Ruby 4.0.6 · Rails 8.1.3 (API-only) | Core da API RESTful de alta produtividade |
| **Banco de Dados** | PostgreSQL 16 | UUIDs nativos (`pgcrypto`), JSONB e índices parciais únicos |
| **Fila & Cache** | Redis 7 + Sidekiq | Processamento assíncrono resiliente de documentos pesados |
| **Resiliência de IA** | Circuit Breaker + Redis | Proteção contra falhas de terceiros e failover automático |
| **Serialização JSON** | Alba | Camada de apresentação desacoplada e segura |
| **Autenticação** | Devise + Devise-JWT | Autenticação stateless JWT com denylist de revogação |
| **WebSockets** | ActionCable | Notificações em tempo real para o atendimento |
| **Paginação & Datatables**| `huginn_datatable` (Gem Própria) | Queries otimizadas com aliases seguros e filtros dinâmicos |
| **HTTP Client** | Faraday | Integração com APIs externas de IA e Webhooks |
| **Migrations de Dados** | `data_migrate` | Separação entre migrations estruturais de schema e populações de dados |
| **Testes Automatizados** | RSpec 7, WebMock, Faker | Suíte completa de testes unitários, de serviços e de integração |
| **Documentação Interativa**| Swagger UI / OpenAPI 3.0 | Visualização e experimentação dos endpoints em `/api-docs` |

---

## 6. Como Rodar o Projeto

### Opção A: Execução Completa via Docker Compose (Recomendada)
Sobe o banco PostgreSQL, Redis, servidor Rails e o worker do Sidekiq em contêineres orquestrados:

```bash
# 1. Clone o repositório e acesse o diretório
git clone <url-do-repositorio>
cd doc_inteligence_api

# 2. Crie o arquivo de ambiente a partir do exemplo
cp .env.example .env

# 3. Construa e suba todos os serviços
docker compose up --build
```

A API estará pronta e respondendo em `http://localhost:3000` (ou porta configurada).  
Documentação Swagger UI em: `http://localhost:3000/api-docs`.

---

### Opção B: Execução Local Tradicional

#### Pré-requisitos:
- Ruby 4.0.6 instalado
- PostgreSQL 16 e Redis 7 ativos

```bash
# 1. Instalar dependências
bundle install

# 2. Configurar variáveis de ambiente
cp .env.example .env

# 3. Criar banco e executar migrations de schema e de dados
bin/rails db:create db:migrate
bin/rails data:migrate

# 4. Iniciar o worker do Sidekiq (em um terminal separado)
bundle exec sidekiq

# 5. Iniciar o servidor Rails
bin/rails server -p 3000
```

---

## 7. Testes Automatizados

Para rodar a suíte completa de testes:

```bash
# Execução Local
bundle exec rspec

# Ou Execução 100% dentro do Docker
docker compose run --rm -e RAILS_ENV=test api bundle exec rspec
```

### O que foi testado e por quê

A suíte de testes automatizados priorizou cobrir de forma profunda e exaustiva os caminhos críticos e os pontos de maior fragilidade operacional do sistema, alinhando-se aos **fatos do ambiente** do desafio:

1. **Pipeline de Ingestão e Deduplicação (Fato c):** Testes comprovando que reenvios do mesmo arquivo por um cliente são interceptados por hash SHA-256 sem duplicação no banco, e que eventos repetidos de webhook são descartados de imediato por Early Idempotency.
2. **Webhooks e Sanitização de Magic Bytes (Fato b):** Testes com payloads reais de WhatsApp e E-mail, além de rejeição de arquivos executáveis corrompidos ou maliciosos.
3. **Resiliência e Circuit Breaker (Fatos a e e):** Testes unitários cobrindo os 3 estados do disjuntor (`closed`, `open`, `half_open`) e a cascata de fallback automático entre provedores de IA.
4. **Concorrência Otimista na Fila de Conferência (Fato g):** Simulação de dois atendentes tentando salvar o mesmo documento simultaneamente, atestando o retorno de `HTTP 409 Conflict` via `lock_version`.
5. **Ports & Adapters de IA e Precificação Dinâmica (Fato f):** Testes de fallback gracioso para o `MockAdapter`, isolamento de chamadas HTTP via WebMock e cálculo dinâmico de custos de tokens.
6. **Autenticação JWT e WebSockets:** Testes de ciclo de vida de tokens (login, me, logout com revogação) e conexão autenticada ao ActionCable.

---

## 8. Documentação da API e Governança de IA

- **Swagger UI / OpenAPI 3.0:** Acesse `http://localhost:3000/api-docs` para explorar e testar todas as rotas da API interativamente.
- **Especificação Canônica:** O projeto foi implementado com base na especificação inicial [`docs/especificacao_e_arquitetura_doc_intelligence.md`](docs/especificacao_e_arquitetura_doc_intelligence.md).
- **Registro de Divergências:** Documentação detalhada das evoluções de engenharia pós-especificação em [`docs/divergencias_e_evolucoes_arquiteturais.md`](docs/divergencias_e_evolucoes_arquiteturais.md).
- **Registro de Uso de IA (`docs/ai_log/`):**
  - [`AGENTS.md`](AGENTS.md): Diretrizes mandatórias de engenharia e regras de governança para agentes de IA.
  - [`docs/ai_log/prompts/`](docs/ai_log/prompts/): Histórico bruto, integral e sequencial dos prompts utilizados.
  - [`docs/ai_log/AGENT_POST_MORTEM.md`](docs/ai_log/AGENT_POST_MORTEM.md): Registro transparente de 12 intervenções do desenvolvedor para corrigir alucinações e desvios do agente.

---

## 9. Licença

Desenvolvido para o Processo Seletivo de Tecnologia da **Lamarck — Sociedade de Advogados**. Uso restrito para fins de avaliação técnica.
