# frozen_string_literal: true

module IngestaoEmail
  class Port
    def provider_name
      raise NotImplementedError, "#{self.class} must implement #provider_name"
    end

    # Converte os parâmetros/payload HTTP brutos do webhook para um EmailMessage padronizado
    # @param params_or_payload [Hash, ActionController::Parameters, String]
    # @return [EmailMessage]
    def parse_payload(params_or_payload)
      raise NotImplementedError, "#{self.class} must implement #parse_payload"
    end
  end
end
