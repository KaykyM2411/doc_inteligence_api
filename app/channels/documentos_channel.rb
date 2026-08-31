# frozen_string_literal: true

class DocumentosChannel < ApplicationCable::Channel
  STREAM_NAME = "documentos_integracoes"

  def subscribed
    stream_from STREAM_NAME
  end

  def unsubscribed
    # Limpeza quando o cliente desconectar
  end
end
