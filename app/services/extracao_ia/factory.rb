# frozen_string_literal: true

module ExtracaoIa
  class Factory
    ADAPTERS = {
      "mock" => Adapters::MockAdapter,
      "grok" => Adapters::GrokAdapter,
      "openai" => Adapters::OpenaiAdapter,
      "gemini" => Adapters::GeminiAdapter,
      "openrouter" => Adapters::OpenrouterAdapter,
      "ollama" => Adapters::OllamaAdapter
    }.freeze

    # Retorna a lista de adaptadores ativos ordenados por prioridade (ordem)
    # Suporta fallback cascade entre múltiplos provedores
    # @return [Array<Port>]
    def self.active_adapters
      configs = ConfiguracaoProvedorIa.ativos_ordenados

      if configs.any?
        configs.filter_map do |config|
          adapter_class = ADAPTERS[config.nome_provedor.to_s.downcase]
          adapter_class&.new(config)
        end.presence || [Adapters::MockAdapter.new]
      else
        [Adapters::MockAdapter.new]
      end
    end

    # Retorna a instância do adaptador prioritário (ordem 1)
    # @return [Port]
    def self.active_adapter
      active_adapters.first
    end

    # Instancia um adaptador específico por nome
    # @param provider_name [String, Symbol]
    # @param configuration [ConfiguracaoProvedorIa, nil]
    # @return [Port]
    def self.create(provider_name, configuration = nil)
      key = provider_name.to_s.downcase
      adapter_class = ADAPTERS[key]

      raise ArgumentError, "Provedor de IA desconhecido: #{provider_name}. Provedores suportados: #{ADAPTERS.keys.join(', ')}" unless adapter_class

      adapter_class.new(configuration)
    end
  end
end
