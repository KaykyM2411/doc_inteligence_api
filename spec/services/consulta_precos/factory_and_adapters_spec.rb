# frozen_string_literal: true

require "rails_helper"
require "webmock/rspec"

RSpec.describe "ConsultaPrecos Ports & Adapters", type: :service do
  before do
    Rails.cache.clear
  end

  describe ConsultaPrecos::Factory do
    it "returns GrokPricingAdapter for grok provider" do
      adapter = described_class.for_provider("grok")
      expect(adapter).to be_a(ConsultaPrecos::Adapters::GrokPricingAdapter)
      expect(adapter.provider_name).to eq("grok")
    end

    it "returns OpenrouterPricingAdapter for openai, gemini and openrouter" do
      expect(described_class.for_provider("openai")).to be_a(ConsultaPrecos::Adapters::OpenrouterPricingAdapter)
      expect(described_class.for_provider("gemini")).to be_a(ConsultaPrecos::Adapters::OpenrouterPricingAdapter)
      expect(described_class.for_provider("openrouter")).to be_a(ConsultaPrecos::Adapters::OpenrouterPricingAdapter)
    end

    it "returns MockPricingAdapter for mock and ollama" do
      expect(described_class.for_provider("mock")).to be_a(ConsultaPrecos::Adapters::MockPricingAdapter)
      expect(described_class.for_provider("ollama")).to be_a(ConsultaPrecos::Adapters::MockPricingAdapter)
    end
  end

  describe ConsultaPrecos::Adapters::GrokPricingAdapter do
    subject(:adapter) { described_class.new }

    it "fetches prices dynamically from xAI API endpoint" do
      stub_request(:get, "https://api.x.ai/v1/models/grok-2-vision-1212")
        .with(headers: { "Authorization" => "Bearer xai_key" })
        .to_return(
          status: 200,
          body: { prompt_text_token_price: 12500, completion_text_token_price: 25000 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = adapter.fetch_price("grok-2-vision-1212", "xai_key")

      expect(result.prompt_per_token).to eq(0.00000125)
      expect(result.completion_per_token).to eq(0.0000025)
      expect(result.calculate_cost(1000, 500)).to eq(0.0025)
    end

    it "returns 0.0 when model is not found" do
      stub_request(:get, "https://api.x.ai/v1/models/unknown")
        .to_return(status: 404, body: "Not found")

      result = adapter.fetch_price("unknown", "xai_key")
      expect(result.calculate_cost(1000, 500)).to eq(0.0)
    end
  end

  describe ConsultaPrecos::Adapters::OpenrouterPricingAdapter do
    subject(:adapter) { described_class.new }

    it "fetches prices dynamically from OpenRouter catalog" do
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

      result = adapter.fetch_price("google/gemini-1.5-flash")

      expect(result.prompt_per_token).to eq(0.000000075)
      expect(result.completion_per_token).to eq(0.0000003)
      expect(result.calculate_cost(1_000_000, 1_000_000)).to eq(0.375)
    end

    it "returns 0.0 when model is not found on OpenRouter" do
      stub_request(:get, "https://openrouter.ai/api/v1/models")
        .to_return(status: 200, body: { data: [] }.to_json, headers: { "Content-Type" => "application/json" })

      result = adapter.fetch_price("unlisted-model")
      expect(result.calculate_cost(1_000_000, 1_000_000)).to eq(0.0)
    end
  end
end
