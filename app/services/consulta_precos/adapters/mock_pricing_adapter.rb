# frozen_string_literal: true

module ConsultaPrecos
  module Adapters
    class MockPricingAdapter < Port
      def provider_name
        "mock"
      end

      def fetch_price(model_name, credential = nil)
        PriceResult.new(
          model_name: model_name,
          prompt_per_token: 0.0,
          completion_per_token: 0.0
        )
      end
    end
  end
end
