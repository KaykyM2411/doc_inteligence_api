# frozen_string_literal: true

module Api
  module V1
    module Webhooks
      class EmailController < BaseController
        before_action :autenticar_email!

        # POST /api/v1/webhooks/email/ (ou /api/v1/webhooks/email/:provider)
        def create
          provedor = params[:provider].presence || detectar_provedor(request.params)
          adapter = IngestaoEmail::Factory.for_provider(provedor)

          mensagem = adapter.parse_payload(request.params)

          if mensagem.has_attachments?
            mensagem.attachments.each_with_index do |anexo, idx|
              ref_id = "#{mensagem.reference_id}_#{idx + 1}"

              Documentos::IngestaoService.ingestar!(
                anexo.bytes,
                origem: :email,
                referencia_origem: ref_id,
                nome_arquivo: anexo.filename
              )
            end
          end

          render json: {
            status: "success",
            mensagem: "Webhook de e-mail processado com sucesso",
            reference_id: mensagem.reference_id,
            total_anexos: mensagem.attachments.size
          }, status: :ok
        rescue StandardError => e
          Rails.logger.error("[EmailWebhookController] Erro ao processar webhook: #{e.message}")
          render json: {
            status: "error",
            mensagem: "Falha interna no processamento do webhook de e-mail"
          }, status: :ok
        end

        private

        def detectar_provedor(payload)
          if payload["MessageID"].present? || payload[:MessageID].present? || payload["FromFull"].present?
            "postmark"
          else
            "sendgrid"
          end
        end
      end
    end
  end
end
