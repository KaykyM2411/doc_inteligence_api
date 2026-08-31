# frozen_string_literal: true

module EsquemasDocumento
  class EsquemaContrachequeV1 < EsquemaBase
    attr_accessor :nome_funcionario,
                  :cpf_funcionario,
                  :empregador,
                  :cnpj_empregador,
                  :mes_ano_competencia,
                  :cargo,
                  :salario_bruto,
                  :salario_liquido,
                  :descontos

    validates :nome_funcionario, presence: true

    def nome_cliente
      nome_funcionario
    end

    def cpf_cliente
      cpf_funcionario
    end

    protected

    def sanitizar_atributos(hash)
      {
        nome_funcionario: sanitizar_string(hash["nome_funcionario"]),
        cpf_funcionario: sanitizar_cpf(hash["cpf_funcionario"]),
        empregador: sanitizar_string(hash["empregador"]),
        cnpj_empregador: sanitizar_string(hash["cnpj_empregador"]),
        mes_ano_competencia: sanitizar_string(hash["mes_ano_competencia"]),
        cargo: sanitizar_string(hash["cargo"]),
        salario_bruto: sanitizar_numero(hash["salario_bruto"]),
        salario_liquido: sanitizar_numero(hash["salario_liquido"]),
        descontos: sanitizar_numero(hash["descontos"])
      }
    end
  end
end
