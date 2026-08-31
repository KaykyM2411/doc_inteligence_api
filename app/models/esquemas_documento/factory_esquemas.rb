# frozen_string_literal: true

module EsquemasDocumento
  class FactoryEsquemas
    ESQUEMAS = {
      "rg" => { 1 => EsquemaRgV1 },
      "cnh" => { 1 => EsquemaCnhV1 },
      "comprovante_residencia" => { 1 => EsquemaComprovanteResidenciaV1 },
      "contracheque" => { 1 => EsquemaContrachequeV1 }
    }.freeze

    # Constrói a instância do esquema PORO para o tipo e versão de documento
    # @param tipo [String, Symbol]
    # @param dados [Hash]
    # @param versao [Integer]
    # @return [EsquemaBase]
    def self.build(tipo, dados = {}, versao = 1)
      tipo_chave = tipo.to_s.downcase
      classe = ESQUEMAS.dig(tipo_chave, versao.to_i) || EsquemaBase
      classe.new(dados)
    end
  end
end
