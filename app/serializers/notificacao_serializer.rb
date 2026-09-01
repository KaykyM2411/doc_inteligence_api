# frozen_string_literal: true

class NotificacaoSerializer < ApplicationSerializer
  attributes :id, :titulo, :conteudo, :lida_em, :metadados, :created_at

  attribute :lida, &:lida?
end
