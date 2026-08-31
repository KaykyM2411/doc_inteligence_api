# frozen_string_literal: true

module IntegracaoWhatsapp
  module Adapters
    class MockWhatsappAdapter < Port
      def provider_name
        "mock"
      end

      def parse_payload(payload)
        raw = payload.is_a?(Hash) ? payload : {}

        WhatsappMessage.new(
          provider_name: provider_name,
          reference_id: raw[:reference_id] || raw["reference_id"] || "mock_wa_#{Time.current.to_i}",
          sender_phone: raw[:sender_phone] || raw["sender_phone"] || "5511999998888",
          receiver_phone: "551130000000",
          timestamp: Time.current,
          caption: raw[:caption] || "Segue meu documento",
          media: WhatsappMedia.new(
            media_id: "mock_media_123",
            filename: "cnh_digital.pdf",
            mime_type: "application/pdf",
            bytes: "%PDF-1.4 mock pdf content from whatsapp"
          ),
          raw_payload: raw
        )
      end
    end
  end
end
