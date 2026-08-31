# frozen_string_literal: true

module Api
  module V1
    module Webhooks
      class BaseController < ActionController::API
        private

        # Validação estrita de credenciais de canais de WhatsApp contra as configurações ativas no banco
        def autenticar_whatsapp!
          configuracoes_ativas = ConfiguracaoWhatsapp.ativos
          return if configuracoes_ativas.empty?

          token_recebido = extrair_token_whatsapp
          chaves_validas = configuracoes_ativas.map(&:credencial_criptografada).compact

          unless token_recebido.present? && chaves_validas.include?(token_recebido)
            render json: { error: "Não autorizado: credencial de WhatsApp inválida" }, status: :unauthorized
          end
        end

        # Validação estrita de credenciais de canais de E-mail contra as configurações ativas no banco
        def autenticar_email!
          configuracoes_ativas = ConfiguracaoSmtp.ativos
          return if configuracoes_ativas.empty?

          token_recebido = extrair_token_email
          chaves_validas = configuracoes_ativas.map(&:credencial_criptografada).compact

          unless token_recebido.present? && chaves_validas.include?(token_recebido)
            render json: { error: "Não autorizado: credencial de e-mail inválida" }, status: :unauthorized
          end
        end

        def extrair_token_whatsapp
          request.headers["X-Api-Key"] ||
            request.headers["apikey"] ||
            request.headers["Authorization"]&.sub(/\ABearer\s+/i, "") ||
            params["apikey"] ||
            params["hub.verify_token"] ||
            params[:token]
        end

        def extrair_token_email
          request.headers["X-Postmark-Server-Token"] ||
            request.headers["X-Sendgrid-Token"] ||
            request.headers["Authorization"]&.sub(/\ABearer\s+/i, "") ||
            params[:token] ||
            params["token"]
        end
      end
    end
  end
end
