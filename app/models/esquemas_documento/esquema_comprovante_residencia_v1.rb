# frozen_string_literal: true

module EsquemasDocumento
  class EsquemaComprovanteResidenciaV1 < EsquemaBase
    attr_accessor :titular,
                  :cpf_titular,
                  :tipo_comprovante,
                  :empresa_emissora,
                  :mes_referencia,
                  :data_vencimento,
                  :endereco

    validates :titular, presence: true

    def nome_cliente
      titular
    end

    def cpf_cliente
      cpf_titular
    end

    protected

    def sanitizar_atributos(hash)
      {
        titular: sanitizar_string(hash["titular"]),
        cpf_titular: sanitizar_cpf(hash["cpf_titular"]),
        tipo_comprovante: sanitizar_string(hash["tipo_comprovante"]),
        empresa_emissora: sanitizar_string(hash["empresa_emissora"]),
        mes_referencia: sanitizar_string(hash["mes_referencia"]),
        data_vencimento: sanitizar_data(hash["data_vencimento"]),
        endereco: sanitizar_endereco(hash["endereco"])
      }
    end

    private

    def sanitizar_endereco(end_hash)
      return {} unless end_hash.is_a?(Hash)

      {
        "logradouro" => sanitizar_string(end_hash["logradouro"] || end_hash[:logradouro]),
        "numero" => sanitizar_string(end_hash["numero"] || end_hash[:numero]),
        "complemento" => sanitizar_string(end_hash["complemento"] || end_hash[:complemento]),
        "bairro" => sanitizar_string(end_hash["bairro"] || end_hash[:bairro]),
        "cidade" => sanitizar_string(end_hash["cidade"] || end_hash[:cidade]),
        "estado" => sanitizar_string(end_hash["estado"] || end_hash[:estado]),
        "cep" => sanitizar_string(end_hash["cep"] || end_hash[:cep])
      }.compact
    end
  end
end
