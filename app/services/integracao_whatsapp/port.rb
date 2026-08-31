# frozen_string_literal: true

module IntegracaoWhatsapp
  class Port
    def provider_name
      raise NotImplementedError, "#{self.class} must implement #provider_name"
    end

    # Converte os parâmetros/payload HTTP brutos do webhook para um WhatsappMessage padronizado
    # @param params_or_payload [Hash, ActionController::Parameters, String]
    # @return [WhatsappMessage]
    def parse_payload(params_or_payload)
      raise NotImplementedError, "#{self.class} must implement #parse_payload"
    end
  end
end
