# Agent Post-Mortem & Registro de Intervenções

Este documento registra os pontos em que o agente de Inteligência Artificial cometeu equívocos, desvios de boas práticas ou decisões inadequadas durante a construção do projeto **DOC Intelligence**, detalhando a detecção e as correções efetuadas pelo engenheiro.

---

## Tabela Resumo de Intervenções

| ID | Fase / Etapa | Erro / Alucinação / Desvio do Agente | Como foi Identificado | Ação Corretiva / Decisão do Engenheiro |
|:---|:---|:---|:---|:---|
| **01** | Modelagem / Migrations | Tentativa de criar os arquivos de migration diretamente via escrita de arquivo manual (`write_to_file`) em `db/migrate/` com timestamps arbitrários | Intervenção direta do engenheiro: *"Nao gere migrations na mao. Use rails g migrations"* | O agente passou a utilizar estritamente a CLI do Rails (`bin/rails g migration <Nome>`) para geração dos esqueletos de migração |
| **02** | Extração IA / Pricing | Preços de tokens hardcoded nos adaptadores em vez de consulta dinâmica via APIs dos provedores | Apontamento do engenheiro com link para documentação oficial da xAI e OpenRouter | Implementação de consulta dinâmica via API da xAI (`/v1/models/{id}`) e OpenRouter (`/api/v1/models`), com retorno estrito de `0.0` se o modelo não for localizado (sem fallbacks mockados) |
| **03** | Validação de Conteúdo | Falta de validação e sanitização do JSON extraído da LLM via POROs antes de gerar documento e associar cliente | Apontamento do engenheiro sobre a ausência de validação do conteúdo retornado pela LLM | Criação da camada de Schemas PORO em `app/models/esquemas_documento/` com `FactoryEsquemas`, validações e extração de identificadores de clientes |
| **04** | Provedor de IA | Criação de adaptador para Groq em vez de Grok (xAI - Elon Musk) | Esclarecimento do desenvolvedor sobre a ferramenta pretendida | Substituição por `GrokAdapter` conectado à API da xAI (`https://api.x.ai/v1`) |
| **05** | Fluxo de Extração / Pipeline | Schemas PORO criados isoladamente sem serem orquestrados no fluxo de processamento de documentos e associação a clientes | Apontamento do engenheiro: *"voce fez os esquemas, mas eles nao sao chamados em lugar nenhum"* | Criação de `Documentos::ProcessadorDocumentoService` e `ProcessarDocumentoJob` integrando `Adapter IA -> FactoryEsquemas -> Associação de Cliente -> Auditoria` |
| **06** | Arquitetura Hexagonal / Preços | Chamada de cálculo de preços acoplada dentro do adaptador de extração da Grok e service sem Ports & Adapters | Apontamento do engenheiro solicitando Ports & Adapters também no domínio de preços | Criação do módulo `ConsultaPrecos` com `Port`, `Factory`, `PriceResult`, `GrokPricingAdapter`, `OpenrouterPricingAdapter` e `MockPricingAdapter` |
| **07** | Sanitização / EsquemaBase | Lógica de sanitização de números excessivamente complexa e ausência de regex padrão para telefones | Apontamento do engenheiro recomendando regex tradicional `/^(?:55)?(?:([1-9]{2}))?(\d{4,5})(\d{4})$/` | Refatoração em `EsquemaBase` simplificando parsing monetário e adicionando `sanitizar_telefone` com regex padrão |
| **08** | Ingestão / Webhooks Terceiros | Modelagem incorreta de payloads de webhook (SendGrid multipart, Postmark JSON, Evolution API v2 e falta de fluxo em 2 passos na Graph API da Meta) | Apontamento detalhado do engenheiro com especificações oficiais de payload e documentação da Graph API | Refatoração de `SendgridAdapter` (multipart/form), `PostmarkAdapter` (JSON Base64), `EvolutionApiAdapter` (v2 `messages.upsert`) e `MetaCloudAdapter` com download em 2 etapas |

---

## Detalhamento dos Casos

### Caso 01: Geração Manual de Migrations vs. Rails Generator
- **Contexto:** Inicialização da modelagem de dados e criação das tabelas no PostgreSQL com base na especificação de arquitetura.
- **Desvio do Agente:** O agente tentou criar os arquivos de migração manualmente no diretório `db/migrate/` usando timestamps fictícios, ignorando as boas práticas do ecossistema Rails.
- **Ação Adotada:** Todas as migrações foram geradas usando a CLI nativa (`bin/rails g migration ...`), garantindo timestamps precisos e rastreabilidade pelo Rails Active Record.

