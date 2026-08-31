# Prompt 04: Schemas PORO, Precificação Dinâmica Hexagonal e Orquestração do Pipeline

**Data:** 31/08/2026  
**Contexto:** Criação da camada de validação estruturada com PORO Schemas, aplicação do padrão Ports & Adapters no domínio de consulta de preços e orquestração do pipeline de extração com vinculação de clientes.

---

## 1. Prompts Fornecidos / Intenção

> *"Notei detalhes importantes onde voce falhou. 1 voce nao esta validando em nada o conteudo que a llm extraiu, o conteudo precisa ser validado para ser gerado um documento com o conteudo e buscar com o cliente certo, atualmente nao esta fazendo isso. Outra coisa voce hardcodou o preço de cada modelo, isso nao faz sentido nenhum. os preços devem ser obtidos dinamicamente pela api do proprio provedor com base no modelo escolhido. https://docs.x.ai/developers/rest-api-reference/inference/models#get-model no da grook ai tem a documentação eles usam o endpoint /v1/models/{model_id} ... e o provider nao é a 'grog' quero adicionar o adpter da 'grok' do elon musk. do gemini nao disponibilizam preços em sua propria api use o da openrouter filtrando pelo modelo do gemini de la ... da openai pode fazer o mesmo tambem nao disponibilizam endpoint oficial para consulta de valores"*
>
> *"tenho alguns apontamentos para fazer. voce fez os esquemas, mas eles nao sao chamdos em lugar nenhum eles precisam ser usados, segundo voce fez uma sanitização enorme para o numero no esquema_base.rb nao entendi o porque, use apenas um regex tradicional para numeros de celular const regex = /^(55)?(?:([1-9]{2})?)(\d{4,5})(\d{4})$/; (exemplo, pode adaptar para gsub), terceiro voce chamou o calculo de preços da grok diretamente dentro do adapter de extração, quero que siga o padrao da arquitetura hexasgonal e aplique pots and adapters nessa implementação tambem (ajuste a consulta de preços do openrouter tambem, apesar de estar separada em um service nao segue o padrao da arquitetura hexagonal)"*

---

## 2. Ações Executadas

1. **Camada de Schemas PORO (`app/models/esquemas_documento/`):**
   - `EsquemaBase`: sanitização de CPFs, strings, datas e regex tradicional para telefones (`sanitizar_telefone`).
   - `EsquemaRgV1`, `EsquemaCnhV1`, `EsquemaComprovanteResidenciaV1`, `EsquemaContrachequeV1`: validações de presença/regras de negócio e métodos `nome_cliente` / `cpf_cliente`.
   - `FactoryEsquemas`: factory para instanciar o schema com base no tipo e versão.

2. **Domínio de Precificação em Ports & Adapters (`app/services/consulta_precos/`):**
   - `ConsultaPrecos::Port`: interface abstrata com `#fetch_price` e `#calculate_cost`.
   - `ConsultaPrecos::PriceResult`: value object com taxas por token.
   - `ConsultaPrecos::Adapters::GrokPricingAdapter`: consulta dinâmica via `GET https://api.x.ai/v1/models/{model_id}`.
   - `ConsultaPrecos::Adapters::OpenrouterPricingAdapter`: consulta dinâmica via catálogo `GET https://openrouter.ai/api/v1/models` (utilizado para OpenRouter, OpenAI e Gemini).
   - `ConsultaPrecos::Adapters::MockPricingAdapter`: retorno estrito de `0.0` para Mock e Ollama.
   - `ConsultaPrecos::Factory`: fábrica mapeando o provedor ao adaptador de precificação.
   - **Zero Fallback:** se a API externa não localizar o modelo, o custo retornado é estritamente `0.0`.

3. **Orquestração do Pipeline de Extração (`app/services/documentos/processador_documento_service.rb`):**
   - Fluxo completo integrado:
     1. Disparo de extração multimodal via `ExtracaoIa::Port`.
     2. Validação e sanitização de dados pelo schema PORO (`FactoryEsquemas`).
     3. Associação automática com o `Cliente` (busca por CPF -> fallback por Nome).
     4. Classificação de status (`:processado` se válido e confiança $\ge 0.85$, ou `:necessita_revisao`).
     5. Registro de auditoria em `historicos_extracao`.
   - Criação do background job `ProcessarDocumentoJob` para execução assíncrona com Sidekiq.

4. **Registro de Auditoria:**
   - Documentação detalhada dos Casos 02 a 07 em `docs/ai_log/AGENT_POST_MORTEM.md`.

---

## 3. Verificação de Resultados

- Suítes de testes em:
  - `spec/services/extracao_ia/factory_and_adapters_spec.rb`
  - `spec/services/consulta_precos/factory_and_adapters_spec.rb`
  - `spec/models/esquemas_documento/factory_esquemas_spec.rb`
  - `spec/services/documentos/processador_documento_service_spec.rb`
- Execução do RSpec com 37 exemplos e 0 falhas (100% de cobertura nos serviços e adaptadores).
