# Prompt 06: Ingestão de Documentos, Magic Bytes, SHA-256, Early Idempotency e Ports & Adapters para Webhooks (WhatsApp & E-mail)

**Data:** 31/08/2026  
**Contexto:** Implementação do serviço central de ingestão de documentos com sanitização binária por Magic Bytes, deduplicação SHA-256 por cliente, Early Idempotency para webhooks, suporte a upload com `cliente_id` opcional e Ports & Adapters estritamente alinhados aos contratos oficiais de e-mail (SendGrid Inbound Parse, Postmark) e WhatsApp (Evolution API v2, Meta Cloud WhatsApp Business com download em 2 etapas).

---

## 1. Prompts Fornecidos / Intenção

> *"Agora a proxima etapa é a ingestao de documentos via webhooks de terceiros, seguindo o protocolo descrito na arquitetura do projeto, calculo de hash para nao duplicar documentos, validação do arquivo com Magic Bytes, idepotencia do webhook, e o service de pode receber coo parametro opcional o id do cliente(fluxo de criação de documento diretamente na ficha do cliente). Toda essa parte deve seguir o mesmo padrao que adotamos ate agora da arquitetura hexagonal. Para os servicos de email quero que faça os adapters para o SendGrip e Postmarl e para whatsapp para o Evolution API e a api oficial da meta. Aqui esta as documentações oficiais de cada provedor: https://www.twilio.com/docs/sendgrid/for-developers/tracking-events/event https://postmarkapp.com/developer/webhooks/webhooks-overview https://docs.evolutionfoundation.com.br/evolution-go/webhooks https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/overview"*
>
> *(Correção dos contratos oficiais: "Encontrei inconsistencias na sua implementação: primeiro o recebimento de webhooks do sendgrip esta errado, como vamos precisar receber o arquivo é necessario usar o Inbound Parse Webhook, que tem esse payload: O SendGrid envia uma requisição HTTP POST com o cabeçalho Content-Type: multipart/form-data ... o Postmark tambem esta errado, ao contrario do sendgrip que devolve em multpart o postmark devolve tudo em json seguindo esse padrao ... O adapter do evolutionapi tambem esta errado esse é o modelo de payload que eles ennviam ... E na api oficial da meta tambem esta errado e o fluxo precisa ser realizado em duas etapas: 1. Estrutura do Payload Recebido via Webhook ... 3. Como Baixar o Arquivo (Fluxo Obrigatório em 2 Passos) ... Passo 1: Obter a URL temporária de download ... Passo 2: Baixar o binário do arquivo ... Headers obrigatórios: Authorization: Bearer <SEU_WHATSAPP_SYSTEM_USER_TOKEN> User-Agent: curl/7.64.1")*

---

## 2. Ações Executadas

1. **Validador de Magic Bytes (`app/services/documentos/validador_arquivo.rb`):**
   - Reconhecimento de assinaturas binárias de PDF (`%PDF-`), JPEG (`\xFF\xD8\xFF`), PNG (`\x89PNG\r\n\x1A\n`) e WebP (`RIFF...WEBP`).
   - Bloqueio e rejeição de executáveis maliciosos (`MZ...`) e arquivos corrompidos.

2. **Serviço de Ingestão de Documentos (`app/services/documentos/ingestao_service.rb`):**
   - **Early Idempotency:** Checagem prévia por `(origem, referencia_origem)`, retornando o documento existente com `duplicado: true` e `idempotente: true` sem duplicar jobs ou processamento.
   - **Validação de Magic Bytes:** Bloqueio de arquivos não suportados.
   - **Cálculo de SHA-256:** `Digest::SHA256.hexdigest(bytes)`.
   - **Deduplicação por Cliente:** Verificação de duplicata de mesmo hash para o cliente quando `cliente_id` é informado.
   - **Persistência com ActiveStorage** e enfileiramento de `ProcessarDocumentoJob.perform_later(documento.id)` com Sidekiq.

3. **Ports & Adapters de E-mail (`app/services/ingestao_email/`):**
   - `Port`, `Factory`, `EmailMessage`, `EmailAttachment`.
   - `SendgridAdapter`: Suporte integral ao SendGrid Inbound Parse multipart/form-data com `attachment-info` (JSON), campos indexados `attachmentX` e extração de `Message-ID` nos headers RFC 822.
   - `PostmarkAdapter`: Suporte ao Postmark Inbound JSON com decodificação Base64 de `Attachments`, campos `From`/`FromFull` e `Headers`.
   - `MockEmailAdapter`: Dublê determinístico.

4. **Ports & Adapters de WhatsApp (`app/services/integracao_whatsapp/`):**
   - `Port`, `Factory`, `WhatsappMessage`, `WhatsappMedia`.
   - `EvolutionApiAdapter`: Payload oficial `messages.upsert` (v2) com extração de `data.key.id`, `data.key.remoteJid`, `data.message.documentMessage.base64` / `imageMessage.base64`.
   - `MetaCloudAdapter`: Suporte ao payload oficial da Meta Cloud WhatsApp Business API e implementação do **fluxo mandatório em 2 passos** (`download_media_bytes`) consultando a Graph API (`GET /v20.0/{MEDIA_ID}`) e baixando o binário na CDN da Meta com `User-Agent: curl/7.64.1`.
   - `MockWhatsappAdapter`: Dublê determinístico.

5. **Auditoria e Post-Mortem:**
   - Registro do Caso 08 em `docs/ai_log/AGENT_POST_MORTEM.md`.

---

## 3. Verificação de Resultados

- Suítes de testes em:
  - `spec/services/documentos/validador_arquivo_spec.rb`
  - `spec/services/documentos/ingestao_service_spec.rb`
  - `spec/services/ingestao_email/factory_and_adapters_spec.rb`
  - `spec/services/integracao_whatsapp/factory_and_adapters_spec.rb`
- 63 testes RSpec passando com 100% de sucesso.
