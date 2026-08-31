# frozen_string_literal: true

module ConsultaPrecos
  class PriceResult
    attr_reader :model_name,
                :prompt_per_token,
                :completion_per_token,
                :currency

    def initialize(
      model_name:,
      prompt_per_token: 0.0,
      completion_per_token: 0.0,
      currency: "USD"
    )
      @model_name = model_name.to_s
      @prompt_per_token = prompt_per_token.to_f
      @completion_per_token = completion_per_token.to_f
      @currency = currency
    end

    def calculate_cost(input_tokens, output_tokens)
      cost = (input_tokens.to_i * @prompt_per_token) + (output_tokens.to_i * @completion_per_token)
      cost.round(6)
    end
  end
end
