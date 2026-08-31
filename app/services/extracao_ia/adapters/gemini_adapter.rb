# frozen_string_literal: true

require "faraday"

module ExtracaoIa
  module Adapters
    class GeminiAdapter < Port
      BASE_URL = "https://generativelanguage.googleapis.com/v1beta"

      def provider_name
        "gemini"
      end

      def default_model
        "gemini-1.5-flash"
      end

      def env_credential
        ENV["GEMINI_API_KEY"]
      end

      def extract(file_bytes_or_io, content_type: "image/jpeg", options: {})
        api_key = credential
        if api_key.blank?
          return build_error_result("Credencial Gemini não configurada (defina no banco ou em GEMINI_API_KEY)")
        end

        base64_file = encode_base64(file_bytes_or_io)

        payload = {
          systemInstruction: {
            parts: [ { text: DefaultPrompt.system_prompt } ]
          },
          contents: [
            {
              role: "user",
              parts: [
                { text: DefaultPrompt.user_prompt },
                {
                  inlineData: {
                    mimeType: content_type,
                    data: base64_file
                  }
                }
              ]
            }
          ],
          generationConfig: {
            responseMimeType: "application/json",
            temperature: 0.1
          }
        }

        conn = Faraday.new(url: BASE_URL) do |f|
          f.request :json
          f.response :json
          f.options.timeout = 60
          f.options.open_timeout = 10
        end

        raw_response = nil
        _, response_time_ms = measure_time do
          response = conn.post("models/#{model_name}:generateContent?key=#{api_key}") do |req|
            req.headers["Content-Type"] = "application/json"
            req.body = payload
          end

          raw_response = response.body
          unless response.success?
            err_msg = raw_response.dig("error", "message") || "HTTP Error #{response.status}"
            return build_error_result(err_msg, raw_response, response_time_ms)
          end
        end

        candidate = raw_response.dig("candidates", 0)
        content_str = candidate.dig("content", "parts", 0, "text")
        parsed_data = parse_json_response(content_str)

        input_tokens = raw_response.dig("usageMetadata", "promptTokenCount") || 0
        output_tokens = raw_response.dig("usageMetadata", "candidatesTokenCount") || 0
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
        build_error_result("Erro de conexão com a API Gemini: #{e.message}")
      rescue StandardError => e
        build_error_result("Falha no processamento Gemini: #{e.message}")
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
