# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Clientes", type: :request do
  let!(:usuario) do
    Usuario.create!(
      nome: "Admin Lamarck",
      email: "admin.clientes@lamarck.adv.br",
      password: "Password@123",
      password_confirmation: "Password@123"
    )
  end

  let!(:estado_rn) { Estado.find_or_create_by!(sigla: "RN") { |e| e.nome = "Rio Grande do Norte" } }
  let!(:cidade_natal) { Cidade.find_or_create_by!(nome: "Natal", estado: estado_rn) }

  let!(:cliente1) do
    c = Cliente.create!(
      nome: "Ana Carolina Silva",
      cpf: "111.222.333-44",
      email: "ana@example.com",
      telefone: "(84) 99999-1111"
    )
    c.enderecos.create!(
      logradouro: "Av. Salgado Filho",
      numero: "1000",
      bairro: "Lagoa Nova",
      cidade: cidade_natal,
      cep: "59000-000"
    )
    c
  end

  let!(:cliente2) do
    Cliente.create!(
      nome: "Bernardo Souza",
      cpf: "555.666.777-88",
      email: "bernardo@example.com"
    )
  end

  let(:auth_headers) do
    post "/api/v1/auth/login", params: {
      usuario: { email: "admin.clientes@lamarck.adv.br", password: "Password@123" }
    }
    { "Authorization" => response.headers["Authorization"] }
  end

  describe "GET /api/v1/clientes" do
    it "returns paginated datatable list with total_count and data" do
      get "/api/v1/clientes", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["total_count"]).to be >= 2
      expect(json["data"].size).to be >= 2
    end

    it "filters by alias using huginn_datatable mapping" do
      get "/api/v1/clientes",
          params: { filters: { cpf: "111.222.333-44" } },
          headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["total_count"]).to eq(1)
      expect(json["data"].first["nome"]).to eq("Ana Carolina Silva")
    end
  end

  describe "GET /api/v1/clientes/:id" do
    it "returns client details and addresses" do
      get "/api/v1/clientes/#{cliente1.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(cliente1.id)
      expect(json["enderecos"]).not_to be_empty
    end
  end

  describe "POST /api/v1/clientes" do
    it "creates a new client with address" do
      params = {
        cliente: {
          nome: "Carlos Eduardo Santos",
          cpf: "999.888.777-66",
          email: "carlos.santos@example.com"
        },
        endereco: {
          logradouro: "Rua Mossoró",
          numero: "50",
          cidade_id: cidade_natal.id
        }
      }

      post "/api/v1/clientes", params: params, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["nome"]).to eq("Carlos Eduardo Santos")
      expect(json["enderecos"]).not_to be_empty
    end
  end

  describe "POST /api/v1/clientes/:id/documentos" do
    it "uploads a document directly to the client's file" do
      fake_pdf = Rack::Test::UploadedFile.new(
        StringIO.new("%PDF-1.4 direct client upload document"),
        "application/pdf",
        original_filename: "rg_ana.pdf"
      )

      post "/api/v1/clientes/#{cliente1.id}/documentos",
           params: { arquivo: fake_pdf, tipo: "rg" },
           headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["documento"]["cliente_id"]).to eq(cliente1.id)
      expect(json["documento"]["status"]).to eq("pendente")
    end
  end

  describe "PATCH /api/v1/clientes/:id" do
    it "updates client info and first address" do
      patch "/api/v1/clientes/#{cliente1.id}",
            params: {
              cliente: { telefone: "(84) 98888-2222" },
              endereco: { logradouro: "Av. Salgado Filho Atualizada", numero: "2000", cidade_id: cidade_natal.id }
            },
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["telefone"]).to eq("(84) 98888-2222")
      expect(cliente1.reload.telefone).to eq("(84) 98888-2222")
      expect(cliente1.enderecos.first.logradouro).to eq("Av. Salgado Filho Atualizada")
    end
  end

  describe "DELETE /api/v1/clientes/:id" do
    it "deletes the client and destroys associated addresses" do
      delete "/api/v1/clientes/#{cliente2.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(Cliente.find_by(id: cliente2.id)).to be_nil
    end
  end

  describe "GET /api/v1/clientes/:id/documentos" do
    it "returns list of documents belonging to the client" do
      doc = Documento.create!(
        tipo: "cnh",
        origem: "manual",
        sha256_arquivo: Digest::SHA256.hexdigest("doc_cliente_list_test"),
        status: :processado,
        cliente: cliente1
      )

      get "/api/v1/clientes/#{cliente1.id}/documentos", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.any? { |d| d["id"] == doc.id }).to be true
    end
  end
end
