# frozen_string_literal: true

class EnderecoSerializer < ApplicationSerializer
  attributes :id, :logradouro, :numero, :complemento, :bairro, :cep, :cidade_id, :created_at

  attribute :cidade_nome do |endereco|
    endereco.cidade&.nome
  end

  attribute :estado_sigla do |endereco|
    endereco.cidade&.estado&.sigla
  end
end
