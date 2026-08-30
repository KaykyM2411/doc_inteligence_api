# frozen_string_literal: true

class ConfiguracaoSmtp < ApplicationRecord
  self.table_name = "configuracoes_smtp"

  encrypts :credencial_criptografada

  validates :nome, :tipo_provedor, :endereco_email, presence: true

  scope :ativos, -> { where(ativo: true) }
end
