# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Documentos", type: :request do
  let!(:usuario) do
    Usuario.create!(
      nome: "Operador de Conferência",
      email: "operador@lamarck.adv.br",
      password: "Password@123",
      password_confirmation: "Password@123"
    )
  end

  let!(:cliente) do
    Cliente.create!(
      nome: "Cliente Lamarck",
      cpf: "123.456.789-00"
    )
  end

  let!(:doc_processado) do
    Documento.create!(
      tipo: "rg",
      origem: "manual",
      sha256_arquivo: Digest::SHA256.hexdigest("arquivo_1"),
      status: :processado,
      cliente: cliente,
      score_confianca: 0.95
    )
  end

  let!(:doc_revisao) do
    Documento.create!(
      tipo: "desconhecido",
      origem: "whatsapp",
      sha256_arquivo: Digest::SHA256.hexdigest("arquivo_2"),
      status: :necessita_revisao,
      score_confianca: 0.45
    )
  end

  let(:auth_headers) do
    post "/api/v1/auth/login", params: {
      usuario: { email: "operador@lamarck.adv.br", password: "Password@123" }
    }
    { "Authorization" => response.headers["Authorization"] }
  end

  describe "GET /api/v1/documentos" do
    it "returns paginated datatable list of documents" do
      get "/api/v1/documentos", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["total_count"]).to be >= 2
      expect(json["data"].size).to be >= 2
    end
  end

  describe "POST /api/v1/documentos" do
    it "performs general manual upload" do
      fake_pdf = Rack::Test::UploadedFile.new(
        StringIO.new("%PDF-1.4 sample general document upload"),
        "application/pdf",
        original_filename: "documento_geral.pdf"
      )

      post "/api/v1/documentos",
           params: { arquivo: fake_pdf, tipo: "cnh" },
           headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["documento"]["status"]).to eq("pendente")
      expect(json["documento"]["origem"]).to eq("manual")
    end
  end

  describe "GET /api/v1/documentos/fila_conferencia" do
    it "lists only documents needing human review or failed" do
      get "/api/v1/documentos/fila_conferencia", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"].all? { |d| %w[necessita_revisao falhou].include?(d["status"]) }).to be true
      expect(json["data"].any? { |d| d["id"] == doc_revisao.id }).to be true
    end
  end

  describe "PATCH /api/v1/documentos/:id/revisar" do
    it "approves and updates document with human review audit and optimistic locking" do
      params = {
        tipo: "cnh",
        cliente_id: cliente.id,
        dados_extraidos: { "nome" => "Cliente Lamarck", "cpf" => "123.456.789-00" },
        lock_version: doc_revisao.lock_version
      }

      patch "/api/v1/documentos/#{doc_revisao.id}/revisar",
            params: params,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["documento"]["status"]).to eq("processado")
      expect(json["documento"]["revisado_por"]["id"]).to eq(usuario.id)

      doc_revisao.reload
      expect(doc_revisao.status).to eq("processado")
      expect(doc_revisao.revisado_por_id).to eq(usuario.id)
      expect(doc_revisao.revisado_em).to be_present
    end

    it "returns 409 Conflict when another operator modified the document concurrently" do
      # Simula modificação simultânea por outro operador alterando o lock_version no banco
      doc_revisao.update!(score_confianca: 0.50)

      params = {
        tipo: "cnh",
        lock_version: 0 # Versão desatualizada (stale)
      }

      patch "/api/v1/documentos/#{doc_revisao.id}/revisar",
            params: params,
            headers: auth_headers

      expect(response).to have_http_status(:conflict)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("Conflito")
    end
  end
end
