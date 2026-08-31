# frozen_string_literal: true

require "digest"
require "stringio"

module Documentos
  class IngestaoService
    class ErroArquivoInvalido < StandardError; end
    class ErroIngestao < StandardError; end

    ResultadoIngestao = Struct.new(:documento, :duplicado, :status, :mensagem, keyword_init: true) do
      def sucesso?
        documento.present?
      end

      def idempotente?
        status == :idempotente
      end

      def duplicata_cliente?
        status == :duplicado_cliente
      end
    end

    # Executa a ingestão segura de documentos com Early Idempotency, Magic Bytes e Deduplicação por SHA-256
    # @param arquivo_bytes_ou_io [String, IO] Conteúdo binário ou IO do arquivo
    # @param origem [String, Symbol] :manual, :whatsapp ou :email
    # @param referencia_origem [String, nil] Identificador único externo do webhook (Message-ID)
    # @param nome_arquivo [String, nil] Nome original do arquivo recebido
    # @param cliente_id [String, nil] UUID do Cliente (opcional - usado em importações diretas na ficha do cliente)
    # @param tipo_sugerido [String] Tipo sugerido ou 'desconhecido'
    # @return [ResultadoIngestao]
    def self.ingestar!(arquivo_bytes_ou_io, origem:, referencia_origem: nil, nome_arquivo: nil, cliente_id: nil, tipo_sugerido: "desconhecido")
      new(
        arquivo_bytes_ou_io,
        origem: origem,
        referencia_origem: referencia_origem,
        nome_arquivo: nome_arquivo,
        cliente_id: cliente_id,
        tipo_sugerido: tipo_sugerido
      ).executar!
    end

    def initialize(arquivo_bytes_ou_io, origem:, referencia_origem: nil, nome_arquivo: nil, cliente_id: nil, tipo_sugerido: "desconhecido")
      @arquivo_raw = arquivo_bytes_ou_io
      @origem = origem.to_s
      @referencia_origem = referencia_origem.presence
      @nome_arquivo = nome_arquivo.presence
      @cliente_id = cliente_id.presence
      @tipo_sugerido = tipo_sugerido.presence || "desconhecido"
    end

    def executar!
      # 1. Early Idempotency Check (Descarte imediato de retries de Webhook sem baixar/processar)
      if @referencia_origem.present?
        doc_existente = Documento.find_by(origem: @origem, referencia_origem: @referencia_origem)
        if doc_existente
          return ResultadoIngestao.new(
            documento: doc_existente,
            duplicado: true,
            status: :idempotente,
            mensagem: "Evento já recebido e registrado anteriormente"
          )
        end
      end

      # 2. Leitura e Sanitização por Magic Bytes
      bytes = extrair_bytes(@arquivo_raw)
      mime_type = ValidadorArquivo.detectar_mime_type(bytes)

      unless ValidadorArquivo.valido?(bytes)
        raise ErroArquivoInvalido, "Tipo de arquivo não permitido ou corrompido. Apenas PDF, JPEG, PNG e WebP são aceitos."
      end

      # 3. Cálculo de Integridade SHA-256
      sha256 = Digest::SHA256.hexdigest(bytes)

      # 4. Deduplicação por Conteúdo (Scoped por Cliente quando cliente_id estiver presente)
      if @cliente_id.present?
        doc_duplicado = Documento.find_by(cliente_id: @cliente_id, sha256_arquivo: sha256)
        if doc_duplicado
          return ResultadoIngestao.new(
            documento: doc_duplicado,
            duplicado: true,
            status: :duplicado_cliente,
            mensagem: "Documento com mesmo conteúdo (SHA-256) já cadastrado para este cliente"
          )
        end
      end

      # 5. Persistência do Documento
      nome_final = @nome_arquivo || "documento_#{Time.current.to_i}#{extensao_para_mime(mime_type)}"

      documento = Documento.new(
        tipo: @tipo_sugerido,
        origem: @origem,
        referencia_origem: @referencia_origem,
        sha256_arquivo: sha256,
        nome_arquivo: nome_final,
        cliente_id: @cliente_id,
        status: :pendente
      )

      documento.arquivo.attach(
        io: StringIO.new(bytes),
        filename: nome_final,
        content_type: mime_type
      )

      documento.save!

      # 6. Despacho do Processamento Assíncrono com IA via Sidekiq
      ProcessarDocumentoJob.perform_later(documento.id)

      ResultadoIngestao.new(
        documento: documento,
        duplicado: false,
        status: :criado,
        mensagem: "Documento enfileirado com sucesso para processamento"
      )
    rescue ActiveRecord::RecordNotUnique => e
      # Fallback de segurança para concorrência em constraints do PostgreSQL
      if @referencia_origem.present? && (doc = Documento.find_by(origem: @origem, referencia_origem: @referencia_origem))
        ResultadoIngestao.new(documento: doc, duplicado: true, status: :idempotente, mensagem: "Evento idempotente capturado por constraint única")
      else
        raise e
      end
    end

    private

    def extrair_bytes(raw)
      if raw.respond_to?(:read)
        raw.rewind if raw.respond_to?(:rewind)
        raw.read
      elsif raw.is_a?(String)
        raw
      else
        raise ErroArquivoInvalido, "Formato de arquivo de entrada inválido: esperado String ou IO"
      end
    end

    def extensao_para_mime(mime)
      case mime
      when "application/pdf" then ".pdf"
      when "image/jpeg" then ".jpg"
      when "image/png" then ".png"
      when "image/webp" then ".webp"
      else ""
      end
    end
  end
end
