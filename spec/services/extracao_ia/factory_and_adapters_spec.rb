# frozen_string_literal: true

require "rails_helper"
require "webmock/rspec"

RSpec.describe "ExtracaoIa Ports & Adapters", type: :service do
  let(:dummy_image) { "fake_binary_image_content" }

  before do
    Rails.cache.clear
  end

  describe ExtracaoIa::Factory do
    context "when no configuration exists" do
      it "falls back to MockAdapter" do
        adapter = described_class.active_adapter
        expect(adapter).to be_a(ExtracaoIa::Adapters::MockAdapter)
        expect(adapter.provider_name).to eq("mock")
      end
    end

    context "when an active configuration exists in database" do
      let!(:config) do
        ConfiguracaoProvedorIa.create!(
          nome_provedor: "grok",
          nome_modelo: "grok-2-vision-1212",
          credencial_criptografada: "xai-test-key-123",
          ativo: true,
          ordem: 1
        )
      end

      it "instantiates the active provider adapter" do
        adapter = described_class.active_adapter
        expect(adapter).to be_a(ExtracaoIa::Adapters::GrokAdapter)
        expect(adapter.provider_name).to eq("grok")
        expect(adapter.model_name).to eq("grok-2-vision-1212")
        expect(adapter.credential).to eq("xai-test-key-123")
      end
    end

    describe ".create" do
      it "creates the requested adapter by name" do
        expect(described_class.create("grok")).to be_a(ExtracaoIa::Adapters::GrokAdapter)
        expect(described_class.create("openai")).to be_a(ExtracaoIa::Adapters::OpenaiAdapter)
        expect(described_class.create("gemini")).to be_a(ExtracaoIa::Adapters::GeminiAdapter)
        expect(described_class.create("openrouter")).to be_a(ExtracaoIa::Adapters::OpenrouterAdapter)
        expect(described_class.create("ollama")).to be_a(ExtracaoIa::Adapters::OllamaAdapter)
      end

      it "raises ArgumentError for unknown providers" do
        expect { described_class.create("inexistente") }.to raise_error(ArgumentError, /desconhecido/)
      end
    end
  end

  describe ExtracaoIa::Adapters::MockAdapter do
    subject(:adapter) { described_class.new }

    it "extracts RG document by default" do
      result = adapter.extract(dummy_image, options: { tipo_documento: "rg" })

      expect(result).to be_success
      expect(result.document_type).to eq("rg")
      expect(result.confidence_score).to be >= 0.90
      expect(result.extracted_data["cpf"]).to eq("123.456.789-00")
      expect(result.extracted_data["nome"]).to eq("Maria Silva Santos")
      expect(result.estimated_cost_usd).to eq(0.0)
    end

    it "extracts CNH document" do
      result = adapter.extract(dummy_image, options: { filename: "scan_cnh_cliente.pdf" })

      expect(result).to be_success
      expect(result.document_type).to eq("cnh")
      expect(result.extracted_data["numero_cnh"]).to be_present
    end

    it "extracts Comprovante de Residência" do
      result = adapter.extract(dummy_image, options: { filename: "comprovante_luz.pdf" })

      expect(result).to be_success
      expect(result.document_type).to eq("comprovante_residencia")
      expect(result.extracted_data.dig("endereco", "cidade")).to eq("Mossoró")
    end

    it "extracts Contracheque" do
      result = adapter.extract(dummy_image, options: { filename: "holerite_julho.pdf" })

      expect(result).to be_success
      expect(result.document_type).to eq("contracheque")
      expect(result.extracted_data["salario_liquido"]).to eq(5120.50)
    end

    it "simulates errors when requested" do
      result = adapter.extract(dummy_image, options: { simulate_error: true })

      expect(result).not_to be_success
      expect(result.error_message).to eq("Simulated extraction failure")
      expect(result.requires_review?).to be true
    end
  end

  describe ExtracaoIa::Adapters::GrokAdapter do
    let(:config) do
      ConfiguracaoProvedorIa.new(
        nome_provedor: "grok",
        nome_modelo: "grok-2-vision-1212",
        credencial_criptografada: "xai_test_key"
      )
    end
    subject(:adapter) { described_class.new(config) }

    it "queries dynamic pricing from xAI API /v1/models/grok-2-vision-1212 and calculates cost" do
      models_response = {
        id: "grok-2-vision-1212",
        created: 1776556800,
        object: "model",
        owned_by: "xai",
        prompt_text_token_price: 12500,
        completion_text_token_price: 25000
      }

      stub_request(:get, "https://api.x.ai/v1/models/grok-2-vision-1212")
        .with(headers: { "Authorization" => "Bearer xai_test_key" })
        .to_return(status: 200, body: models_response.to_json, headers: { "Content-Type" => "application/json" })

      cost = adapter.calculate_estimated_cost(1000, 500)
      expect(cost).to eq(0.0025)
    end

    it "returns 0.0 if pricing cannot be found" do
      stub_request(:get, "https://api.x.ai/v1/models/grok-2-vision-1212")
        .to_return(status: 404, body: "Not found")

      cost = adapter.calculate_estimated_cost(1000, 500)
      expect(cost).to eq(0.0)
    end

    it "performs extraction via xAI Grok API and parses JSON" do
      api_response = {
        choices: [
          {
            message: {
              content: {
                tipo_documento: "rg",
                score_confianca: 0.98,
                nome_sugerido: "TESTE - RG - 2026.jpg",
                dados_extraidos: { nome: "Fulano de Tal", cpf: "111.222.333-44" }
              }.to_json
            }
          }
        ],
        usage: {
          prompt_tokens: 600,
          completion_tokens: 150
        }
      }

      stub_request(:get, "https://api.x.ai/v1/models/grok-2-vision-1212")
        .to_return(status: 200, body: { prompt_text_token_price: 12500, completion_text_token_price: 25000 }.to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:post, "https://api.x.ai/v1/chat/completions")
        .with(headers: { "Authorization" => "Bearer xai_test_key" })
        .to_return(status: 200, body: api_response.to_json, headers: { "Content-Type" => "application/json" })

      result = adapter.extract(dummy_image)

      expect(result).to be_success
      expect(result.provider_name).to eq("grok")
      expect(result.document_type).to eq("rg")
      expect(result.confidence_score).to eq(0.98)
      expect(result.extracted_data["nome"]).to eq("Fulano de Tal")
      expect(result.input_tokens).to eq(600)
      expect(result.output_tokens).to eq(150)
      expect(result.estimated_cost_usd).to be > 0
    end
  end

  describe ExtracaoIa::Adapters::OpenaiAdapter do
    let(:config) do
      ConfiguracaoProvedorIa.new(
        nome_provedor: "openai",
        nome_modelo: "gpt-4o-mini",
        credencial_criptografada: "sk-proj-test"
      )
    end
    subject(:adapter) { described_class.new(config) }

    it "queries dynamic pricing from OpenRouter models catalog and calculates cost" do
      openrouter_catalog = {
        data: [
          {
            id: "openai/gpt-4o-mini",
            pricing: {
              prompt: "0.00000015",
              completion: "0.0000006"
            }
          }
        ]
      }

      stub_request(:get, "https://openrouter.ai/api/v1/models")
        .to_return(status: 200, body: openrouter_catalog.to_json, headers: { "Content-Type" => "application/json" })

      cost = adapter.calculate_estimated_cost(1_000_000, 1_000_000)
      expect(cost).to eq(0.75)
    end

    it "returns 0.0 if model pricing is not found on OpenRouter" do
      stub_request(:get, "https://openrouter.ai/api/v1/models")
        .to_return(status: 200, body: { data: [] }.to_json, headers: { "Content-Type" => "application/json" })

      cost = adapter.calculate_estimated_cost(1_000_000, 1_000_000)
      expect(cost).to eq(0.0)
    end

    it "performs extraction via OpenAI API" do
      api_response = {
        choices: [
          {
            message: {
              content: {
                tipo_documento: "cnh",
                score_confianca: 0.99,
                nome_sugerido: "MARIA - CNH - 2026.pdf",
                dados_extraidos: { nome: "Maria Santos", cpf: "999.888.777-66" }
              }.to_json
            }
          }
        ],
        usage: {
          prompt_tokens: 800,
          completion_tokens: 200
        }
      }

      stub_request(:get, "https://openrouter.ai/api/v1/models")
        .to_return(status: 200, body: { data: [{ id: "openai/gpt-4o-mini", pricing: { prompt: "0.00000015", completion: "0.0000006" } }] }.to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .with(headers: { "Authorization" => "Bearer sk-proj-test" })
        .to_return(status: 200, body: api_response.to_json, headers: { "Content-Type" => "application/json" })

      result = adapter.extract(dummy_image)

      expect(result).to be_success
      expect(result.document_type).to eq("cnh")
      expect(result.extracted_data["nome"]).to eq("Maria Santos")
    end
  end

  describe ExtracaoIa::Adapters::GeminiAdapter do
    let(:config) do
      ConfiguracaoProvedorIa.new(
        nome_provedor: "gemini",
        nome_modelo: "gemini-1.5-flash",
        credencial_criptografada: "gemini_key_123"
      )
    end
    subject(:adapter) { described_class.new(config) }

    it "queries dynamic pricing from OpenRouter for Gemini model" do
      openrouter_catalog = {
        data: [
          {
            id: "google/gemini-1.5-flash",
            pricing: {
              prompt: "0.000000075",
              completion: "0.0000003"
            }
          }
        ]
      }

      stub_request(:get, "https://openrouter.ai/api/v1/models")
        .to_return(status: 200, body: openrouter_catalog.to_json, headers: { "Content-Type" => "application/json" })

      cost = adapter.calculate_estimated_cost(1_000_000, 1_000_000)
      expect(cost).to eq(0.375)
    end

    it "performs extraction with Google Gemini format" do
      api_response = {
        candidates: [
          {
            content: {
              parts: [
                {
                  text: {
                    tipo_documento: "comprovante_residencia",
                    score_confianca: 0.95,
                    nome_sugerido: "COMPROVANTE - 2026.pdf",
                    dados_extraidos: { titular: "João da Silva" }
                  }.to_json
                }
              ]
            }
          }
        ],
        usageMetadata: {
          promptTokenCount: 500,
          candidatesTokenCount: 120
        }
      }

      stub_request(:get, "https://openrouter.ai/api/v1/models")
        .to_return(status: 200, body: { data: [{ id: "google/gemini-1.5-flash", pricing: { prompt: "0.000000075", completion: "0.0000003" } }] }.to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=gemini_key_123")
        .to_return(status: 200, body: api_response.to_json, headers: { "Content-Type" => "application/json" })

      result = adapter.extract(dummy_image)

      expect(result).to be_success
      expect(result.document_type).to eq("comprovante_residencia")
      expect(result.extracted_data["titular"]).to eq("João da Silva")
      expect(result.input_tokens).to eq(500)
    end
  end

  describe ExtracaoIa::Adapters::OpenrouterAdapter do
    let(:config) do
      ConfiguracaoProvedorIa.new(
        nome_provedor: "openrouter",
        nome_modelo: "meta-llama/llama-3.2-11b-vision-instruct",
        credencial_criptografada: "sk-or-test"
      )
    end
    subject(:adapter) { described_class.new(config) }

    it "queries dynamic pricing from OpenRouter API" do
      openrouter_catalog = {
        data: [
          {
            id: "meta-llama/llama-3.2-11b-vision-instruct",
            pricing: {
              prompt: "0.000000055",
              completion: "0.000000085"
            }
          }
        ]
      }

      stub_request(:get, "https://openrouter.ai/api/v1/models")
        .to_return(status: 200, body: openrouter_catalog.to_json, headers: { "Content-Type" => "application/json" })

      cost = adapter.calculate_estimated_cost(1_000_000, 1_000_000)
      expect(cost).to eq(0.14)
    end

    it "sends correct OpenRouter headers and handles response" do
      api_response = {
        choices: [
          {
            message: {
              content: {
                tipo_documento: "rg",
                score_confianca: 0.91,
                dados_extraidos: { nome: "Carlos Lima" }
              }.to_json
            }
          }
        ],
        usage: { prompt_tokens: 450, completion_tokens: 90 }
      }

      stub_request(:get, "https://openrouter.ai/api/v1/models")
        .to_return(status: 200, body: { data: [] }.to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
        .with(headers: {
          "Authorization" => "Bearer sk-or-test",
          "HTTP-Referer" => "https://lamarck.adv.br",
          "X-Title" => "DOC Intelligence"
        })
        .to_return(status: 200, body: api_response.to_json, headers: { "Content-Type" => "application/json" })

      result = adapter.extract(dummy_image)

      expect(result).to be_success
      expect(result.document_type).to eq("rg")
    end
  end

  describe ExtracaoIa::Adapters::OllamaAdapter do
    subject(:adapter) { described_class.new }

    it "has 0.0 estimated USD cost" do
      expect(adapter.calculate_estimated_cost(10_000, 5_000)).to eq(0.0)
    end

    it "posts to local Ollama API and parses response" do
      api_response = {
        message: {
          content: {
            tipo_documento: "contracheque",
            score_confianca: 0.92,
            dados_extraidos: { salario_bruto: 4500.0 }
          }.to_json
        },
        prompt_eval_count: 320,
        eval_count: 85
      }

      stub_request(:post, "http://localhost:11434/api/chat")
        .to_return(status: 200, body: api_response.to_json, headers: { "Content-Type" => "application/json" })

      result = adapter.extract(dummy_image)

      expect(result).to be_success
      expect(result.document_type).to eq("contracheque")
      expect(result.estimated_cost_usd).to eq(0.0)
      expect(result.input_tokens).to eq(320)
    end
  end
end
