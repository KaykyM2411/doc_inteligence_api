# frozen_string_literal: true

class ConfiguracaoProvedorIa < ApplicationRecord
  self.table_name = "configuracoes_provedor_ia"

  has_many :historicos_extracao, dependent: :nullify

  encrypts :credencial_criptografada

  validates :nome_provedor, :nome_modelo, presence: true

  scope :ativos, -> { where(ativo: true) }

  before_save :desativar_outros_se_ativo, if: :ativo?

  private

  def desativar_outros_se_ativo
    self.class.where.not(id: id).update_all(ativo: false)
  end
end
