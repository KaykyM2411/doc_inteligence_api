# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Configuracoes::Whatsapp", type: :request do
  let!(:usuario) do
    Usuario.create!(
      nome: "Admin WhatsApp",
      email: "admin.whatsapp@lamarck.adv.br",
      password: "Password@123",
      password_confirmation: "Password@123"
    )
  end

  let!(:config_whatsapp) do
    ConfiguracaoWhatsapp.create!(
      nome: "WhatsApp Principal",
      tipo_provedor: "evolution_api",
      credencial_criptografada: "secret_token_123",
      numero_telefone: "5584999990001",
      ativo: true
    )
  end

  let(:auth_headers) do
    post "/api/v1/auth/login", params: {
      usuario: { email: "admin.whatsapp@lamarck.adv.br", password: "Password@123" }
    }
    { "Authorization" => response.headers["Authorization"] }
  end

  describe "GET /api/v1/configuracoes/whatsapp" do
    it "returns list of WhatsApp configs without exposing credentials" do
      get "/api/v1/configuracoes/whatsapp", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.first["nome"]).to eq("WhatsApp Principal")
      expect(json.first).not_to have_key("credencial_criptografada")
    end
  end

  describe "GET /api/v1/configuracoes/whatsapp/:id" do
    it "returns specific WhatsApp configuration" do
      get "/api/v1/configuracoes/whatsapp/#{config_whatsapp.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(config_whatsapp.id)
      expect(json["tipo_provedor"]).to eq("evolution_api")
      expect(json).not_to have_key("credencial_criptografada")
    end
  end

  describe "POST /api/v1/configuracoes/whatsapp" do
    it "creates a new WhatsApp configuration" do
      params = {
        whatsapp: {
          nome: "WhatsApp Secundário",
          tipo_provedor: "meta_cloud",
          credencial_criptografada: "meta_token_abc",
          numero_telefone: "5584999990002",
          ativo: true
        }
      }

      post "/api/v1/configuracoes/whatsapp", params: params, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["nome"]).to eq("WhatsApp Secundário")
      expect(json["tipo_provedor"]).to eq("meta_cloud")
      expect(json).not_to have_key("credencial_criptografada")
    end
  end

  describe "PATCH /api/v1/configuracoes/whatsapp/:id" do
    it "updates existing WhatsApp configuration" do
      params = {
        whatsapp: {
          nome: "WhatsApp Atualizado",
          ativo: false
        }
      }

      patch "/api/v1/configuracoes/whatsapp/#{config_whatsapp.id}", params: params, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["nome"]).to eq("WhatsApp Atualizado")
      expect(config_whatsapp.reload.ativo).to be false
    end
  end

  describe "DELETE /api/v1/configuracoes/whatsapp/:id" do
    it "destroys the WhatsApp configuration" do
      delete "/api/v1/configuracoes/whatsapp/#{config_whatsapp.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(ConfiguracaoWhatsapp.find_by(id: config_whatsapp.id)).to be_nil
    end
  end
end
