# frozen_string_literal: true

module Api
  module V1
    class CidadesController < BaseController
      # GET /api/v1/cidades ou GET /api/v1/estados/:estado_id/cidades
      # Datatable paginada com filtros via huginn-datatable e scope por_estado
      def index
        relation = if params[:estado_id].present?
          Cidade.por_estado(params[:estado_id])
        else
          Cidade.all
        end

        result = relation.datatable(
          params,
          allowed_paths: [ :estado ],
          includes: [ :estado ]
        )

        render json: {
          total_count: result[:total_count],
          data: result[:data].as_json(include: :estado)
        }, status: :ok
      end

      # GET /api/v1/cidades/:id
      def show
        cidade = Cidade.find(params[:id])
        render json: cidade.as_json(include: :estado), status: :ok
      end
    end
  end
end
