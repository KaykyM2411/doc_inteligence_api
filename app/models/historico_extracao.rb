# frozen_string_literal: true

class HistoricoExtracao < ApplicationRecord
  self.table_name = "historicos_extracao"

  belongs_to :documento
  belongs_to :configuracao_provedor_ia, optional: true

  validates :nome_provedor, :nome_modelo, :versao_prompt, presence: true

  scope :recentes, -> { order(created_at: :desc) }
end
