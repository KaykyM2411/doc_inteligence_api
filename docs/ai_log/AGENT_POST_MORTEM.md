# Agent Post-Mortem & Registro de Intervenções

Este documento registra os pontos em que o agente de Inteligência Artificial cometeu equívocos, desvios de boas práticas ou decisões inadequadas durante a construção do projeto **DOC Intelligence**, detalhando a detecção e as correções efetuadas pelo engenheiro.

---

## Tabela Resumo de Intervenções

| ID | Fase / Etapa | Erro / Alucinação / Desvio do Agente | Como foi Identificado | Ação Corretiva / Decisão do Engenheiro |
|:---|:---|:---|:---|:---|
| **01** | Modelagem / Migrations | Tentativa de criar os arquivos de migration diretamente via escrita de arquivo manual (`write_to_file`) em `db/migrate/` com timestamps arbitrários | Intervenção direta do engenheiro: *"Nao gere migrations na mao. Use rails g migrations"* | O agente passou a utilizar estritamente a CLI do Rails (`bin/rails g migration <Nome>`) para geração dos esqueletos de migração antes de editar a estrutura |

---

## Detalhamento dos Casos

### Caso 01: Geração Manual de Migrations vs. Rails Generator
- **Contexto:** Inicialização da modelagem de dados e criação das tabelas no PostgreSQL com base na especificação de arquitetura.
- **Desvio do Agente:** O agente tentou criar os arquivos de migração manualmente no diretório `db/migrate/` usando timestamps fictícios/hardcoded, ignorando as boas práticas e convenções do ecossistema Rails.
- **Identificação:** O desenvolvedor identificou a violação de padrão e corrigiu imediatamente a abordagem.
- **Ação Adotada:** Todas as migrações foram geradas usando a CLI nativa (`bin/rails g migration ...` e `bin/rails active_storage:install`), garantindo timestamps precisos e rastreabilidade pelo Rails Active Record.
