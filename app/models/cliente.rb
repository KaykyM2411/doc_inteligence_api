# frozen_string_literal: true

class Cliente < ApplicationRecord
  include Huginn::Datatable

  has_many :enderecos, dependent: :destroy
  has_many :documentos, dependent: :nullify

  validates :nome, presence: true
  validates :cpf, uniqueness: true, allow_nil: true

  # Mapeamento de atributos públicos no Huginn (colunas próprias diretas e associações por caminho)
  huginn_attributes(
    id: "id",
    nome: "nome",
    cpf: "cpf",
    email: "email",
    telefone: "telefone",
    criado_em: "created_at",
    atualizado_em: "updated_at",
    cidade: "enderecos.cidade.nome",
    estado: "enderecos.cidade.estado.sigla"
  )
end
