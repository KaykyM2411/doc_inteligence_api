# frozen_string_literal: true

module Api
  module V1
    module Configuracoes
      class SmtpController < BaseController
        before_action :set_config, only: [ :show, :update, :destroy ]

        # GET /api/v1/configuracoes/smtp
        def index
          configs = ConfiguracaoSmtp.order(:nome)
          render json: ConfiguracaoSmtpSerializer.new(configs).serialize, status: :ok
        end

        # GET /api/v1/configuracoes/smtp/:id
        def show
          render json: ConfiguracaoSmtpSerializer.new(@config).serialize, status: :ok
        end

        # POST /api/v1/configuracoes/smtp
        def create
          config = ConfiguracaoSmtp.create!(smtp_params)
          render json: ConfiguracaoSmtpSerializer.new(config).serialize, status: :created
        end

        # PATCH/PUT /api/v1/configuracoes/smtp/:id
        def update
          @config.update!(smtp_params)
          render json: ConfiguracaoSmtpSerializer.new(@config).serialize, status: :ok
        end

        # DELETE /api/v1/configuracoes/smtp/:id
        def destroy
          @config.destroy!
          render json: { mensagem: "Configuração de E-mail/SMTP removida com sucesso" }, status: :ok
        end

        private

        def set_config
          @config = ConfiguracaoSmtp.find(params[:id])
        end

        def smtp_params
          source = params[:smtp] || params[:configuracao_smtp] || params
          source.permit(:nome, :tipo_provedor, :credencial_criptografada, :endereco_email, :ativo)
        end
      end
    end
  end
end
