# frozen_string_literal: true

module Api
  module V1
    class DocumentosController < BaseController
      before_action :set_documento, only: [ :show, :revisar, :download ]

      # GET /api/v1/documentos
      # Datatable global com filtros e ordenações via huginn-datatable
      def index
        result = Documento.datatable(
          params,
          allowed_paths: [ :cliente, :revisado_por ],
          includes: [ :cliente, :revisado_por, arquivo_attachment: :blob ]
        )

        render json: {
          total_count: result[:total_count],
          data: result[:data].as_json(
            include: [ :cliente, :revisado_por ],
            methods: :arquivo_url
          )
        }, status: :ok
      end

      # GET /api/v1/documentos/:id
      def show
        render json: @documento.as_json(
          include: [ :cliente, :revisado_por, :historicos_extracao ],
          methods: :arquivo_url
        ), status: :ok
      end

      # POST /api/v1/documentos
      # Upload manual geral
      def create
        arquivo = params[:arquivo]

        if arquivo.blank?
          return render json: { error: "Nenhum arquivo enviado" }, status: :unprocessable_entity
        end

        resultado = Documentos::IngestaoService.ingestar!(
          arquivo,
          origem: :manual,
          cliente_id: params[:cliente_id],
          nome_arquivo: arquivo.respond_to?(:original_filename) ? arquivo.original_filename : nil,
          tipo_sugerido: params[:tipo].presence || "desconhecido"
        )

        render json: {
          mensagem: resultado.mensagem,
          duplicado: resultado.duplicado,
          documento: resultado.documento.as_json(methods: :arquivo_url)
        }, status: (resultado.duplicado ? :ok : :created)
      rescue Documentos::IngestaoService::ErroArquivoInvalido => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # GET /api/v1/documentos/fila_conferencia
      # Listagem de itens necessitando de revisão ou com falha
      def fila_conferencia
        result = Documento.para_revisao.datatable(
          params,
          allowed_paths: [ :cliente, :revisado_por ],
          includes: [ :cliente, :revisado_por, arquivo_attachment: :blob ]
        )

        render json: {
          total_count: result[:total_count],
          data: result[:data].as_json(
            include: [ :cliente, :revisado_por ],
            methods: :arquivo_url
          )
        }, status: :ok
      end

      # PATCH /api/v1/documentos/:id/revisar
      # Conferência humana com concorrência otimista (lock_version) e registro de auditoria
      def revisar
        # Atualiza com lock_version garantindo controle de concorrência entre atendentes
        @documento.lock_version = params[:lock_version] if params[:lock_version].present?
        @documento.tipo = params[:tipo] if params[:tipo].present?
        @documento.cliente_id = params[:cliente_id] if params.key?(:cliente_id)
        @documento.dados_extraidos = params[:dados_extraidos] if params[:dados_extraidos].present?
        @documento.status = :processado
        @documento.revisado_por = current_usuario
        @documento.revisado_em = Time.current

        @documento.save!

        render json: {
          mensagem: "Documento conferido e aprovado com sucesso",
          documento: @documento.as_json(include: [ :cliente, :revisado_por ], methods: :arquivo_url)
        }, status: :ok
      end

      # GET /api/v1/documentos/:id/download
      def download
        if @documento.arquivo.attached?
          redirect_to rails_blob_url(@documento.arquivo, disposition: "attachment")
        else
          render json: { error: "Arquivo não encontrado para este documento" }, status: :not_found
        end
      end

      private

      def set_documento
        @documento = Documento.find(params[:id])
      end
    end
  end
end
