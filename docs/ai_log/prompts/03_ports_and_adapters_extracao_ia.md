# Prompt 03: Arquitetura Hexagonal — Ports & Adapters para Extração com IA

**Data:** 30/08/2026 – 31/08/2026  
**Contexto:** Implementação da camada desacoplada de comunicação com múltiplos provedores de IA multimodal (Grok da xAI, OpenAI, Gemini, OpenRouter, Ollama e Mock) utilizando o padrão Ports & Adapters.

---

## 1. Prompt Fornecido / Intenção

> "O proximo passo é fazer os ports e adapters para comunicação com a ia faça os adapters do provedores de ia especificados no documento, siga o padrao arquitetural da arquitetura hexagonal especificado"
>
> *(Instruções adicionais: "cara no padrao de projeto pode usar ports e adapters, nao precisa usar tudo em portugues", "chame factory e ports e adapters", "chame de port.rb")*

---

## 2. Ações Executadas

1. **Definição da Porta Base (`app/services/extracao_ia/port.rb`):**
   - Criação da interface abstrata `ExtracaoIa::Port` contendo os contratos `#provider_name`, `#model_name`, `#extract`, `#calculate_estimated_cost` e helpers para codificação Base64 e medição de latência.

2. **Criação do Value Object de Retorno (`app/services/extracao_ia/extraction_result.rb`):**
   - Padronização dos retornos de extração com status de sucesso, tokens de entrada/saída, tempo de resposta em ms, custo financeiro em USD e método auxiliar `requires_review?`.

3. **Prompt Estruturado Versionado (`app/services/extracao_ia/default_prompt.rb`):**
   - Criação do `DefaultPrompt::VERSION = "v1.0"` focado em documentos jurídicos e cadastrais brasileiros (RG, CNH, Comprovante de Residência, Contracheque).

4. **Implementação dos Adaptadores Concretos (`app/services/extracao_ia/adapters/`):**
   - `MockAdapter`: dublê determinístico offline para desenvolvimento e testes.
   - `GrokAdapter`: integração oficial com a API da xAI (`https://api.x.ai/v1`).
   - `OpenaiAdapter`: integração com modelos multimodais GPT-4o e GPT-4o-mini.
   - `GeminiAdapter`: integração REST com a API do Google Gemini (1.5/2.0 Flash e Pro).
   - `OpenrouterAdapter`: roteamento multimodal via gateway OpenRouter.
   - `OllamaAdapter`: execução local on-premise com modelos open-source.

5. **Fábrica de Adaptadores (`app/services/extracao_ia/factory.rb`):**
   - `ExtracaoIa::Factory.active_adapter`: instanciação dinâmica baseada no registro ativo em `ConfiguracaoProvedorIa` com fallback para `MockAdapter`.

6. **Configuração de Criptografia:**
   - Criação de `config/initializers/active_record_encryption.rb` para armazenamento e leitura segura de API keys.

---

## 3. Verificação de Resultados

- Criação de suíte de testes RSpec em `spec/services/extracao_ia/factory_and_adapters_spec.rb` cobrindo a Factory e todos os adaptadores de IA com mocks via `WebMock`.
- 100% dos testes passando com sucesso.
