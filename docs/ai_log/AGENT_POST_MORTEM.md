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
| **09** | Huginn Datatables / Aliases | Mapeamento de atributos próprios da tabela em `huginn_attributes` com prefixo da tabela (`clientes.id` em vez de `id`) | Apontamento do engenheiro: *"para atributos da propria tabela o correto nao seria so id mesmo ao inves de clientes.id?"* | Refatoração dos mapeamentos nos models para colunas diretas (`id`, `nome`, `cpf`) e caminhos encadeados apenas para associações |
| **10** | Webhooks / Autenticação Dinâmica | Aceitar credenciais de webhooks de variáveis de ambiente em vez de validar estritamente no banco | Intervenção direta do engenheiro: *"nao faça isso de tambem aceitar via variavel de ambiente nao faz sentido"* | Remoção total dos fallbacks de ENV e validação estrita baseada nas instâncias ativas cadastradas no banco (`ConfiguracaoWhatsapp.ativos` e `ConfiguracaoSmtp.ativos`) |
| **11** | Estados e Cidades / Huginn | Endpoints geográficos com paginação simples e busca manual `LIKE` em vez de usar `huginn_datatable` | Apontamento do engenheiro orientando o uso do Datatable e criação de scope `por_estado` | Inclusão de `Huginn::Datatable` em `Estado` e `Cidade` e uso de `Cidade.por_estado(id).datatable(params)` no controller |
| **12** | Autenticação / Token no Body | Retorno do token JWT apenas nos cabeçalhos HTTP (`Authorization`), sem incluir no corpo do JSON da resposta de login | Apontamento do engenheiro durante teste com cURL: *"nao retornou token"* | Inclusão explícita do campo `token: "..."` no corpo da resposta JSON do `SessionsController#create` |

---

## Detalhamento dos Casos Recentes

### Caso 09: Nomenclatura em `huginn_attributes`
- **Contexto:** Definição dos aliases públicos para ocultar o schema real do banco na gem `huginn_datatable`.
- **Desvio do Agente:** O agente adicionou o prefixo da própria tabela nos atributos diretos (ex: `id: "clientes.id"`), contrariando a convenção de colunas simples do validador da gem.
- **Ação Adotada:** Ajuste em todos os models (`Cliente`, `Documento`, `Estado`, `Cidade`) mantendo colunas diretas como strings simples (`"id"`, `"nome"`) e prefixos encadeados apenas para relacionamentos (`"enderecos.cidade.nome"`).

### Caso 10: Autenticação Estrita de Webhooks via Banco de Dados
- **Contexto:** Validação de segurança em endpoints públicos de webhooks de terceiros (WhatsApp e E-mail) onde o escritório possui múltiplos números e caixas ativas.
- **Desvio do Agente:** O agente adicionou fallbacks em variáveis de ambiente (`ENV["WHATSAPP_SYSTEM_USER_TOKEN"]`), quebrando a premissa de múltiplas instâncias dinâmicas.
- **Ação Adotada:** Validação estrita e dinâmica exclusivamente contra `ConfiguracaoWhatsapp.ativos` e `ConfiguracaoSmtp.ativos`.

### Caso 11: Padronização de Estados e Cidades com Huginn Datatable
- **Contexto:** Fornecimento de endpoints geográficos para dropdowns e filtros paginados da interface.
- **Desvio do Agente:** Criação de queries manuais simples em vez de aplicar a padronização do `huginn_datatable`.
- **Ação Adotada:** Inclusão de `Huginn::Datatable` em `Estado` e `Cidade` com o scope `Cidade.por_estado(id)` e consumo padronizado nos controllers.

### Caso 12: Disponibilização do Token JWT no JSON de Login
- **Contexto:** Facilidade de integração de clientes REST, SPAs e testes de API.
- **Desvio do Agente:** O Devise-JWT por padrão despacha o token apenas no cabeçalho `Authorization`, dificultando a leitura em clientes que esperam o token no JSON.
- **Ação Adotada:** O `SessionsController#create` foi enriquecido para expor o token JWT diretamente no payload JSON (`token: "..."`) além do cabeçalho HTTP.
