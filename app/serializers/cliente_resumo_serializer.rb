# frozen_string_literal: true

class ClienteResumoSerializer < ApplicationSerializer
  attributes :id, :nome, :cpf, :email, :telefone
end
