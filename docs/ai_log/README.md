# Registro de Auditoria de Uso de IA (`ai_log`)

Este diretório contém o registro formal e transparente de todo o ciclo de vida do desenvolvimento assistido por Inteligência Artificial no projeto **DOC Intelligence**, em conformidade com as diretrizes do Desafio Técnico.

---

## Estrutura do Diretório

```text
docs/ai_log/
├── README.md                # Este documento explicativo
├── AGENT_POST_MORTEM.md     # Registro de erros, alucinações da IA e correções humanas
└── prompts/                 # Histórico cronológico e bruto de todos os prompts utilizados
    ├── 01_setup_inicial_e_instalacao_de_gems.md
    ├── 02_modelagem_de_dados_migrations_e_schema.md
    ├── 03_ports_and_adapters_extracao_ia.md
    ├── 04_esquemas_poro_e_precificacao_dinamica_hexagonal.md
    ├── 05_data_migrations_com_data_migrate.md
    ├── 06_ingestao_de_documentos_magic_bytes_e_webhooks.md
    └── 07_controllers_rest_autenticacao_jwt_e_huginn_datatables.md
```

---

## Diretrizes de Auditoria

1. **Prompts Brutos e Fidedignos:**
   - Todo prompt executado é registrado na íntegra na pasta `prompts/`, mantendo a ordem sequencial (`01_...`, `02_...`, etc.).
   - Os prompts registram a intenção técnica, restrições passadas ao agente e a verificação do resultado produzido.
   - Nenhuma alteração cosmética posterior deve mascarar a real interação ocorrida entre o engenheiro e o agente.

2. **Rastreabilidade de Falhas (`AGENT_POST_MORTEM.md`):**
   - Onde o modelo cometeu equívocos (ex: suposições erradas sobre o schema, alucinações de bibliotecas, falha de tipagem ou concorrência).
   - Como o desenvolvedor identificou a falha (inspeção de código, falha de testes, checagem estática).
   - Qual intervenção técnica foi adotada para corrigir a rota.

3. **Governança do Agente (`AGENTS.md`):**
   - Diretrizes mandatórias para qualquer agente autônomo ou assistente de código atuando neste repositório.
   - Consulta mandatória aos documentos em `docs/` antes de qualquer alteração estrutural ou de código.
