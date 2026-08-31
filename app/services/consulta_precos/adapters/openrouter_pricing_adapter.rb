# frozen_string_literal: true

require "faraday"
require "json"

module ConsultaPrecos
  module Adapters
    class OpenrouterPricingAdapter < Port
      OPENROUTER_MODELS_URL = "https://openrouter.ai/api/v1/models"

      def provider_name
        "openrouter"
      end

      # Consulta dinamicamente a taxa de preços na API de catálogo do OpenRouter
      # Utilizado para OpenRouter, OpenAI e Gemini
      # @param model_name [String] Ex: "gpt-4o-mini", "gemini-1.5-flash", "meta-llama/llama-3.2-11b-vision-instruct"
      # @param credential [String, nil]
      # @return [PriceResult]
      def fetch_price(model_name, credential = nil)
        m_name = model_name.to_s
        return build_zero_result(m_name) if m_name.blank?

        models_catalog = Rails.cache.fetch("openrouter_models_catalog", expires_in: 6.hours) do
          conn = Faraday.new(url: OPENROUTER_MODELS_URL) do |f|
            f.options.timeout = 10
            f.options.open_timeout = 5
          end

          response = conn.get
          if response.success?
            parsed = JSON.parse(response.body)
            parsed["data"] || []
          else
            []
          end
        rescue StandardError => e
          Rails.logger.warn("[OpenrouterPricingAdapter] Falha ao consultar catálogo de modelos OpenRouter: #{e.message}")
          []
        end

        target_model = models_catalog.find do |item|
          item_id = item["id"].to_s.downcase
          query = m_name.downcase

          item_id == query ||
            item_id == "openai/#{query}" ||
            item_id == "google/#{query}" ||
            item_id.end_with?("/#{query}")
        end

        if target_model && target_model["pricing"]
          PriceResult.new(
            model_name: m_name,
            prompt_per_token: target_model.dig("pricing", "prompt").to_f,
            completion_per_token: target_model.dig("pricing", "completion").to_f
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
