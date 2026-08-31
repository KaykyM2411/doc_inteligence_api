# frozen_string_literal: true

module Api
  module V1
    class NotificacoesController < BaseController
      before_action :set_notificacao, only: [ :show, :lida ]

      # GET /api/v1/notificacoes
      # Datatable paginada com suporte a filtros (ex: filters[lida_em]=null)
      def index
        result = Notificacao.recentes.datatable(params)

        render json: {
          total_count: result[:total_count],
          total_nao_lidas: Notificacao.nao_lidas.count,
          data: result[:data]
        }, status: :ok
      end

      # GET /api/v1/notificacoes/:id
      def show
        render json: @notificacao, status: :ok
      end

      # PATCH /api/v1/notificacoes/:id/lida
      def lida
        @notificacao.marcar_como_lida!
        render json: {
          mensagem: "Notificação marcada como lida com sucesso",
          notificacao: @notificacao
        }, status: :ok
      end

      # POST /api/v1/notificacoes/marcar_todas_lidas
      def marcar_todas_lidas
        Notificacao.nao_lidas.update_all(lida_em: Time.current, updated_at: Time.current)
        render json: {
          mensagem: "Todas as notificações foram marcadas como lidas com sucesso"
        }, status: :ok
      end

      # GET /api/v1/notificacoes/nao_lidas_count
      def nao_lidas_count
        render json: {
          total_nao_lidas: Notificacao.nao_lidas.count
        }, status: :ok
      end

      private

      def set_notificacao
        @notificacao = Notificacao.find(params[:id])
      end
    end
  end
end
