# Prompt 05: Data Migrations com Gem `data_migrate` (Estados, Cidades, Admin e Provedores IA)

**Data:** 31/08/2026  
**Contexto:** Instalação da gem `data_migrate` (11.3.1) e criação de migrações de dados versionadas para popular a base geográfica brasileira (IBGE), usuário administrador e provedores de IA.

---

## 1. Prompt Fornecido / Intenção

> "agora quero a gem https://rubygems.org/gems/data_migrate/versions/11.3.1 para criar migrations de dados ao inves de jogar tudo no seeds.rb. Quero criar a migração para popular cidades/eestados para essa quero que use esse repositorio do github onde ele mapeou todos os estados e cidades, ele colocou mais dados que vamos usar entao faça o mapeamento para a nossa estrutura, criação de um usuario administrador, e quero popular os provedores de ia, popule os provedores que criamos os adapters. Para todos as migrations use a gem que informei"

---

## 2. Ações Executadas

1. **Instalação da Gem `data_migrate` (`11.3.1`):**
   - Adicionada ao `Gemfile` e executado `bundle install`.

2. **Criação de Data Migrations (`db/data/`):**
   - `20260831063410_popular_estados_e_cidades.rb`:
     - Leitura e mapeamento dos 27 Estados brasileiros e 5.571 Municípios via JSON oficial do IBGE.
     - Inserção em lote (`insert_all`) em `estados` e `cidades` com tratamento de encoding e fallback local em `db/data_sources/`.
   - `20260831063438_criar_usuario_administrador.rb`:
     - Criação do usuário administrador padrão (`admin@lamarck.adv.br`).
   - `20260831063547_popular_configuracoes_provedores_ia.rb`:
     - Cadastro e inicialização dos 6 provedores suportados (`grok`, `openai`, `gemini`, `openrouter`, `ollama`, `mock`), com `grok` ativo por padrão.

3. **Execução das Migrações de Dados:**
   - Executado `bin/rails data:migrate`, gerando `db/data_schema.rb` e persistindo os registros no PostgreSQL.

---

## 3. Verificação de Resultados

- `Estado.count` = 27
- `Cidade.count` = 5.571
- `Usuario.count` = 1 (`admin@lamarck.adv.br`)
- `ConfiguracaoProvedorIa.count` = 6 (`grok` ativo)
- 38 testes RSpec passando com 100% de sucesso.
