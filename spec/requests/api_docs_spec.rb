# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Swagger & API Docs", type: :request do
  describe "GET /api-docs" do
    it "renders the Swagger UI HTML page" do
      get "/api-docs"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("SwaggerUIBundle")
      expect(response.body).to include("/swagger.json")
    end
  end

  describe "GET /swagger.json" do
    it "returns the valid OpenAPI 3.0 JSON specification" do
      get "/swagger.json"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["openapi"]).to start_with("3.0")
      expect(json["info"]["title"]).to eq("DOC Intelligence API")
      expect(json["paths"]).to have_key("/api/v1/auth/login")
      expect(json["paths"]).to have_key("/api/v1/documentos")
      expect(json["paths"]).to have_key("/api/v1/notificacoes")
    end
  end
end
