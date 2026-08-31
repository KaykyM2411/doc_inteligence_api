# frozen_string_literal: true

module Api
  module V1
    module Configuracoes
      class ProvedoresIaController < BaseController
        before_action :set_provedor, only: [ :show, :update, :ativar ]

        # GET /api/v1/configuracoes/provedores_ia
        def index
          provedores = ConfiguracaoProvedorIa.order(:nome_provedor)
          render json: provedores.as_json(except: :credencial_criptografada), status: :ok
        end

        # GET /api/v1/configuracoes/provedores_ia/:id
        def show
          render json: @provedor.as_json(except: :credencial_criptografada), status: :ok
        end

        # PATCH/PUT /api/v1/configuracoes/provedores_ia/:id
        def update
          @provedor.update!(provedor_params)
          render json: @provedor.as_json(except: :credencial_criptografada), status: :ok
        end

        # POST /api/v1/configuracoes/provedores_ia/:id/ativar
        # Garante que apenas um provedor de IA esteja ativo simultaneamente
        def ativar
          ConfiguracaoProvedorIa.transaction do
            ConfiguracaoProvedorIa.where.not(id: @provedor.id).update_all(ativo: false)
            @provedor.update!(ativo: true)
          end

          render json: {
            mensagem: "Provedor #{@provedor.nome_provedor} ativado com sucesso",
            provedor: @provedor.as_json(except: :credencial_criptografada)
          }, status: :ok
        end

        private

        def set_provedor
          @provedor = ConfiguracaoProvedorIa.find(params[:id])
        end

        def provedor_params
          params.require(:provedor_ia).permit(:nome_modelo, :credencial_criptografada, :ativo)
        end
      end
    end
  end
end
