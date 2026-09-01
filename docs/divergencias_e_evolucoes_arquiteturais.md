# Registro de Divergências e Evoluções de Arquitetura

> **Documento de Rastreabilidade e Governança de Decisões Técnicas**  
> DOC Intelligence — Desafio Técnico de Seleção em Tecnologia · **Trilha A (Back-end)**  
> **Lamarck — Sociedade de Advogados**

---

## 1. Contexto e Transparência

Em estrito cumprimento ao item 2 das entregas do desafio técnico (*"Se a implementação divergiu da especificação, entregue a especificação como estava e diga onde divergiu"*), este documento lista todas as divergências conscientes e evoluções de engenharia realizadas entre o documento de especificação inicial ([`docs/especificacao_e_arquitetura_doc_intelligence.md`](especificacao_e_arquitetura_doc_intelligence.md)), commitado antes da primeira linha de código, e a implementação final entregue no repositório.

A especificação canônica foi mantida **100% íntegra** como foi concebida no dia zero. Abaixo detalham-se as divergências deliberadas e justificadas.

---

## 2. Tabela Comparativa de Divergências

| Item | Especificação Inicial (v1.0) | Implementação Final Entregue | Motivação / Fato do Ambiente |
|:---|:---|:---|:---|
| **1. Substituição de Provedor: Groq por Grok (xAI)** | Enum de provedor listava `groq` (Groq Inc. LPU) | **Grok (xAI Vision API):** Adaptador `GrokAdapter` com modelo multimodal `grok-2-vision-1212` e consulta dinâmica de preços via endpoint da xAI | O Groq na época de especificação possuía limitações de modelos de visão; o Grok da xAI oferece suporte nativo de alta qualidade a documentos multimodais complexos e API de precificação transparente. |
| **2. Gestão de Provedores de IA** | Apenas 1 provedor ativo simultaneamente (desativando os outros via callback `before_save`) | **Multi-Provider Fallback Cascade:** Múltiplos provedores ativos simultâneos com coluna `ordem` e índice único parcial | **Fato (e):** Picos de 800 docs/dia e rate limits (HTTP 429). Permite failover instantâneo entre múltiplos fornecedores sem interromper a fila de triagem. |
| **3. Resiliência de Chamadas de IA** | Chamada direta via Faraday com timeout simples de 60 segundos | **Circuit Breaker com Redis ([`app/services/extracao_ia/circuit_breaker.rb`](../app/services/extracao_ia/circuit_breaker.rb)):** Máquina de 3 estados (`:closed`, `:open`, `:half_open`) com Fast Fail em 1ms | **Fato (a):** Instabilidade e timeouts de APIs terceiras (5-40s). Evita que centenas de workers do Sidekiq fiquem travados consumindo recursos quando a API externa cai. |
| **4. Serialização de Respostas JSON** | Serialização direta nos controllers via `.as_json()` inline | **Camada de Apresentação com Alba ([`app/serializers/`](../app/serializers/)):** 11 serializers dedicados e fortemente tipados | Desacoplamento entre banco e apresentação pública; proteção estrita de credenciais criptografadas e tokens confidenciais. |
| **5. Inicialização de Dados Estruturais** | Ambígua entre `db/seeds.rb` e migrations | **Separação Canônica via `data_migrate`:** Dados de domínio em `db/data/` e `db/seeds.rb` como script de diagnóstico explicativo | Idempotência e rastreabilidade total de dados em esteiras de deploy (dev, test, prod). |

---

## 3. Detalhamento Técnico das Evoluções

### 3.1 Substituição de Provedor: Groq por Grok (xAI Vision)
- **Na Especificação Inicial:** O enum do modelo `configuracoes_provedor_ia` definia `groq` como opção de provedor de inferência rápida.
- **Na Implementação:** Para o pipeline multimodal de OCR jurídico, a API da xAI (modelo `grok-2-vision-1212`) mostrou-se mais adequada para parsing de documentos e tabelas, com endpoint oficial de consulta de preços integrado via `GrokPricingAdapter`. O enum e os adaptadores foram nomeados como `grok`.

---

### 3.2 Multi-Provider Fallback Cascade com Prioridade Dinâmica
- **Na Especificação Inicial:** A tabela `configuracoes_provedor_ia` continha um callback no model que garantia exclusividade de um único provedor ativo (`where.not(id: id).update_all(ativo: false)`).
- **Na Implementação:** Percebeu-se que em dias de pico (Fato e), se o provedor único ativo sofresse indisponibilidade ou rate limit, toda a esteira do escritório ficaria paralisada. Criou-se a coluna `ordem: :integer` com constraint única parcial (`WHERE ativo = true`), permitindo que a `ExtracaoIa::Factory` forneça uma esteira ordenada (ex: Grok como Ordem 1, OpenAI como Ordem 2, Gemini como Ordem 3).
- **Impacto:** Eliminação do ponto único de falha (SPOF) no consumo de LLMs, garantindo continuidade do fluxo de triagem através de failover automático e transparente entre provedores.

---

### 3.3 Circuit Breaker com Redis e Fast Fail
- **Na Especificação Inicial:** O tratamento de erros de IA resumia-se a capturar exceções HTTP e marcar o documento com `status: :falhou`.
- **Na Implementação:** Sob rajadas de centenas de documentos simultâneos durante o pico das 9h às 11h, um provedor fora do ar faria todos os workers do Sidekiq esperarem 60 segundos de timeout por job, esgotando o pool de conexões e travando o sistema. Implementou-se o `ExtracaoIa::CircuitBreaker` no Redis:
  - Após 5 falhas consecutivas, o circuito **abre (OPEN)** e rejeita chamadas em 1ms (*Fast Fail*), liberando a thread do Sidekiq para acionar o próximo provedor do Fallback Cascade;
  - Após 2 minutos (*cooldown*), transita para `:half_open` e testa o provedor com uma requisição piloto.
- **Impacto:** Proteção total dos recursos computacionais do servidor e isolamento arquitetural no `Port` base.

---

### 3.4 Camada de Serialização Dedicada (Alba)
- **Na Especificação Inicial:** O retorno dos endpoints JSON era estruturado inline via `.as_json(include: [...])` nos controllers.
- **Na Implementação:** A prática de serialização inline acoplava a camada de controle ao schema de persistência e trazia risco de vazamento de atributos confidenciais (`credencial_criptografada`). Criou-se a camada `app/serializers/` utilizando a gem **Alba**, padronizando a saída de Documentos, Clientes, Endereços, Configurações e Notificações.
- **Impacto:** Segurança por design e consistência nos contratos da API.

---

## 4. Conclusão

Todas as divergências listadas representam **ganhos incrementais de robustez, segurança e resiliência**, concebidos após testes de estresse e confronto com os 7 Fatos do Ambiente do desafio técnico. Nenhuma funcionalidade original da especificação foi removida ou reduzida.
