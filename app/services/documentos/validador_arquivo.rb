# frozen_string_literal: true

module Documentos
  class ValidadorArquivo
    # Assinaturas binárias (Magic Bytes) de formatos suportados
    ASSINATURAS = {
      "application/pdf" => [
        [ 0, "%PDF-".b ]
      ],
      "image/jpeg" => [
        [ 0, "\xFF\xD8\xFF".b ]
      ],
      "image/png" => [
        [ 0, "\x89PNG\r\n\x1A\n".b ]
      ],
      "image/webp" => [
        [ 0, "RIFF".b, 8, "WEBP".b ]
      ]
    }.freeze

    MIME_TYPES_PERMITIDOS = %w[
      application/pdf
      image/jpeg
      image/png
      image/webp
    ].freeze

    # Detecta o MIME type real através dos magic bytes do arquivo
    # @param bytes_or_io [String, IO]
    # @return [String, nil] MIME type detectado ou nil se não reconhecido
    def self.detectar_mime_type(bytes_or_io)
      cabecalho = extrair_cabecalho(bytes_or_io)
      return nil if cabecalho.blank?

      ASSINATURAS.each do |mime_type, regras|
        corresponde = if regras.size == 1
          offset, assinatura = regras.first
          cabecalho.byteslice(offset, assinatura.bytesize) == assinatura
        else
          regras.each_slice(2).all? do |offset, assinatura|
            cabecalho.byteslice(offset, assinatura.bytesize) == assinatura
          end
        end

        return mime_type if corresponde
      end

      nil
    end

    # Valida se os bytes do arquivo correspondem a um formato seguro e aceito
    # @param bytes_or_io [String, IO]
    # @return [Boolean]
    def self.valido?(bytes_or_io)
      mime = detectar_mime_type(bytes_or_io)
      MIME_TYPES_PERMITIDOS.include?(mime)
    end

    private

    def self.extrair_cabecalho(bytes_or_io)
      if bytes_or_io.respond_to?(:read)
        pos = bytes_or_io.pos if bytes_or_io.respond_to?(:pos)
        bytes_or_io.rewind if bytes_or_io.respond_to?(:rewind)
        header = bytes_or_io.read(32)
        bytes_or_io.pos = pos if pos && bytes_or_io.respond_to?(:pos=)
        header&.b
      elsif bytes_or_io.is_a?(String)
        bytes_or_io.byteslice(0, 32)&.b
      else
        nil
      end
    end
  end
end
