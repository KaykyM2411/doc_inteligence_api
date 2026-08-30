# frozen_string_literal: true

class Cidade < ApplicationRecord
  belongs_to :estado
  has_many :enderecos, dependent: :restrict_with_error

  validates :nome, presence: true
end
