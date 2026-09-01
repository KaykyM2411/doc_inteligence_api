# frozen_string_literal: true

module Api
  module V1
    module Configuracoes
      class WhatsappController < BaseController
        before_action :set_config, only: [ :show, :update, :destroy ]

        # GET /api/v1/configuracoes/whatsapp
        def index
          configs = ConfiguracaoWhatsapp.order(:nome)
          render json: ConfiguracaoWhatsappSerializer.new(configs).serialize, status: :ok
        end

        # GET /api/v1/configuracoes/whatsapp/:id
        def show
          render json: ConfiguracaoWhatsappSerializer.new(@config).serialize, status: :ok
        end

        # POST /api/v1/configuracoes/whatsapp
        def create
          config = ConfiguracaoWhatsapp.create!(whatsapp_params)
          render json: ConfiguracaoWhatsappSerializer.new(config).serialize, status: :created
        end

        # PATCH/PUT /api/v1/configuracoes/whatsapp/:id
        def update
          @config.update!(whatsapp_params)
          render json: ConfiguracaoWhatsappSerializer.new(@config).serialize, status: :ok
        end

        # DELETE /api/v1/configuracoes/whatsapp/:id
        def destroy
          @config.destroy!
          render json: { mensagem: "Configuração de WhatsApp removida com sucesso" }, status: :ok
        end

        private

        def set_config
          @config = ConfiguracaoWhatsapp.find(params[:id])
        end

        def whatsapp_params
          source = params[:whatsapp] || params[:configuracao_whatsapp] || params
          source.permit(:nome, :tipo_provedor, :credencial_criptografada, :numero_telefone, :ativo)
        end
      end
    end
  end
end
