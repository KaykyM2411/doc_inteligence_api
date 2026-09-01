# frozen_string_literal: true

class ClienteSerializer < ApplicationSerializer
  attributes :id, :nome, :cpf, :email, :telefone, :created_at, :updated_at

  many :enderecos, resource: EnderecoSerializer
end
