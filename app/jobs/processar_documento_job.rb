# frozen_string_literal: true

class ProcessarDocumentoJob < ApplicationJob
  queue_as :default

  # Processa extração de documento assincronamente com Sidekiq
  # @param documento_id [String] UUID do Documento
  def perform(documento_id)
    documento = Documento.find_by(id: documento_id)
    return unless documento

    Documentos::ProcessadorDocumentoService.new(documento).processar!
  end
end
