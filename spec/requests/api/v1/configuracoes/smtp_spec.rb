# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Configuracoes::Smtp", type: :request do
  let!(:usuario) do
    Usuario.create!(
      nome: "Admin SMTP",
      email: "admin.smtp@lamarck.adv.br",
      password: "Password@123",
      password_confirmation: "Password@123"
    )
  end

  let!(:config_smtp) do
    ConfiguracaoSmtp.create!(
      nome: "E-mail Geral Lamarck",
      tipo_provedor: "postmark",
      credencial_criptografada: "secret_inbound_postmark_token",
      endereco_email: "docs@lamarck.adv.br",
      ativo: true
    )
  end

  let(:auth_headers) do
    post "/api/v1/auth/login", params: {
      usuario: { email: "admin.smtp@lamarck.adv.br", password: "Password@123" }
    }
    { "Authorization" => response.headers["Authorization"] }
  end

  describe "GET /api/v1/configuracoes/smtp" do
    it "returns list of SMTP configs without exposing credentials" do
      get "/api/v1/configuracoes/smtp", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.first["nome"]).to eq("E-mail Geral Lamarck")
      expect(json.first).not_to have_key("credencial_criptografada")
    end
  end

  describe "GET /api/v1/configuracoes/smtp/:id" do
    it "returns specific SMTP configuration" do
      get "/api/v1/configuracoes/smtp/#{config_smtp.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(config_smtp.id)
      expect(json["tipo_provedor"]).to eq("postmark")
      expect(json).not_to have_key("credencial_criptografada")
    end
  end

  describe "POST /api/v1/configuracoes/smtp" do
    it "creates a new SMTP configuration" do
      params = {
        smtp: {
          nome: "Sendgrid Inbound",
          tipo_provedor: "sendgrid",
          credencial_criptografada: "sendgrid_key_xyz",
          endereco_email: "inbound@lamarck.adv.br",
          ativo: true
        }
      }

      post "/api/v1/configuracoes/smtp", params: params, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["nome"]).to eq("Sendgrid Inbound")
      expect(json["endereco_email"]).to eq("inbound@lamarck.adv.br")
      expect(json).not_to have_key("credencial_criptografada")
    end
  end

  describe "PATCH /api/v1/configuracoes/smtp/:id" do
    it "updates existing SMTP configuration" do
      params = {
        smtp: {
          nome: "E-mail Geral Atualizado",
          ativo: false
        }
      }

      patch "/api/v1/configuracoes/smtp/#{config_smtp.id}", params: params, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["nome"]).to eq("E-mail Geral Atualizado")
      expect(config_smtp.reload.ativo).to be false
    end
  end

  describe "DELETE /api/v1/configuracoes/smtp/:id" do
    it "destroys the SMTP configuration" do
      delete "/api/v1/configuracoes/smtp/#{config_smtp.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(ConfiguracaoSmtp.find_by(id: config_smtp.id)).to be_nil
    end
  end
end
