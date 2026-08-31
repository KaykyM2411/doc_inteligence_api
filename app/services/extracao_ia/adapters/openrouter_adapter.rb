# frozen_string_literal: true

require "faraday"

module ExtracaoIa
  module Adapters
    class OpenrouterAdapter < Port
      BASE_URL = "https://openrouter.ai/api/v1"

      def provider_name
        "openrouter"
      end

      def default_model
        "meta-llama/llama-3.2-11b-vision-instruct"
      end

      def env_credential
        ENV["OPENROUTER_API_KEY"]
      end

      def extract(file_bytes_or_io, content_type: "image/jpeg", options: {})
        api_key = credential
        if api_key.blank?
          return build_error_result("Credencial OpenRouter não configurada (defina no banco ou em OPENROUTER_API_KEY)")
        end

        base64_file = encode_base64(file_bytes_or_io)
        data_uri = "data:#{content_type};base64,#{base64_file}"

        payload = {
          model: model_name,
          messages: [
            {
              role: "system",
              content: DefaultPrompt.system_prompt
            },
            {
              role: "user",
              content: [
                { type: "text", text: DefaultPrompt.user_prompt },
                {
                  type: "image_url",
                  image_url: { url: data_uri }
                }
              ]
            }
          ],
          response_format: { type: "json_object" },
          temperature: 0.1
        }

        conn = Faraday.new(url: BASE_URL) do |f|
          f.request :json
          f.response :json
          f.options.timeout = 60
          f.options.open_timeout = 10
        end

        raw_response = nil
        _, response_time_ms = measure_time do
          response = conn.post("chat/completions") do |req|
            req.headers["Authorization"] = "Bearer #{api_key}"
            req.headers["HTTP-Referer"] = "https://lamarck.adv.br"
            req.headers["X-Title"] = "DOC Intelligence"
            req.headers["Content-Type"] = "application/json"
            req.body = payload
          end

          raw_response = response.body
          unless response.success?
            err_msg = raw_response.dig("error", "message") || "HTTP Error #{response.status}"
            return build_error_result(err_msg, raw_response, response_time_ms)
          end
        end

        content_str = raw_response.dig("choices", 0, "message", "content")
        parsed_data = parse_json_response(content_str)

        input_tokens = raw_response.dig("usage", "prompt_tokens") || 0
        output_tokens = raw_response.dig("usage", "completion_tokens") || 0
        estimated_cost = calculate_estimated_cost(input_tokens, output_tokens)

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
          estimated_cost_usd: estimated_cost,
          raw_response: raw_response,
          error_message: nil
        )
      rescue Faraday::Error => e
        build_error_result("Erro de conexão com OpenRouter: #{e.message}")
      rescue StandardError => e
        build_error_result("Falha no processamento OpenRouter: #{e.message}")
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
