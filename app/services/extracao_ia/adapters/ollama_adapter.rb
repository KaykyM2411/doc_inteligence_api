# frozen_string_literal: true

require "faraday"

module ExtracaoIa
  module Adapters
    class OllamaAdapter < Port
      def provider_name
        "ollama"
      end

      def default_model
        "llama3.2-vision"
      end

      def host_url
        ENV.fetch("OLLAMA_HOST") { "http://localhost:11434" }
      end

      def calculate_estimated_cost(input_tokens, output_tokens, model = nil)
        0.0 # Execução local on-premise sem custo de API por chamada
      end

      def extract(file_bytes_or_io, content_type: "image/jpeg", options: {})
        base64_file = encode_base64(file_bytes_or_io)

        payload = {
          model: model_name,
          messages: [
            {
              role: "system",
              content: DefaultPrompt.system_prompt
            },
            {
              role: "user",
              content: DefaultPrompt.user_prompt,
              images: [ base64_file ]
            }
          ],
          format: "json",
          stream: false,
          options: {
            temperature: 0.1
          }
        }

        conn = Faraday.new(url: host_url) do |f|
          f.request :json
          f.response :json
          f.options.timeout = 120
          f.options.open_timeout = 10
        end

        raw_response = nil
        _, response_time_ms = measure_time do
          response = conn.post("api/chat") do |req|
            req.headers["Content-Type"] = "application/json"
            req.body = payload
          end

          raw_response = response.body
          unless response.success?
            err_msg = raw_response&.dig("error") || "HTTP Error #{response.status}"
            return build_error_result(err_msg, raw_response, response_time_ms)
          end
        end

        content_str = raw_response.dig("message", "content")
        parsed_data = parse_json_response(content_str)

        input_tokens = raw_response["prompt_eval_count"] || 0
        output_tokens = raw_response["eval_count"] || 0

        ExtractionResult.new(
          success: true,
          provider_name: provider_name,
          model_name: model_name,
          prompt_version: prompt_version,
          document_type: parsed_data["tipo_documento"] || "desconhecido",
          confidence_score: parsed_data["score_confianca"] || 0.0,
          suggested_filename: parsed_data["nome_sugerido"],
          extracted_data: parsed_data["dados_extraidos"] || {},
          input_tokens: input_tokens,
          output_tokens: output_tokens,
          response_time_ms: response_time_ms,
          estimated_cost_usd: 0.0,
          raw_response: raw_response,
          error_message: nil
        )
      rescue Faraday::Error => e
        build_error_result("Erro ao conectar com servidor local Ollama (#{host_url}): #{e.message}")
      rescue StandardError => e
        build_error_result("Falha no processamento Ollama: #{e.message}")
      end

      private

      def build_error_result(message, raw = {}, time_ms = 0)
        ExtractionResult.new(
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
          response_time_ms: time_ms,
          estimated_cost_usd: 0.0,
          raw_response: raw.presence || { "error" => message },
          error_message: message
        )
      end
    end
  end
end
