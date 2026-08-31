# frozen_string_literal: true

module Api
  module V1
    class ClientesController < BaseController
      before_action :set_cliente, only: [ :show, :update, :destroy, :documentos, :upload_documento ]

      # GET /api/v1/clientes
      # Datatable paginada com filtros e ordenações via huginn-datatable
      def index
        result = Cliente.datatable(
          params,
          allowed_paths: [ :enderecos, { enderecos: { cidade: :estado } } ],
          includes: [ enderecos: { cidade: :estado } ]
        )

        render json: {
          total_count: result[:total_count],
          data: result[:data].as_json(
            include: {
              enderecos: {
                include: {
                  cidade: {
                    include: :estado
                  }
                }
              }
            }
          )
        }, status: :ok
      end

      # GET /api/v1/clientes/:id
      def show
        render json: @cliente.as_json(
          include: {
            enderecos: {
              include: {
                cidade: {
                  include: :estado
                }
              }
            }
          }
        ), status: :ok
      end

      # POST /api/v1/clientes
      def create
        cliente = Cliente.new(cliente_params)

        if params[:endereco].present?
          cliente.enderecos.build(endereco_params)
        end

        cliente.save!

        render json: cliente.as_json(include: :enderecos), status: :created
      end

      # PATCH/PUT /api/v1/clientes/:id
      def update
        @cliente.update!(cliente_params)

        if params[:endereco].present?
          endereco = @cliente.enderecos.first || @cliente.enderecos.build
          endereco.update!(endereco_params)
        end

        render json: @cliente.as_json(include: :enderecos), status: :ok
      end

      # DELETE /api/v1/clientes/:id
      def destroy
        @cliente.destroy!
        render json: { mensagem: "Cliente excluído com sucesso" }, status: :ok
      end

      # GET /api/v1/clientes/:id/documentos
      def documentos
        docs = @cliente.documentos.recentes
        render json: docs.as_json, status: :ok
      end

      # POST /api/v1/clientes/:id/documentos
      # Upload manual de arquivo vinculado diretamente na ficha do cliente
      def upload_documento
        arquivo = params[:arquivo]

        if arquivo.blank?
          return render json: { error: "Nenhum arquivo enviado" }, status: :unprocessable_entity
        end

        resultado = Documentos::IngestaoService.ingestar!(
          arquivo,
          origem: :manual,
          cliente_id: @cliente.id,
          nome_arquivo: arquivo.respond_to?(:original_filename) ? arquivo.original_filename : nil,
          tipo_sugerido: params[:tipo].presence || "desconhecido"
        )

        render json: {
          mensagem: resultado.mensagem,
          duplicado: resultado.duplicado,
          documento: resultado.documento
        }, status: (resultado.duplicado ? :ok : :created)
      rescue Documentos::IngestaoService::ErroArquivoInvalido => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def set_cliente
        @cliente = Cliente.find(params[:id])
      end

      def cliente_params
        params.require(:cliente).permit(:nome, :cpf, :email, :telefone)
      end

      def endereco_params
        params.require(:endereco).permit(:logradouro, :numero, :bairro, :cep, :complemento, :cidade_id)
      end
    end
  end
end
