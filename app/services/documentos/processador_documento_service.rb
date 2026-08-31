# frozen_string_literal: true

module Documentos
  class ProcessadorDocumentoService
    attr_reader :documento, :adapter

    def initialize(documento, adapter: nil)
      @documento = documento
      @adapter = adapter || ExtracaoIa::Factory.active_adapter
    end

    def processar!
      @documento.update!(status: :processando) unless @documento.processando?

      # 1. Carrega bytes do arquivo (ActiveStorage ou url_arquivo_bruto)
      arquivo_bytes, content_type = carregar_arquivo

      # 2. Executa a extração no adaptador de IA ativo
      resultado_extracao = @adapter.extract(
        arquivo_bytes,
        content_type: content_type,
        options: {
          nome_arquivo: @documento.nome_arquivo,
          tipo_documento: @documento.tipo
        }
      )

      # 3. Tratamento de falha de conexão/execução na IA
      unless resultado_extracao.success?
        registrar_historico!(resultado_extracao)
        @documento.update!(status: :falhou)
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

      # 7. Persistência dos Dados Validados no Documento
      @documento.update!(
        tipo: tipo_detectado,
        status: novo_status,
        score_confianca: resultado_extracao.confidence_score,
        nome_arquivo: resultado_extracao.suggested_filename.presence || @documento.nome_arquivo,
        dados_extraidos: schema.para_h
      )

      # 8. Registro de Auditoria em historicos_extracao
      registrar_historico!(resultado_extracao)

      @documento
    end

    private

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
