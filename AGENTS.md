# Diretrizes de Engenharia e Instruções para Agentes de IA (`AGENTS.md`)

Este arquivo contém as instruções mandatórias, padrões de arquitetura e regras de engenharia para qualquer Agente de IA (Antigravity, Claude Code, Copilot, Cursor, etc.) atuando no repositório **DOC Intelligence**.

---

## 1. Documentos Canônicos de Consulta Obrigatória

Antes de propor, planejar, gerar ou alterar qualquer código, modelagem ou teste, o agente **DEVE OBRIGATORIAMENTE** ler e se ater integralmente aos dois documentos mestres em `docs/`:

1. **[docs/especificacao_e_arquitetura_doc_intelligence.md](file:///home/kaykym/doc_inteligence_api/docs/especificacao_e_arquitetura_doc_intelligence.md):**
   - Especificação técnica, contratos de dados, regras de negócio e fluxos assíncronos.
   - Modelo relacional de dados com schema estritamente em português (`usuarios`, `estados`, `cidades`, `clientes`, `enderecos`, `documentos`, `historicos_extracao`, `configuracoes_provedor_ia`, `configuracoes_whatsapp`, `configuracoes_smtp`, `notificacoes`).
   - Índices parciais de idempotência de eventos e deduplicação por SHA-256 no PostgreSQL.
   - Arquitetura Hexagonal com Ports & Adapters por domínio (`app/services/...`).
   - Validações dinâmicas de esquemas de documentos com POROs (`app/models/esquemas_documento/...`).

2. **[docs/desafio_tecnico_especificacao.md](file:///home/kaykym/doc_inteligence_api/docs/desafio_tecnico_especificacao.md):**
   - Requisitos e premissas de negócio do Desafio Técnico (Lamarck — Sociedade de Advogados).
   - **Fatos do Ambiente:** latência de IA (5-40s), instabilidade de terceiros, ausência de validação no upload de origem, reenvio frequente de duplicatas, LGPD/dados sensíveis, picos concentrados de tráfego, versionamento contínuo de modelos/prompts, e concorrência na fila de conferência por múltiplos atendentes simultâneos.
   - Critérios de avaliação focados em modularidade, rastreabilidade de decisões e uso controlado de IA como ferramenta de engenharia.

---

## 2. Padrões de Arquitetura e Engenharia

### 2.1 Modelo e Schema de Dados
- **Nomenclatura em Português:** Todas as tabelas, colunas, models e enums do domínio de negócio utilizam português (ex: `documentos`, `dados_extraidos`, `score_confianca`, `sha256_arquivo`, `origem`, `status`).
- **Chaves Primárias UUID:** Todas as tabelas principais utilizam `id` como `UUID` nativo do PostgreSQL (com exceção de tabelas estáticas/geográficas como `estados` e `cidades` que utilizam `BIGSERIAL`).
- **Integridade no Banco:**
  - Idempotência de ingestão: constraint única parcial `(origem, referencia_origem) WHERE referencia_origem IS NOT NULL`.
  - Deduplicação por hash: constraint única parcial `(cliente_id, sha256_arquivo) WHERE cliente_id IS NOT NULL`.
  - Concorrência otimista: campo `lock_version` na tabela `documentos` para evitar sobrescrita por múltiplos atendentes na fila de conferência.
- **Segurança e Criptografia:** Credenciais de provedores externos (`API keys`, tokens) armazenadas com criptografia de aplicação usando `ActiveRecord::Encryption`.

### 2.2 Arquitetura Hexagonal (Ports & Adapters)
- **Desacoplamento Total:** O core da aplicação nunca deve depender de APIs externas diretamente.
- Todo domínio externo deve seguir a estrutura:
  - `porta.rb`: Interface base com métodos abstratos exigidos.
  - `fabrica.rb`: Responsável por instanciar o adaptador correto com base na configuração ativa do banco.
  - `adaptadores/adaptador_*.rb`: Implementação concreta do provedor (Groq, OpenAI, Gemini, OpenRouter, Ollama, Mock, Evolution API, SendGrid, etc.).
- O adaptador de IA deve calcular/consultar dinamicamente os custos de tokens ($input/output$) e tempo de resposta para alimentar a auditoria em `historicos_extracao`.

### 2.3 Processamento Assíncrono e Fatia Vertical
- Processamento pesado de extração e classificação deve ser executado em background jobs (`ProcessarDocumentoJob`).
- A fatia vertical do sistema deve cobrir o fluxo completo ponta a ponta:
  `Upload / Webhook -> Idempotência/Sanitização -> Persistência Inicial -> Job Assíncrono -> Adapter IA -> Validação PORO -> Associação de Cliente -> Auditoria -> Conclusão/Revisão`.

---

## 3. Gestão e Auditoria de Prompts (`docs/ai_log/`)

O projeto mantém transparência absoluta no uso de IA para engenharia:

1. **Adição de Prompts:** Quando o usuário fornecer/solicitar a gravação de um prompt, ele deve ser gravado de forma bruta e numerada sequencialmente em `docs/ai_log/prompts/` (ex: `01_setup_inicial_e_migrations.md`, `02_modelagem_documentos_e_sha256.md`, etc.).
2. **Post-Mortem de Agente:** Se o agente cometer qualquer alucinação técnica, quebra de contrato ou desvio de arquitetura detectado e corrigido pelo desenvolvedor, o caso deve ser registrado em `docs/ai_log/AGENT_POST_MORTEM.md`.

---

## 4. Regras de Conduta para o Agente

- ❌ **NÃO invente novos campos ou tabelas** que conflitem com a modelagem descrita em `docs/especificacao_e_arquitetura_doc_intelligence.md`.
- ❌ **NÃO acople chamadas HTTP de IA ou webhooks diretamente nos controllers ou jobs** sem passar pela camada de Ports & Adapters.
- ❌ **NÃO silencie erros de terceiros ou falhas de parse**; registre falhas com `status: :falhou` ou `status: :necessita_revisao` e grave a resposta bruta em `historicos_extracao`.
- ✅ **SEMPRE valide o código contra os fatos do ambiente** descritos no desafio técnico.
- ✅ **SEMPRE mantenha o código limpo, modular, documentado e coberto por testes automatizados**.
