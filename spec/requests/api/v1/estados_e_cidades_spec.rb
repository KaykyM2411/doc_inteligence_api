# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Estados & Cidades", type: :request do
  let!(:usuario) do
    Usuario.create!(
      nome: "Admin Geo",
      email: "admin.geo@lamarck.adv.br",
      password: "Password@123",
      password_confirmation: "Password@123"
    )
  end

  let!(:estado_sp) { Estado.find_or_create_by!(sigla: "SP") { |e| e.nome = "São Paulo" } }
  let!(:cidade_sp) { Cidade.find_or_create_by!(nome: "São Paulo", estado: estado_sp) }
  let!(:cidade_campinas) { Cidade.find_or_create_by!(nome: "Campinas", estado: estado_sp) }

  let(:auth_headers) do
    post "/api/v1/auth/login", params: {
      usuario: { email: "admin.geo@lamarck.adv.br", password: "Password@123" }
    }
    { "Authorization" => response.headers["Authorization"] }
  end

  describe "GET /api/v1/estados" do
    it "returns datatable of states" do
      get "/api/v1/estados", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["total_count"]).to be >= 1
      expect(json["data"]).not_to be_empty
    end
  end

  describe "GET /api/v1/cidades" do
    it "returns datatable of cities with por_estado filter scope" do
      get "/api/v1/cidades", params: { estado_id: estado_sp.id }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["total_count"]).to be >= 2
      expect(json["data"].all? { |c| c["estado_id"] == estado_sp.id }).to be true
    end
  end
end
