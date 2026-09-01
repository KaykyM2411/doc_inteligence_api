# frozen_string_literal: true

class ConfiguracaoWhatsappSerializer < ApplicationSerializer
  # Credencial criptografada propositalmente excluida por seguranca
  attributes :id, :nome, :tipo_provedor, :numero_telefone, :ativo, :created_at, :updated_at
end
