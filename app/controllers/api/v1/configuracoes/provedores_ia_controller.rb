# frozen_string_literal: true

module Api
  module V1
    module Configuracoes
      class ProvedoresIaController < BaseController
        before_action :set_provedor, only: [ :show, :update, :ativar ]

        # GET /api/v1/configuracoes/provedores_ia
        def index
          provedores = ConfiguracaoProvedorIa.order(ativo: :desc, ordem: :asc)
          render json: ConfiguracaoProvedorIaSerializer.new(provedores).serialize, status: :ok
        end

        # GET /api/v1/configuracoes/provedores_ia/:id
        def show
          render json: ConfiguracaoProvedorIaSerializer.new(@provedor).serialize, status: :ok
        end

        # PATCH/PUT /api/v1/configuracoes/provedores_ia/:id
        def update
          @provedor.update!(provedor_params)
          render json: ConfiguracaoProvedorIaSerializer.new(@provedor).serialize, status: :ok
        end

        # POST /api/v1/configuracoes/provedores_ia/:id/ativar
        # Ativa o provedor de IA com ordem de prioridade na cascata de fallback
        def ativar
          nova_ordem = params[:ordem].presence || @provedor.ordem || (ConfiguracaoProvedorIa.ativos.maximum(:ordem).to_i + 1)
          @provedor.update!(ativo: true, ordem: nova_ordem)

          render json: {
            mensagem: "Provedor #{@provedor.nome_provedor} ativado com sucesso na ordem #{nova_ordem}",
            provedor: ConfiguracaoProvedorIaSerializer.new(@provedor).to_h
          }, status: :ok
        end

        private

        def set_provedor
          @provedor = ConfiguracaoProvedorIa.find(params[:id])
        end

        def provedor_params
          source = params[:provedor_ia] || params[:configuracao_provedor_ia] || params
          source.permit(:nome_modelo, :credencial_criptografada, :ativo, :ordem)
        end
      end
    end
  end
end
