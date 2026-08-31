# frozen_string_literal: true

module IngestaoEmail
  module Adapters
    class MockEmailAdapter < Port
      def provider_name
        "mock"
      end

      def parse_payload(payload)
        raw = payload.is_a?(Hash) ? payload : {}

        EmailMessage.new(
          provider_name: provider_name,
          reference_id: raw[:reference_id] || raw["reference_id"] || "mock_email_#{Time.current.to_i}",
          sender_email: raw[:sender_email] || raw["sender_email"] || "cliente.teste@example.com",
          recipient_email: raw[:recipient_email] || raw["recipient_email"] || "docs@lamarck.adv.br",
          subject: raw[:subject] || raw["subject"] || "Documento em anexo",
          attachments: [
            EmailAttachment.new(
              filename: "comprovante_residencia.pdf",
              content_type: "application/pdf",
              bytes: "%PDF-1.4 mock pdf content"
            )
          ],
          raw_payload: raw
        )
      end
    end
  end
end
