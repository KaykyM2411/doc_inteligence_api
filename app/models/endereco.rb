# frozen_string_literal: true

class Endereco < ApplicationRecord
  belongs_to :cliente
  belongs_to :cidade

  validates :logradouro, :numero, presence: true
end
