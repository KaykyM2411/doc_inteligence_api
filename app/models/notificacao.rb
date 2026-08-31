# frozen_string_literal: true

class Notificacao < ApplicationRecord
  self.table_name = "notificacoes"

  include Huginn::Datatable

  validates :titulo, :conteudo, presence: true

  scope :nao_lidas, -> { where(lida_em: nil) }
  scope :lidas, -> { where.not(lida_em: nil) }
  scope :recentes, -> { order(created_at: :desc) }

  huginn_attributes(
    id: "id",
    titulo: "titulo",
    conteudo: "conteudo",
    lida_em: "lida_em",
    criado_em: "created_at"
  )

  def lida?
    lida_em.present?
  end

  def marcar_como_lida!
    update!(lida_em: Time.current)
  end
end
