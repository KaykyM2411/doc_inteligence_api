# frozen_string_literal: true

module IntegracaoWhatsapp
  class Factory
    ADAPTERS = {
      "evolution_api" => Adapters::EvolutionApiAdapter,
      "meta_cloud" => Adapters::MetaCloudAdapter,
      "mock" => Adapters::MockWhatsappAdapter
    }.freeze

    # Retorna o adaptador apropriado com base no nome do provedor ou na configuração ativa do banco
    # @param provider_name [String, Symbol, nil]
    # @return [Port]
    def self.for_provider(provider_name = nil)
      key = if provider_name.present?
        provider_name.to_s.downcase
      else
        config = ConfiguracaoWhatsapp.ativos.first
        config&.tipo_provedor&.downcase || "evolution_api"
      end

      adapter_class = ADAPTERS[key] || Adapters::EvolutionApiAdapter
      adapter_class.new
    end
  end
end
