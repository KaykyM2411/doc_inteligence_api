# frozen_string_literal: true

module IngestaoEmail
  class Factory
    ADAPTERS = {
      "sendgrid" => Adapters::SendgridAdapter,
      "postmark" => Adapters::PostmarkAdapter,
      "mock" => Adapters::MockEmailAdapter
    }.freeze

    # Retorna o adaptador apropriado com base no nome do provedor ou na configuração ativa do banco
    # @param provider_name [String, Symbol, nil]
    # @return [Port]
    def self.for_provider(provider_name = nil)
      key = if provider_name.present?
        provider_name.to_s.downcase
      else
        config = ConfiguracaoSmtp.ativos.first
        config&.tipo_provedor&.downcase || "sendgrid"
      end

      adapter_class = ADAPTERS[key] || Adapters::SendgridAdapter
      adapter_class.new
    end
  end
end
