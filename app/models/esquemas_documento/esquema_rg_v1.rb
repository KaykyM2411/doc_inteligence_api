# frozen_string_literal: true

module EsquemasDocumento
  class EsquemaRgV1 < EsquemaBase
    attr_accessor :nome,
                  :cpf,
                  :numero_rg,
                  :orgao_emissor,
                  :data_nascimento,
                  :filiacao,
                  :naturalidade,
                  :data_emissao

    validates :nome, presence: true
    validates :numero_rg, presence: true

    def nome_cliente
      nome
    end

    def cpf_cliente
      cpf
    end

    protected

    def sanitizar_atributos(hash)
      {
        nome: sanitizar_string(hash["nome"]),
        cpf: sanitizar_cpf(hash["cpf"]),
        numero_rg: sanitizar_string(hash["numero_rg"]),
        orgao_emissor: sanitizar_string(hash["orgao_emissor"]),
        data_nascimento: sanitizar_data(hash["data_nascimento"]),
        naturalidade: sanitizar_string(hash["naturalidade"]),
        data_emissao: sanitizar_data(hash["data_emissao"]),
        filiacao: sanitizar_filiacao(hash["filiacao"])
      }
    end

    private

    def sanitizar_filiacao(fil)
      return {} unless fil.is_a?(Hash)

      {
        "mae" => sanitizar_string(fil["mae"] || fil[:mae]),
        "pai" => sanitizar_string(fil["pai"] || fil[:pai])
      }.compact
    end
  end
end