### Caso 02: Preços Hardcoded vs. Consulta Dinâmica de Preços em Tempo de Execução
- **Contexto:** Cálculo e auditoria de custos de tokens para provedores de IA em `historicos_extracao`.
- **Desvio do Agente:** O agente colocou taxas fixas/hardcoded nos adaptadores, violando a necessidade de precificação dinâmica da API dos provedores.
- **Ação Adotada:**
  1. **Grok (xAI):** Consulta dinâmica via `GET https://api.x.ai/v1/models/{model_id}` lendo `prompt_text_token_price` e `completion_text_token_price`.
  2. **Gemini, OpenAI e OpenRouter:** Consulta dinâmica via catálogo de modelos da API do OpenRouter (`GET https://openrouter.ai/api/v1/models`).
  3. **Zero Fallback:** Se a API externa não responder ou o modelo não estiver listado, o custo retornado é estritamente `0.0`, sem valores inventados.

### Caso 03: Validação Estruturada de Conteúdo por Schemas PORO
- **Contexto:** Garantir integridade e saneamento dos dados extraídos do documento para identificação de clientes e preenchimento de campos.
- **Desvio do Agente:** O agente apenas encapsulou o JSON bruto da LLM sem executar validações de integridade de esquema.
- **Ação Adotada:** Implementação de `EsquemaBase`, `EsquemaRgV1`, `EsquemaCnhV1`, `EsquemaComprovanteResidenciaV1`, `EsquemaContrachequeV1` e `FactoryEsquemas`, garantindo sanitização de CPFs, valores monetários brasileiros e extração normalizada de titulares.

### Caso 04: Provedor Grok (xAI) vs Groq
- **Contexto:** Seleção dos adaptadores suportados na Arquitetura Hexagonal.
- **Desvio do Agente:** Criação de adaptador para Groq API em vez de Grok (xAI).
- **Ação Adotada:** Implementação do `GrokAdapter` com suporte à API multimodal e consulta de modelos da xAI.

### Caso 05: Orquestração do Pipeline e Schemas PORO
- **Contexto:** Consumo da validação de esquemas e amarração ponta a ponta com a entidade `Cliente`.
- **Desvio do Agente:** O agente criou as classes de validação PORO mas não as conectou a um serviço orquestrador de domínio.
- **Ação Adotada:** Criação de `Documentos::ProcessadorDocumentoService` e `ProcessarDocumentoJob`, unificando a extração, validação de integridade por esquema, amarração de cliente por CPF/nome e auditoria no banco.

### Caso 06: Ports & Adapters para Precificação Dinâmica
- **Contexto:** Separação de responsabilidades e desacoplamento na precificação de tokens.
- **Desvio do Agente:** Acoplamento da chamada de API da xAI diretamente no adapter de extração e service procedural para OpenRouter.
- **Ação Adotada:** Aplicação de Arquitetura Hexagonal no domínio `ConsultaPrecos` com `Port`, `Factory`, `GrokPricingAdapter`, `OpenrouterPricingAdapter` e `MockPricingAdapter`.

### Caso 07: Simplificação de Sanitização em EsquemaBase
- **Contexto:** Tratamento de entradas brutas de dados cadastrais.
- **Desvio do Agente:** Criação de lógica complexa desnecessária no parsing numérico em vez de utilizar regex simples e expressivo.
- **Ação Adotada:** Refatoração em `EsquemaBase` com regex tradicional para telefones e sanitização direta para números.

### Caso 08: Contratos Oficiais de Webhooks de Terceiros (SendGrid, Postmark, Evolution API e Meta Cloud)
- **Contexto:** Ingestão de arquivos de e-mail e WhatsApp através de webhooks de provedores externos.
- **Desvio do Agente:**
  1. *SendGrid:* Não realizou o parse completo dos campos `attachment-info` (JSON) e do formulário `multipart/form-data` (`attachment1`, `attachment2`).
  2. *Postmark:* Não tratou campos aninhados `FromFull`/`ToFull` e `Headers` estruturados.
  3. *Evolution API:* Incompatibilidade com o JSON oficial da v2 (`messages.upsert`, `data.key.id`, `data.message.documentMessage.base64`).
  4. *Meta Cloud WhatsApp:* Falta do fluxo obrigatório em duas etapas para obter arquivos da Graph API (Passo 1: consulta `GET /v20.0/{MEDIA_ID}` para obter a URL temporária; Passo 2: download do binário na CDN da Meta exigindo `User-Agent: curl/7.64.1`).
- **Ação Adotada:** Refatoração completa dos adaptadores em `app/services/ingestao_email/` e `app/services/integracao_whatsapp/` para conformidade estrita com os contratos oficiais e implementação do método `download_media_bytes` no `MetaCloudAdapter`.
