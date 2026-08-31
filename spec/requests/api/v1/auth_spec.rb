# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  let!(:usuario) do
    Usuario.create!(
      nome: "Admin Teste",
      email: "admin.teste@lamarck.adv.br",
      password: "Password@123",
      password_confirmation: "Password@123"
    )
  end

  describe "POST /api/v1/auth/login" do
    it "authenticates user, returns user JSON and JWT Authorization header" do
      post "/api/v1/auth/login", params: {
        usuario: {
          email: "admin.teste@lamarck.adv.br",
          password: "Password@123"
        }
      }

      expect(response).to have_http_status(:ok)
      expect(response.headers["Authorization"]).to be_present
      expect(response.headers["Authorization"]).to start_with("Bearer ")

      json = JSON.parse(response.body)
      expect(json["token"]).to be_present
      expect(json["usuario"]["email"]).to eq("admin.teste@lamarck.adv.br")
      expect(json["usuario"]["nome"]).to eq("Admin Teste")
    end

    it "returns 401 unauthorized when password is wrong" do
      post "/api/v1/auth/login", params: {
        usuario: {
          email: "admin.teste@lamarck.adv.br",
          password: "SenhaIncorreta"
        }
      }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/auth/me" do
    it "returns current user data when token is valid" do
      post "/api/v1/auth/login", params: {
        usuario: {
          email: "admin.teste@lamarck.adv.br",
          password: "Password@123"
        }
      }

      token = response.headers["Authorization"]

      get "/api/v1/auth/me", headers: { "Authorization" => token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["usuario"]["id"]).to eq(usuario.id)
    end

    it "returns 401 unauthorized without token" do
      get "/api/v1/auth/me"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/auth/logout" do
    it "revokes JWT token and logs out" do
      post "/api/v1/auth/login", params: {
        usuario: {
          email: "admin.teste@lamarck.adv.br",
          password: "Password@123"
        }
      }

      token = response.headers["Authorization"]

      delete "/api/v1/auth/logout", headers: { "Authorization" => token }
      expect(response).to have_http_status(:ok)

      get "/api/v1/auth/me", headers: { "Authorization" => token }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
