# frozen_string_literal: true

class Cidade < ApplicationRecord
  include Huginn::Datatable

  belongs_to :estado
  has_many :enderecos, dependent: :restrict_with_error

  validates :nome, presence: true

  scope :por_estado, ->(estado_id) { where(estado_id: estado_id) if estado_id.present? }

  # Mapeamento de atributos públicos via Huginn
  huginn_attributes(
    id: "id",
    nome: "nome",
    estado_id: "estado_id",
    estado_nome: "estado.nome",
    estado_sigla: "estado.sigla"
  )
end
