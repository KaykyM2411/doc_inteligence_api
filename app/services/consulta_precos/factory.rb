# frozen_string_literal: true

module ConsultaPrecos
  class Factory
    ADAPTERS = {
      "mock" => Adapters::MockPricingAdapter,
      "ollama" => Adapters::MockPricingAdapter,
      "grok" => Adapters::GrokPricingAdapter,
      "openai" => Adapters::OpenrouterPricingAdapter,
      "gemini" => Adapters::OpenrouterPricingAdapter,
      "openrouter" => Adapters::OpenrouterPricingAdapter
    }.freeze

    # Retorna a instância do adaptador de preço para o provedor informado
    # @param provider_name [String, Symbol]
    # @return [Port]
    def self.for_provider(provider_name)
      key = provider_name.to_s.downcase
      adapter_class = ADAPTERS[key] || Adapters::MockPricingAdapter
      adapter_class.new
    end
  end
end
