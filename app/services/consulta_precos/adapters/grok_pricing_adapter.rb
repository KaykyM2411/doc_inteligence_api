# frozen_string_literal: true

require "faraday"
require "json"

module ConsultaPrecos
  module Adapters
    class GrokPricingAdapter < Port
      BASE_URL = "https://api.x.ai/v1"

      def provider_name
        "grok"
      end

      # Consulta dinamicamente a taxa no endpoint /v1/models/{model_id} da xAI
      # @param model_name [String]
      # @param credential [String, nil]
      # @return [PriceResult]
      def fetch_price(model_name, credential = nil)
        m_name = model_name.to_s
        api_key = credential.presence || ENV["XAI_API_KEY"] || ENV["GROK_API_KEY"]

        return build_zero_result(m_name) if api_key.blank?

        data = Rails.cache.fetch("grok_pricing_#{m_name}", expires_in: 6.hours) do
          conn = Faraday.new(url: BASE_URL) do |f|
            f.request :json
            f.response :json
            f.options.timeout = 10
            f.options.open_timeout = 5
          end

          response = conn.get("models/#{m_name}") do |req|
            req.headers["Authorization"] = "Bearer #{api_key}"
          end

          if response.success? && response.body.is_a?(Hash)
            response.body
          else
            nil
          end
        rescue StandardError => e
          Rails.logger.warn("[GrokPricingAdapter] Erro ao consultar preço do modelo #{m_name} na xAI: #{e.message}")
          nil
        end

        if data && (data["prompt_text_token_price"] || data["prompt_image_token_price"])
          prompt_units = (data["prompt_text_token_price"] || data["prompt_image_token_price"]).to_f
          completion_units = (data["completion_text_token_price"] || 0).to_f

          # 12500 micro-units / 10^10 -> USD per token
          PriceResult.new(
            model_name: m_name,
            prompt_per_token: prompt_units / 10_000_000_000.0,
            completion_per_token: completion_units / 10_000_000_000.0
          )
        else
          build_zero_result(m_name)
        end
      end

      private

      def build_zero_result(model_name)
        PriceResult.new(
          model_name: model_name,
          prompt_per_token: 0.0,
          completion_per_token: 0.0
        )
      end
    end
  end
end
