# frozen_string_literal: true

class Cliente < ApplicationRecord
  has_many :enderecos, dependent: :destroy
  has_many :documentos, dependent: :nullify

  validates :nome, presence: true
  validates :cpf, uniqueness: true, allow_nil: true
end
