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
      # @param model_name [String] Ex: "gpt-4o-mini", "gemini-2.5-flash", "meta-llama/llama-3.2-11b-vision-instruct"
      # @param credential [String, nil]
      # @return [PriceResult]
      def fetch_price(model_name, credential = nil)
        m_name = model_name.to_s.strip
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

        target_model = find_matching_model(models_catalog, m_name)

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

      def find_matching_model(catalog, model_query)
        query = model_query.downcase
        clean_q = query.sub(/\A(openai|google|meta-llama)\//, "")

        # 1. Correspondência exata ou com prefixos de provedor
        direct_match = catalog.find do |item|
          id = item["id"].to_s.downcase
          id == query || id == "openai/#{clean_q}" || id == "google/#{clean_q}" || id.end_with?("/#{clean_q}")
        end
        return direct_match if direct_match

        # 2. Correspondência por família (ex: gemini flash / pro)
        if clean_q.include?("gemini")
          flash_or_pro = clean_q.include?("pro") ? "pro" : "flash"
          catalog.find do |item|
            id = item["id"].to_s.downcase
            id.start_with?("google/gemini") && id.include?(flash_or_pro) && !id.include?("image") && !id.include?("preview")
          end
        end
      end

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
