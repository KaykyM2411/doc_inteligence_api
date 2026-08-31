# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Notificacoes", type: :request do
  let!(:usuario) do
    Usuario.create!(
      nome: "Admin Notificacoes",
      email: "admin.notif@lamarck.adv.br",
      password: "Password@123",
      password_confirmation: "Password@123"
    )
  end

  let!(:notif1) do
    Notificacao.create!(
      titulo: "Novo documento via WhatsApp",
      conteudo: "Documento RG recebido",
      metadados: { documento_id: SecureRandom.uuid, score_confianca: 0.95 }
    )
  end

  let!(:notif2) do
    Notificacao.create!(
      titulo: "Novo documento via E-mail",
      conteudo: "Documento CNH recebido",
      metadados: { documento_id: SecureRandom.uuid, score_confianca: 0.90 }
    )
  end

  let(:auth_headers) do
    post "/api/v1/auth/login", params: {
      usuario: { email: "admin.notif@lamarck.adv.br", password: "Password@123" }
    }
    { "Authorization" => response.headers["Authorization"] }
  end

  describe "GET /api/v1/notificacoes" do
    it "returns list of notifications and total_nao_lidas count" do
      get "/api/v1/notificacoes", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["total_count"]).to be >= 2
      expect(json["total_nao_lidas"]).to be >= 2
      expect(json["data"]).not_to be_empty
    end
  end

  describe "PATCH /api/v1/notificacoes/:id/lida" do
    it "marks single notification as read" do
      patch "/api/v1/notificacoes/#{notif1.id}/lida", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(notif1.reload.lida?).to be true
    end
  end

  describe "POST /api/v1/notificacoes/marcar_todas_lidas" do
    it "marks all unread notifications as read" do
      post "/api/v1/notificacoes/marcar_todas_lidas", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(Notificacao.nao_lidas.count).to eq(0)
    end
  end

  describe "GET /api/v1/notificacoes/nao_lidas_count" do
    it "returns unread count" do
      get "/api/v1/notificacoes/nao_lidas_count", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["total_nao_lidas"]).to be >= 2
    end
  end
end
