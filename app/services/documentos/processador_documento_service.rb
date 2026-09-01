# frozen_string_literal: true

module Documentos
  class ProcessadorDocumentoService
    attr_reader :documento, :adapter

    def initialize(documento, adapter: nil)
      @documento = documento
      @adapter = adapter
    end

    def processar!
      @documento.update!(status: :processando) unless @documento.processando?

      # 1. Carrega bytes do arquivo (ActiveStorage ou url_arquivo_bruto)
      arquivo_bytes, content_type = carregar_arquivo

      # 2. Executa a extração via cascata de adaptadores protegidos por Circuit Breaker
      resultado_extracao = executar_extracao_com_fallback(arquivo_bytes, content_type)

      # 3. Tratamento de falha de conexão/execução na IA
      unless resultado_extracao.success?
        registrar_historico!(resultado_extracao)
        @documento.update!(status: :falhou)
        Notificacoes::EmissorNotificacaoService.notificar_documento_integracao!(@documento)
        return @documento
      end

      # 4. Validação e sanitização via Schemas PORO
      tipo_detectado = resultado_extracao.document_type.presence || @documento.tipo
      schema = EsquemasDocumento::FactoryEsquemas.build(
        tipo_detectado,
        resultado_extracao.extracted_data,
        @documento.versao_schema
      )

      # 5. Associação Automática de Cliente (via CPF -> Fallback por Nome)
      associar_cliente!(schema) if @documento.cliente_id.blank?

      # 6. Avaliação de Status com base na Validade do Schema e Score de Confiança
      novo_status = if schema.valid? && resultado_extracao.confidence_score >= 0.85 && tipo_detectado != "desconhecido"
                      :processado
                    else
                      :necessita_revisao
                    end

      # 7. Persistência dos Dados Validados no Documento e Renomeação do Arquivo Físico no Blob
      novo_nome = resultado_extracao.suggested_filename.presence || @documento.nome_arquivo

      @documento.update!(
        tipo: tipo_detectado,
        status: novo_status,
        score_confianca: resultado_extracao.confidence_score,
        nome_arquivo: novo_nome,
        dados_extraidos: schema.para_h
      )

      # Renomeia o blob do ActiveStorage para que futuros downloads usem o nome padronizado
      if @documento.arquivo.attached? && resultado_extracao.suggested_filename.present?
        @documento.arquivo.blob.update(filename: resultado_extracao.suggested_filename)
      end

      # 8. Registro de Auditoria em historicos_extracao
      registrar_historico!(resultado_extracao)

      # 9. Notificação em tempo real via ActionCable para documentos de integrações (WhatsApp / E-mail)
      Notificacoes::EmissorNotificacaoService.notificar_documento_integracao!(@documento)

      @documento
    end

    private

    def executar_extracao_com_fallback(arquivo_bytes, content_type)
      adapters_disponiveis = @adapter ? [@adapter] : ExtracaoIa::Factory.active_adapters
      options = { nome_arquivo: @documento.nome_arquivo, tipo_documento: @documento.tipo }
      ultimo_resultado = nil

      adapters_disponiveis.each_with_index do |adapter, idx|
        breaker = ExtracaoIa::CircuitBreaker.new(adapter.provider_name)

        begin
          resultado = breaker.call do
            adapter.extract(arquivo_bytes, content_type: content_type, options: options)
          end

          ultimo_resultado = resultado
          @adapter = adapter

          if resultado&.success?
            Rails.logger.info("[ProcessadorDocumentoService] Extracao concluida com sucesso via '#{adapter.provider_name}' (Tentativa #{idx + 1}/#{adapters_disponiveis.size})")
            return resultado
          else
            Rails.logger.warn("[ProcessadorDocumentoService] Provedor '#{adapter.provider_name}' falhou: #{resultado&.error_message}. Acionando fallback se disponivel...")
          end
        rescue ExtracaoIa::CircuitOpenError => e
          Rails.logger.warn("[ProcessadorDocumentoService] Circuit Breaker OPEN para '#{adapter.provider_name}': #{e.message}. Tentando proximo provedor...")
        rescue StandardError => e
          Rails.logger.error("[ProcessadorDocumentoService] Erro no provedor '#{adapter.provider_name}': #{e.message}. Tentando proximo provedor...")
        end
      end

      ultimo_resultado || ExtracaoIa::ExtractionResult.new(
        success: false,
        provider_name: @adapter&.provider_name || "nenhum",
        model_name: @adapter&.model_name || "nenhum",
        prompt_version: "v1.0",
        document_type: "desconhecido",
        confidence_score: 0.0,
        suggested_filename: nil,
        extracted_data: {},
        input_tokens: 0,
        output_tokens: 0,
        response_time_ms: 0,
        estimated_cost_usd: 0.0,
        raw_response: { "error" => "Todos os provedores de IA configurados falharam ou estao indisponiveis" },
        error_message: "Todos os provedores de IA configurados falharam ou estao indisponiveis"
      )
    end

    def carregar_arquivo
      if @documento.arquivo.attached?
        [ @documento.arquivo.download, @documento.arquivo.content_type ]
      elsif @documento.url_arquivo_bruto.present?
        [ @documento.url_arquivo_bruto, "image/jpeg" ]
      else
        [ "", "image/jpeg" ]
      end
    end

    def associar_cliente!(schema)
      cpf = schema.cpf_cliente
      nome = schema.nome_cliente

      cliente_encontrado = if cpf.present?
                             Cliente.find_by(cpf: cpf)
      elsif nome.present?
                             Cliente.where("LOWER(nome) = ?", nome.downcase.strip).first
      end

      @documento.cliente = cliente_encontrado if cliente_encontrado.present?
    end

    def registrar_historico!(resultado)
      config_id = @adapter.configuration&.id

      @documento.historicos_extracao.create!(
        configuracao_provedor_ia_id: config_id,
        nome_provedor: resultado.provider_name,
        nome_modelo: resultado.model_name,
        versao_prompt: resultado.prompt_version,
        tokens_entrada: resultado.input_tokens,
        tokens_saida: resultado.output_tokens,
        tempo_resposta_ms: resultado.response_time_ms,
        custo_estimado_usd: resultado.estimated_cost_usd,
        resposta_bruta: resultado.raw_response,
        mensagem_erro: resultado.error_message
      )
    end
  end
end
