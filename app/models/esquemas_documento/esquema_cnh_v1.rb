# frozen_string_literal: true

module EsquemasDocumento
  class EsquemaCnhV1 < EsquemaBase
    attr_accessor :nome,
                  :cpf,
                  :numero_cnh,
                  :data_nascimento,
                  :categoria,
                  :validade,
                  :primeira_habilitacao,
                  :filiacao

    validates :nome, presence: true
    validates :cpf, presence: true
    validates :numero_cnh, presence: true

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
        numero_cnh: sanitizar_string(hash["numero_cnh"]),
        data_nascimento: sanitizar_data(hash["data_nascimento"]),
        categoria: sanitizar_string(hash["categoria"]),
        validade: sanitizar_data(hash["validade"]),
        primeira_habilitacao: sanitizar_data(hash["primeira_habilitacao"]),
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
