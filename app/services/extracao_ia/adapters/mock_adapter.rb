# frozen_string_literal: true

module ExtracaoIa
  module Adapters
    class MockAdapter < Port
      def provider_name
        "mock"
      end

      def default_model
        "mock-vision-v1"
      end

      def calculate_estimated_cost(input_tokens, output_tokens, model = nil)
        0.0
      end

      def extract(file_bytes_or_io, content_type: "image/jpeg", options: {})
        _, response_time_ms = measure_time { sleep(0.01) }

        if options[:simulate_error] || options[:simular_erro]
          return ExtractionResult.new(
            success: false,
            provider_name: provider_name,
            model_name: model_name,
            prompt_version: prompt_version,
            document_type: "desconhecido",
            confidence_score: 0.0,
            suggested_filename: nil,
            extracted_data: {},
            input_tokens: 0,
            output_tokens: 0,
            response_time_ms: response_time_ms,
            estimated_cost_usd: 0.0,
            raw_response: { "error" => "Simulated extraction failure" },
            error_message: "Simulated extraction failure"
          )
        end

        tipo = options[:document_type] || options[:tipo_documento] || infer_type_from_name(options[:filename] || options[:nome_arquivo])

        mock_data = generate_mock_data(tipo)

        ExtractionResult.new(
          success: true,
          provider_name: provider_name,
          model_name: model_name,
          prompt_version: prompt_version,
          document_type: mock_data[:tipo_documento],
          confidence_score: mock_data[:score_confianca],
          suggested_filename: mock_data[:nome_sugerido],
          extracted_data: mock_data[:dados_extraidos],
          input_tokens: 820,
          output_tokens: 215,
          response_time_ms: response_time_ms,
          estimated_cost_usd: 0.0,
          raw_response: mock_data,
          error_message: nil
        )
      end

      private

      def infer_type_from_name(filename)
        name = filename.to_s.downcase
        if name.include?("cnh")
          "cnh"
        elsif name.include?("comprovante") || name.include?("residencia") || name.include?("luz") || name.include?("agua")
          "comprovante_residencia"
        elsif name.include?("contracheque") || name.include?("holerite") || name.include?("salario")
          "contracheque"
        elsif name.include?("rg") || name.include?("identidade")
          "rg"
        else
          "rg"
        end
      end

      def generate_mock_data(tipo)
        case tipo.to_s.downcase
        when "cnh"
          {
            tipo_documento: "cnh",
            score_confianca: 0.97,
            nome_sugerido: "MARIA SILVA SANTOS - CNH - 2026.pdf",
            dados_extraidos: {
              "nome" => "Maria Silva Santos",
              "cpf" => "123.456.789-00",
              "numero_cnh" => "04589234101",
              "data_nascimento" => "1990-05-15",
              "categoria" => "AB",
              "validade" => "2030-05-15",
              "primeira_habilitacao" => "2008-06-10",
              "filiacao" => {
                "mae" => "Ana Maria Silva",
                "pai" => "Jose Carlos Santos"
              }
            }
          }
        when "comprovante_residencia"
          {
            tipo_documento: "comprovante_residencia",
            score_confianca: 0.94,
            nome_sugerido: "MARIA SILVA SANTOS - COMPROVANTE RESIDENCIA - 2026.pdf",
            dados_extraidos: {
              "titular" => "Maria Silva Santos",
              "cpf_titular" => "123.456.789-00",
              "tipo_comprovante" => "energia",
              "empresa_emissora" => "Cosern Neoenergia",
              "mes_referencia" => "08/2026",
              "data_vencimento" => "2026-08-20",
              "endereco" => {
                "logradouro" => "Rua Melo Franco",
                "numero" => "122",
                "complemento" => "Sala 102",
                "bairro" => "Centro",
                "cidade" => "Mossoró",
                "estado" => "RN",
                "cep" => "59600-165"
              }
            }
          }
        when "contracheque"
          {
            tipo_documento: "contracheque",
            score_confianca: 0.93,
            nome_sugerido: "MARIA SILVA SANTOS - CONTRACHEQUE - 2026.pdf",
            dados_extraidos: {
              "nome_funcionario" => "Maria Silva Santos",
              "cpf_funcionario" => "123.456.789-00",
              "empregador" => "Lamarck Sociedade de Advogados",
              "cnpj_empregador" => "12.345.678/0001-90",
              "mes_ano_competencia" => "07/2026",
              "cargo" => "Analista Jurídico",
              "salario_bruto" => 6500.00,
              "salario_liquido" => 5120.50,
              "descontos" => 1379.50
            }
          }
        else
          {
            tipo_documento: "rg",
            score_confianca: 0.96,
            nome_sugerido: "MARIA SILVA SANTOS - RG - 2026.pdf",
            dados_extraidos: {
              "nome" => "Maria Silva Santos",
              "cpf" => "123.456.789-00",
              "numero_rg" => "002.894.123",
              "orgao_emissor" => "SSP/RN",
              "data_nascimento" => "1990-05-15",
              "naturalidade" => "Mossoró/RN",
              "data_emissao" => "2018-03-22",
              "filiacao" => {
                "mae" => "Ana Maria Silva",
                "pai" => "Jose Carlos Santos"
              }
            }
          }
        end
      end
    end
  end
end
