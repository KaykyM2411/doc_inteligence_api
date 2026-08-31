# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Webhooks", type: :request do
  let!(:config_whatsapp) do
    ConfiguracaoWhatsapp.create!(
      nome: "WhatsApp Atendimento 1",
      tipo_provedor: "evolution_api",
      credencial_criptografada: "evo_secret_token_12345",
      numero_telefone: "5511999999999",
      ativo: true
    )
  end

  let!(:config_smtp) do
    ConfiguracaoSmtp.create!(
      nome: "Email Inbound Lamarck",
      tipo_provedor: "postmark",
      credencial_criptografada: "postmark_inbound_secret_999",
      endereco_email: "docs@lamarck.adv.br",
      ativo: true
    )
  end

  describe "GET /api/v1/webhooks/whatsapp" do
    it "responds to Meta Cloud verification challenge when verify_token matches active config" do
      get "/api/v1/webhooks/whatsapp", params: {
        "hub.mode" => "subscribe",
        "hub.verify_token" => "evo_secret_token_12345",
        "hub.challenge" => "1158201444"
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("1158201444")
    end

    it "returns 403 forbidden when verify_token is invalid" do
      get "/api/v1/webhooks/whatsapp", params: {
        "hub.mode" => "subscribe",
        "hub.verify_token" => "token_incorreto",
        "hub.challenge" => "1158201444"
      }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/webhooks/whatsapp" do
    it "processes Evolution API webhook when valid apikey header is passed" do
      base64_pdf = Base64.encode64("%PDF-1.4 sample document from evolution webhook")

      payload = {
        "event" => "messages.upsert",
        "instance" => "WhatsApp Atendimento 1",
        "data" => {
          "key" => {
            "remoteJid" => "5511988887777@s.whatsapp.net",
            "id" => "EVO_REQ_TEST_123"
          },
          "message" => {
            "documentMessage" => {
              "fileName" => "cnh_digital.pdf",
              "mimetype" => "application/pdf",
              "base64" => base64_pdf
            }
          }
        }
      }

      post "/api/v1/webhooks/whatsapp",
           params: payload.to_json,
           headers: {
             "Content-Type" => "application/json",
             "apikey" => "evo_secret_token_12345"
           }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("success")
      expect(json["reference_id"]).to eq("EVO_REQ_TEST_123")

      doc = Documento.find_by(referencia_origem: "EVO_REQ_TEST_123")
      expect(doc).to be_present
      expect(doc.origem).to eq("whatsapp")
      expect(doc.arquivo).to be_attached
    end

    it "returns 401 unauthorized when WhatsApp credential is wrong" do
      post "/api/v1/webhooks/whatsapp",
           params: {}.to_json,
           headers: {
             "Content-Type" => "application/json",
             "apikey" => "chave_invalida"
           }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/webhooks/email" do
    it "processes Postmark Inbound webhook when valid header token is passed" do
      base64_pdf = Base64.encode64("%PDF-1.4 sample document from postmark webhook")

      payload = {
        "MessageID" => "POSTMARK_REQ_TEST_777",
        "From" => "cliente@example.com",
        "To" => "docs@lamarck.adv.br",
        "Subject" => "Comprovante de Renda",
        "Attachments" => [
          {
            "Name" => "holerite.pdf",
            "ContentType" => "application/pdf",
            "Content" => base64_pdf,
            "ContentLength" => base64_pdf.bytesize
          }
        ]
      }

      post "/api/v1/webhooks/email",
           params: payload.to_json,
           headers: {
             "Content-Type" => "application/json",
             "X-Postmark-Server-Token" => "postmark_inbound_secret_999"
           }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("success")
      expect(json["total_anexos"]).to eq(1)

      doc = Documento.find_by(referencia_origem: "POSTMARK_REQ_TEST_777_1")
      expect(doc).to be_present
      expect(doc.origem).to eq("email")
      expect(doc.arquivo).to be_attached
    end

    it "returns 401 unauthorized when email token is wrong" do
      post "/api/v1/webhooks/email",
           params: {}.to_json,
           headers: {
             "Content-Type" => "application/json",
             "X-Postmark-Server-Token" => "token_falso"
           }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
