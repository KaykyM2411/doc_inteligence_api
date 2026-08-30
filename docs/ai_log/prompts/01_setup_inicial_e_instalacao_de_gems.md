# Prompt 01: Setup Inicial, Dependências e Configuração de Infraestrutura

**Data:** 30/08/2026  
**Contexto:** Preparação do ambiente de desenvolvimento, definição de gems e configuração de contêineres e inicializadores do Rails 8.

---

## 1. Prompt Fornecido / Intenção

> "antes de iniciar efetivamente o desenvolvimento preciso que analise a minha proposta de desenvolvimento e as configurações necessarias para implementala, adicione gems que vao ser necessarias (vou usar devise-jwt) tambem vai ser necessesario usar sidekiq entao precisa do redis, configureo no meu meu docker-compose.yml"
>
> *"para paginação adicione a gem huginn-datatable https://rubygems.org/gems/huginn_datatable ela é de minha autoria"*

---

## 2. Ações Executadas

1. **Docker Compose:**
   - Adição do serviço `redis:7-alpine` mapeado na porta `6379:6379` com volume nomeado `redis_data` em `docker-compose.yml`.
   - Inicialização dos contêineres de banco de dados (`postgres:16-alpine`) e cache/fila (`redis:7-alpine`).

2. **Gerenciamento de Dependências (`Gemfile`):**
   - **Autenticação:** `devise` e `devise-jwt`.
   - **Background Jobs & Cache:** `sidekiq` e `redis`.
   - **Paginação:** `huginn_datatable`.
   - **HTTP & Integrações:** `faraday` e `rack-cors`.
   - **Ambiente & Testes:** `dotenv-rails`, `rspec-rails`, `factory_bot_rails`, `faker`, `webmock`, `database_cleaner-active_record`.
   - Execução de `bundle install`.

3. **Configuração de Inicializadores:**
   - `config/initializers/sidekiq.rb`: Conexão configurada para o Redis local (`redis://localhost:6379/1`).
   - `config/application.rb`: `config.active_job.queue_adapter = :sidekiq`.
   - `config/initializers/cors.rb`: Habilitado para requisições de clientes internos / front-end com exposição de cabeçalho `Authorization`.
   - `config/initializers/devise.rb`: Configuração de rotas de dispatch/revocation JWT (`/api/v1/auth/login` e `/api/v1/auth/logout`) e `navigational_formats = []`.
   - Setup inicial do RSpec com carregamento de helpers e `FactoryBot::Syntax::Methods`.

---

## 3. Verificação de Resultados

- `bundle install` finalizado com sucesso.
- Containers `doc_inteligence_api_development` e `doc_inteligence_api_redis` ativos.
- RSpec inicializado e configurado.
