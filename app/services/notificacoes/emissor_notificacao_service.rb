# frozen_string_literal: true

module Notificacoes
  class EmissorNotificacaoService
    # Emite notificação persistida e transmissão WebSocket em tempo real para documentos de integrações
    # @param documento [Documento]
    # @return [Notificacao, nil]
    def self.notificar_documento_integracao!(documento)
      new(documento).executar!
    end

    def initialize(documento)
      @documento = documento
    end

    def executar!
      return unless @documento.origem.to_s.in?(%w[whatsapp email])

      titulo = gerar_titulo
      conteudo = gerar_conteudo
      metadados = gerar_metadados

      notificacao = Notificacao.create!(
        titulo: titulo,
        conteudo: conteudo,
        metadados: metadados
      )

      transmitir_action_cable!(notificacao, metadados)

      notificacao
    rescue StandardError => e
      Rails.logger.error("[EmissorNotificacaoService] Erro ao emitir notificação para documento #{@documento.id}: #{e.message}")
      nil
    end

    private

    def gerar_titulo
      canal = @documento.origem.to_s == "whatsapp" ? "WhatsApp" : "E-mail"
      "Novo documento recebido via #{canal}"
    end

    def gerar_conteudo
      nome_doc = @documento.nome_arquivo.presence || "Documento #{@documento.tipo.upcase}"
      confianca_pct = (@documento.score_confianca.to_f * 100).round

      case @documento.status.to_s
      when "processado"
        "O documento '#{nome_doc}' foi extraído com sucesso (Confiança: #{confianca_pct}%)."
      when "necessita_revisao"
        "O documento '#{nome_doc}' necessita de conferência humana (Confiança: #{confianca_pct}%)."
      when "falhou"
        "Falha na extração automática do documento '#{nome_doc}'."
      else
        "O documento '#{nome_doc}' foi recebido e está em processamento."
      end
    end

    def gerar_metadados
      {
        documento_id: @documento.id,
        nome_arquivo: @documento.nome_arquivo,
        tipo: @documento.tipo,
        origem: @documento.origem,
        status: @documento.status,
        score_confianca: @documento.score_confianca.to_f,
        cliente_id: @documento.cliente_id,
        cliente_nome: @documento.cliente&.nome,
        created_at: @documento.created_at
      }
    end

    def transmitir_action_cable!(notificacao, metadados)
      payload = {
        evento: "documento_integracao_processado",
        notificacao_id: notificacao.id,
        titulo: notificacao.titulo,
        conteudo: notificacao.conteudo,
        documento: metadados,
        enviado_em: Time.current
      }

      ActionCable.server.broadcast(DocumentosChannel::STREAM_NAME, payload)
    end
  end
end
