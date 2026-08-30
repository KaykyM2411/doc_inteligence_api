# frozen_string_literal: true

class ConfiguracaoWhatsapp < ApplicationRecord
  self.table_name = "configuracoes_whatsapp"

  encrypts :credencial_criptografada

  validates :nome, :tipo_provedor, presence: true

  scope :ativos, -> { where(ativo: true) }
end
