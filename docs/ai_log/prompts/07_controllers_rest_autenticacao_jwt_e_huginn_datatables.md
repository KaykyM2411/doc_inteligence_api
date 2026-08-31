# Prompt 07: Controladores REST, Autenticação JWT, Webhooks Públicos e Datatables com Huginn

**Data:** 31/08/2026  
**Contexto:** Implementação da camada de controladores da API v1, endpoints de autenticação Devise com JWT, webhooks públicos de WhatsApp e E-mail com autenticação dinâmica por configurações ativas do banco, CRUDs e consultas com a gem `huginn_datatable` (ocultando o schema real via `huginn_attributes`), fila de conferência humana com concorrência otimista (`lock_version`) e dashboard de custos.

---

## 1. Prompts Fornecidos / Intenção

> *"O proximo passo é a implementação dos controllers e CRUD das entidades. Preciso que implemente os endpoints de autenticação padroes do devise, os endpoints publicos para os webhooks de eamil e whatsapp em api/v1/webhooks/whatsapp/ e /api/v1/webhooks/email/ respectivamente, nesse endpoints a autenticação vai ser diferente com base nas configurações ativas dos provedores (Pode tem mais de uma configuração ativa. Ex: dois numeros de whasapp ou dois endereços de email diferentes). Ademais, implemente o CRUD/Datatables de clientes e documentos usando a gem huginn-datatable, use o mapeamente de campos que a gem disponibiliza para os filtros, para nao expor o schema real do banco"*
>
> *(Apontamentos e correções do desenvolvedor: "para atributos da propria tabela o correto nao seria so id mesmo ou inves clientes.id?", "nao faça isso de tambem aceitar via variavel de ambiente nao faz sentido", "nesse endpoint e no de estados é melhor usar a gem huggin para paginação e busca, na rota de cidades de um estado no model de cidades voce pode criar um scope por_estado que recebe o id de um estado e filtra as cidaddes dele, ai na hora de chamar o datatable voce faz Cidades.por_estado(id).datatable", "adicione outra porta ao redis, ja tenho um rodando nessa porta", "adicione outr aporta para a api coloque 3002 ja estou usando a 3000")*

---

## 2. Ações Executadas

1. **Autenticação JWT (`Api::V1::Auth::SessionsController`):**
   - Endpoints `/api/v1/auth/login`, `/api/v1/auth/logout` e `/api/v1/auth/me`.
   - Emissão de JWT tanto no header `Authorization: Bearer <token>` quanto no corpo da resposta JSON (`token: "..."`).
   - Revogação de tokens via `JwtDenylist`.

2. **Webhooks Públicos com Autenticação Dinâmica (`Api::V1::Webhooks::*`):**
   - Validação estrita de credenciais diretamente contra os registros ativos no banco (`ConfiguracaoWhatsapp.ativos` e `ConfiguracaoSmtp.ativos`), permitindo múltiplas instâncias simultâneas sem fallbacks indevidos em variáveis de ambiente.
   - Handshake de verificação (`hub.challenge`) para Meta Cloud Graph API.
   - Ingestão automática de anexos de WhatsApp (Evolution API / Meta Cloud) e E-mail (SendGrid Inbound Parse / Postmark JSON) via `Documentos::IngestaoService`.

3. **Mapeamento e Proteção de Schema com `huginn_datatable`:**
   - Inclusão de `Huginn::Datatable` nos models `Cliente`, `Documento`, `Estado` e `Cidade`.
   - Definição de `huginn_attributes` mapeando atributos diretos (`id`, `nome`, `cpf`, `tipo`, `status`) e caminhos relacionais autorizados (`cidade: "enderecos.cidade.nome"`, `estado: "enderecos.cidade.estado.sigla"`, `cliente_nome: "cliente.nome"`), ocultando o schema real do banco de dados.
   - Scope `Cidade.por_estado(id)` para listagens filtradas e paginadas de municípios.

4. **Gestão de Documentos e Fila de Conferência Humana:**
   - `GET /api/v1/documentos/fila_conferencia`: Listagem filtrada de documentos em `necessita_revisao` e `falhou`.
   - `PATCH /api/v1/documentos/:id/revisar`: Endpoint de conferência humana com controle de concorrência otimista via `lock_version` (retornando `409 Conflict` com mensagem amigável em caso de colisão entre operadores), gravação de `revisado_por_id` e `revisado_em`.
   - Upload vinculado direto na ficha do cliente (`POST /api/v1/clientes/:id/documentos`).

5. **Configurações e Dashboard de Auditoria Financeira:**
   - `ProvedoresIaController`: Gerenciamento e alternância atômica do provedor ativo (`POST :id/ativar`).
   - `CustosController`: Agregação de custos em USD, contagem de tokens ($input/output$), tempos de resposta e extrato de histórico de extrações.

6. **Ajuste de Portas de Infraestrutura:**
   - Redis mapeado para a porta do host **`6380`** (`docker-compose.yml`, `config/initializers/sidekiq.rb`, `.env`).
   - Servidor Puma da API configurado para a porta **`3002`** (`config/puma.rb`, `.env`).

---

## 3. Verificação de Resultados

- Suítes de testes em:
  - `spec/requests/api/v1/auth_spec.rb`
  - `spec/requests/api/v1/webhooks_spec.rb`
  - `spec/requests/api/v1/clientes_spec.rb`
  - `spec/requests/api/v1/documentos_spec.rb`
  - `spec/requests/api/v1/estados_e_cidades_spec.rb`
  - `spec/requests/api/v1/configuracoes_e_auditoria_spec.rb`
- **88 testes RSpec passando com 100% de sucesso.**
