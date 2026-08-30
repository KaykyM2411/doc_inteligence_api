# frozen_string_literal: true

class Notificacao < ApplicationRecord
  self.table_name = "notificacoes"

  validates :titulo, :conteudo, presence: true

  scope :nao_lidas, -> { where(lida_em: nil) }
  scope :recentes, -> { order(created_at: :desc) }

  def marcar_como_lida!
    update!(lida_em: Time.current)
  end
end
