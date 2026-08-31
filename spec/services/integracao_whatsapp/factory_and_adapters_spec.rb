# frozen_string_literal: true

require "rails_helper"
require "webmock/rspec"

RSpec.describe "IntegracaoWhatsapp Ports & Adapters", type: :service do
  describe IntegracaoWhatsapp::Factory do
    it "returns EvolutionApiAdapter for evolution_api" do
      adapter = described_class.for_provider("evolution_api")
      expect(adapter).to be_a(IntegracaoWhatsapp::Adapters::EvolutionApiAdapter)
      expect(adapter.provider_name).to eq("evolution_api")
    end

    it "returns MetaCloudAdapter for meta_cloud" do
      adapter = described_class.for_provider("meta_cloud")
      expect(adapter).to be_a(IntegracaoWhatsapp::Adapters::MetaCloudAdapter)
      expect(adapter.provider_name).to eq("meta_cloud")
    end

    it "returns MockWhatsappAdapter for mock" do
      adapter = described_class.for_provider("mock")
      expect(adapter).to be_a(IntegracaoWhatsapp::Adapters::MockWhatsappAdapter)
    end
  end

  describe IntegracaoWhatsapp::Adapters::EvolutionApiAdapter do
    subject(:adapter) { described_class.new }

    it "parses Evolution API messages.upsert payload matching official JSON schema" do
      base64_pdf = "JVBERi0xLjQKJcfsj6IKNSAwIG9iago8PA..."

      payload = {
        "event" => "messages.upsert",
        "instance" => "minha-instancia",
        "data" => {
          "key" => {
            "remoteJid" => "5584999999999@s.whatsapp.net",
            "fromMe" => false,
            "id" => "3EB0C123456789ABCDEF"
          },
          "pushName" => "Nome do Contato",
          "messageType" => "documentMessage",
          "message" => {
            "documentMessage" => {
              "url" => "https://mmg.whatsapp.net/v/t62.7118-24/...",
              "mimetype" => "application/pdf",
              "title" => "relatorio_financeiro.pdf",
              "fileSha256" => "sha256_dummy_hash",
              "fileLength" => "1048576",
              "mediaKey" => "media_key_123",
              "fileName" => "relatorio_financeiro.pdf",
              "directPath" => "/v/t62.7118-24/...",
              "mediaKeyTimestamp" => "1725100000"
            },
            "base64" => base64_pdf
          },
          "messageTimestamp" => 1725100000,
          "instanceId" => "uuid-da-instancia",
          "source" => "whatsapp"
        },
        "destination" => "https://sua-api.com/webhook/evolution",
        "date_time" => "2026-08-31T07:51:27.000Z",
        "sender" => "5584999999999@s.whatsapp.net",
        "server_url" => "https://evolution.seu-servidor.com",
        "apikey" => "sua-global-api-key"
      }

      msg = adapter.parse_payload(payload)

      expect(msg.provider_name).to eq("evolution_api")
      expect(msg.reference_id).to eq("3EB0C123456789ABCDEF")
      expect(msg.sender_phone).to eq("5584999999999")
      expect(msg.receiver_phone).to eq("minha-instancia")
      expect(msg).to have_media
      expect(msg.media.filename).to eq("relatorio_financeiro.pdf")
      expect(msg.media.mime_type).to eq("application/pdf")
      expect(msg.media.bytes).to start_with("%PDF-1.4")
    end
  end

  describe IntegracaoWhatsapp::Adapters::MetaCloudAdapter do
    subject(:adapter) { described_class.new }

    let(:meta_payload) do
      {
        "object" => "whatsapp_business_account",
        "entry" => [
          {
            "id" => "WHATSAPP_BUSINESS_ACCOUNT_ID",
            "changes" => [
              {
                "value" => {
                  "messaging_product" => "whatsapp",
                  "metadata" => {
                    "display_phone_number" => "15550555555",
                    "phone_number_id" => "PHONE_NUMBER_ID"
                  },
                  "contacts" => [
                    {
                      "profile" => { "name" => "Nome do Usuário" },
                      "wa_id" => "5584999999999"
                    }
                  ],
                  "messages" => [
                    {
                      "from" => "5584999999999",
                      "id" => "wamid.HBgLMTIzNDU2Nzg5MA",
                      "timestamp" => "1725100000",
                      "type" => "document",
                      "document" => {
                        "filename" => "fatura_agosto.pdf",
                        "mime_type" => "application/pdf",
                        "sha256" => "4b6c38e...",
                        "id" => "1234567890123456"
                      }
                    }
                  ]
                },
                "field" => "messages"
              }
            ]
          }
        ]
      }
    end

    it "parses Meta Cloud WhatsApp Business API webhook structure" do
      msg = adapter.parse_payload(meta_payload)

      expect(msg.provider_name).to eq("meta_cloud")
      expect(msg.reference_id).to eq("wamid.HBgLMTIzNDU2Nzg5MA")
      expect(msg.sender_phone).to eq("5584999999999")
      expect(msg.receiver_phone).to eq("15550555555")
      expect(msg).to have_media
      expect(msg.media.media_id).to eq("1234567890123456")
      expect(msg.media.filename).to eq("fatura_agosto.pdf")
      expect(msg.media.mime_type).to eq("application/pdf")
    end

    it "executes the mandatory 2-step media download flow from Graph API" do
      media_id = "1234567890123456"
      token = "EAABtesttoken123"
      temp_download_url = "https://lookaside.fbsbx.com/whatsapp_business/attachments/?mid=1234567890123456"
      expected_binary = "%PDF-1.4 binary content downloaded from meta CDN"

      # Passo 1: Obter a URL temporária de download
      stub_request(:get, "https://graph.facebook.com/v20.0/#{media_id}")
        .with(headers: { "Authorization" => "Bearer #{token}" })
        .to_return(
          status: 200,
          body: {
            url: temp_download_url,
            mime_type: "application/pdf",
            sha256: "4b6c38e...",
            file_size: expected_binary.bytesize,
            id: media_id,
            messaging_product: "whatsapp"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Passo 2: Baixar o binário puro da URL temporária (com User-Agent obrigatório)
      stub_request(:get, temp_download_url)
        .with(headers: {
          "Authorization" => "Bearer #{token}",
          "User-Agent" => "curl/7.64.1"
        })
        .to_return(
          status: 200,
          body: expected_binary,
          headers: { "Content-Type" => "application/pdf" }
        )

      downloaded_bytes = adapter.download_media_bytes(media_id, token: token)
      expect(downloaded_bytes).to eq(expected_binary)
    end
  end

  describe IntegracaoWhatsapp::Adapters::MockWhatsappAdapter do
    subject(:adapter) { described_class.new }

    it "returns deterministic whatsapp message for testing" do
      result = adapter.parse_payload({})
      expect(result.provider_name).to eq("mock")
      expect(result.reference_id).to be_present
      expect(result.media.bytes).to start_with("%PDF-1.4")
    end
  end
end
