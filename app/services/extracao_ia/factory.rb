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

    # Retorna a instância do adaptador configurado como ativo no banco de dados
    # Fallback para MockAdapter quando nenhum provedor estiver ativo ou configurado
    # @return [Port]
    def self.active_adapter
      config = ConfiguracaoProvedorIa.ativos.first

      if config.present? && ADAPTERS.key?(config.nome_provedor.to_s.downcase)
        ADAPTERS[config.nome_provedor.to_s.downcase].new(config)
      else
        Adapters::MockAdapter.new(config)
      end
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
