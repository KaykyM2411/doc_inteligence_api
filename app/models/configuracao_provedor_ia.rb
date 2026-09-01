# frozen_string_literal: true

class ConfiguracaoProvedorIa < ApplicationRecord
  self.table_name = "configuracoes_provedor_ia"

  has_many :historicos_extracao, class_name: "HistoricoExtracao", dependent: :nullify

  encrypts :credencial_criptografada

  validates :nome_provedor, :nome_modelo, presence: true
  validates :ordem, presence: true, uniqueness: true, numericality: { greater_than: 0 }, if: :ativo?

  scope :ativos, -> { where(ativo: true) }
  scope :ativos_ordenados, -> { where(ativo: true).order(:ordem, :created_at) }
end
