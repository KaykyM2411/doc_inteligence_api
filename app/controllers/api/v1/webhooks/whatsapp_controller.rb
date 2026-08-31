# frozen_string_literal: true

module Api
  module V1
    module Webhooks
      class WhatsappController < BaseController
        before_action :autenticar_whatsapp!, except: [ :verify ]

        # GET /api/v1/webhooks/whatsapp/ (ou /api/v1/webhooks/whatsapp/:provider)
        # Responde ao desafio de verificação de webhook da Meta Cloud Graph API
        def verify
          mode = params["hub.mode"]
          token = params["hub.verify_token"]
          challenge = params["hub.challenge"]

          chaves_validas = ConfiguracaoWhatsapp.ativos.map(&:credencial_criptografada).compact

          if mode == "subscribe" && (chaves_validas.empty? || chaves_validas.include?(token))
            render plain: challenge, status: :ok
          else
            render json: { error: "Token de verificação do webhook inválido" }, status: :forbidden
          end
        end

        # POST /api/v1/webhooks/whatsapp/ (ou /api/v1/webhooks/whatsapp/:provider)
        def create
          provedor = params[:provider].presence || detectar_provedor(request.params)
          adapter = IntegracaoWhatsapp::Factory.for_provider(provedor)

          mensagem = adapter.parse_payload(request.params)

          if mensagem.has_media?
            bytes = extrair_ou_baixar_bytes(mensagem, adapter)

            if bytes.present?
              Documentos::IngestaoService.ingestar!(
                bytes,
                origem: :whatsapp,
                referencia_origem: mensagem.reference_id,
                nome_arquivo: mensagem.media.filename
              )
            end
          end

          render json: {
            status: "success",
            mensagem: "Webhook de WhatsApp recebido com sucesso",
            reference_id: mensagem.reference_id
          }, status: :ok
        rescue StandardError => e
          Rails.logger.error("[WhatsappWebhookController] Erro ao processar webhook: #{e.message}")
          render json: {
            status: "error",
            mensagem: "Falha interna no processamento do webhook"
          }, status: :ok # Retorna 200 para evitar retries infinitos do provedor
        end

        private

        def detectar_provedor(payload)
          if payload["object"] == "whatsapp_business_account" || payload[:object] == "whatsapp_business_account"
            "meta_cloud"
          else
            "evolution_api"
          end
        end

        def extrair_ou_baixar_bytes(mensagem, adapter)
          return mensagem.media.bytes if mensagem.media.has_bytes?

          if adapter.respond_to?(:download_media_bytes) && mensagem.media.media_id.present?
            adapter.download_media_bytes(mensagem.media.media_id)
          else
            ""
          end
        end
      end
    end
  end
end
