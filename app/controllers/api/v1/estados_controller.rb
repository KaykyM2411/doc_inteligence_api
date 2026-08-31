# frozen_string_literal: true

module Api
  module V1
    class EstadosController < BaseController
      # GET /api/v1/estados
      # Datatable paginada com filtros via huginn-datatable
      def index
        result = Estado.datatable(params)

        render json: {
          total_count: result[:total_count],
          data: result[:data]
        }, status: :ok
      end

      # GET /api/v1/estados/:id
      def show
        estado = Estado.find(params[:id])
        render json: estado.as_json(include: :cidades), status: :ok
      end
    end
  end
end
