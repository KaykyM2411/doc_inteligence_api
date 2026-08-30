# frozen_string_literal: true

class Estado < ApplicationRecord
  has_many :cidades, dependent: :destroy

  validates :nome, presence: true
  validates :sigla, presence: true, uniqueness: true, length: { is: 2 }
end
