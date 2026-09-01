# frozen_string_literal: true

class DocumentoResumoSerializer < ApplicationSerializer
  attributes :id, :tipo, :origem, :status, :score_confianca, :nome_arquivo,
             :dados_extraidos, :cliente_id, :created_at, :updated_at
end
