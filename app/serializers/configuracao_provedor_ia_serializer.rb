# frozen_string_literal: true

class ConfiguracaoProvedorIaSerializer < ApplicationSerializer
  # Credencial criptografada propositalmente excluida por seguranca
  attributes :id, :nome_provedor, :nome_modelo, :ordem, :ativo, :created_at, :updated_at
end
