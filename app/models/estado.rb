# frozen_string_literal: true

class Estado < ApplicationRecord
  include Huginn::Datatable

  has_many :cidades, dependent: :destroy

  validates :nome, presence: true
  validates :sigla, presence: true, uniqueness: true, length: { is: 2 }

  # Mapeamento de atributos públicos via Huginn
  huginn_attributes(
    id: "id",
    nome: "nome",
    sigla: "sigla"
  )
end
