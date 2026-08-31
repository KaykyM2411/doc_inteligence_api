# frozen_string_literal: true

module ConsultaPrecos
  class Port
    def provider_name
      raise NotImplementedError, "#{self.class} must implement #provider_name"
    end

    # Consulta dinamicamente a taxa de preços por token do modelo
    # @param model_name [String]
    # @param credential [String, nil]
    # @return [PriceResult]
    def fetch_price(model_name, credential = nil)
      raise NotImplementedError, "#{self.class} must implement #fetch_price"
    end

    # Calcula custo total em USD para os tokens informados
    # @param model_name [String]
    # @param input_tokens [Integer]
    # @param output_tokens [Integer]
    # @param credential [String, nil]
    # @return [Float]
    def calculate_cost(model_name, input_tokens, output_tokens, credential = nil)
      price = fetch_price(model_name, credential)
      price ? price.calculate_cost(input_tokens, output_tokens) : 0.0
    end
  end
end
