# frozen_string_literal: true

class Documento < ApplicationRecord
  has_one_attached :arquivo

  belongs_to :cliente, optional: true
  belongs_to :revisado_por, class_name: "Usuario", optional: true

  has_many :historicos_extracao, dependent: :destroy

  enum :status, {
    pendente: "pendente",
    processando: "processando",
    processado: "processado",
    necessita_revisao: "necessita_revisao",
    falhou: "falhou"
  }, default: :pendente

  enum :origem, {
    manual: "manual",
    whatsapp: "whatsapp",
    email: "email"
  }

  validates :tipo, :origem, :sha256_arquivo, presence: true
  validates :referencia_origem, uniqueness: { scope: :origem }, allow_nil: true
  validates :sha256_arquivo, uniqueness: { scope: :cliente_id }, if: -> { cliente_id.present? }

  scope :recentes, -> { order(created_at: :desc) }
  scope :para_revisao, -> { where(status: [ :necessita_revisao, :falhou ]) }
  scope :por_cliente, ->(cliente_id) { where(cliente_id: cliente_id) if cliente_id.present? }
  scope :por_tipo, ->(tipo) { where(tipo: tipo) if tipo.present? }
  scope :por_status, ->(status) { where(status: status) if status.present? }
end
