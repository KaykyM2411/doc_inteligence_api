# frozen_string_literal: true

class ConfiguracaoSmtpSerializer < ApplicationSerializer
  # Credencial criptografada propositalmente excluida por seguranca
  attributes :id, :nome, :tipo_provedor, :endereco_email, :ativo, :created_at, :updated_at
end
