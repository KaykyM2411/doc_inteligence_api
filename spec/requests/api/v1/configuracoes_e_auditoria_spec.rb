# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Configuracoes & Auditoria", type: :request do
  let!(:usuario) do
    Usuario.create!(
      nome: "Admin Gestor",
      email: "admin.gestor@lamarck.adv.br",
      password: "Password@123",
      password_confirmation: "Password@123"
    )
  end

  let!(:provedor_grok) do
    ConfiguracaoProvedorIa.find_or_create_by!(nome_provedor: "grok") do |c|
      c.nome_modelo = "grok-2-vision-1212"
      c.credencial_criptografada = "key_grok"
      c.ativo = true
      c.ordem = 1
    end
  end

  let!(:provedor_openai) do
    ConfiguracaoProvedorIa.find_or_create_by!(nome_provedor: "openai") do |c|
      c.nome_modelo = "gpt-4o-mini"
      c.credencial_criptografada = "key_openai"
      c.ativo = false
    end
  end

  let!(:documento) do
    Documento.create!(
      tipo: "rg",
      origem: "manual",
      sha256_arquivo: Digest::SHA256.hexdigest("arquivo_auditoria"),
      status: :processado
    )
  end

  let!(:historico1) do
    documento.historicos_extracao.create!(
      nome_provedor: "grok",
      nome_modelo: "grok-2-vision-1212",
      versao_prompt: "v1.0",
      tokens_entrada: 1000,
      tokens_saida: 200,
      tempo_resposta_ms: 1200,
      custo_estimado_usd: 0.003
    )
  end

  let(:auth_headers) do
    post "/api/v1/auth/login", params: {
      usuario: { email: "admin.gestor@lamarck.adv.br", password: "Password@123" }
    }
    { "Authorization" => response.headers["Authorization"] }
  end

  describe "POST /api/v1/configuracoes/provedores_ia/:id/ativar" do
    it "activates the selected AI provider with order" do
      post "/api/v1/configuracoes/provedores_ia/#{provedor_openai.id}/ativar",
           params: { ordem: 2 },
           headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(provedor_openai.reload.ativo).to be true
      expect(provedor_openai.ordem).to eq(2)
    end
  end

  describe "GET /api/v1/auditoria/custos" do
    it "returns aggregated summary of costs, tokens, response times and drill-down history" do
      get "/api/v1/auditoria/custos", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      resumo = json["resumo"]
      expect(resumo["total_custo_usd"]).to be >= 0.003
      expect(resumo["total_tokens_entrada"]).to be >= 1000
      expect(resumo["total_processamentos"]).to be >= 1
      expect(resumo["gastos_por_provedor"]["grok"]).to be >= 0.003

      expect(json["historicos"]).not_to be_empty
    end
  end
end
