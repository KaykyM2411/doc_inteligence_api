# frozen_string_literal: true

module ExtracaoIa
  class ExtractionResult
    attr_accessor :success,
                  :provider_name,
                  :model_name,
                  :prompt_version,
                  :document_type,
                  :confidence_score,
                  :suggested_filename,
                  :extracted_data,
                  :input_tokens,
                  :output_tokens,
                  :response_time_ms,
                  :estimated_cost_usd,
                  :raw_response,
                  :error_message

    def initialize(
      success:,
      provider_name:,
      model_name:,
      prompt_version: "v1.0",
      document_type: "desconhecido",
      confidence_score: 0.0,
      suggested_filename: nil,
      extracted_data: {},
      input_tokens: 0,
      output_tokens: 0,
      response_time_ms: 0,
      estimated_cost_usd: 0.0,
      raw_response: {},
      error_message: nil
    )
      @success = success
      @provider_name = provider_name.to_s
      @model_name = model_name.to_s
      @prompt_version = prompt_version.to_s
      @document_type = document_type.to_s
      @confidence_score = confidence_score.to_f
      @suggested_filename = suggested_filename
      @extracted_data = (extracted_data || {}).deep_stringify_keys
      @input_tokens = input_tokens.to_i
      @output_tokens = output_tokens.to_i
      @response_time_ms = response_time_ms.to_i
      @estimated_cost_usd = estimated_cost_usd.to_f
      @raw_response = raw_response || {}
      @error_message = error_message
    end

    def success?
      @success == true
    end

    def requires_review?
      !success? || confidence_score < 0.85 || document_type == "desconhecido"
    end
  end
end
